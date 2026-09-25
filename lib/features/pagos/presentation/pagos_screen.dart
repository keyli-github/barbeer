import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/sede_scope_provider.dart';
import '../../../core/widgets/operation_form.dart';
import '../../../core/widgets/operation_page.dart';
import '../../../core/widgets/responsive_form.dart';
import '../../../core/widgets/sede_scope_selector.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../operaciones/data/operations_repository.dart';
import '../../caja/presentation/providers/caja_provider.dart';
import '../../cuentas/presentation/providers/cuentas_provider.dart';

final payrollProvider = FutureProvider.autoDispose
    .family<OperationsPage, (int, String)>((ref, query) {
      ref.watch(authProvider.select((state) => state.user?.id));
      return ref
          .watch(operationsRepositoryProvider)
          .list(
            '/pagos',
            sedeId: ref.watch(globalSedeIdProvider),
            page: query.$1,
            filters: {'q': query.$2},
          );
    });
final payrollDetailProvider = FutureProvider.autoDispose
    .family<OperationJson, String>((ref, id) {
      ref.watch(authProvider.select((state) => state.user?.id));
      return ref.watch(operationsRepositoryProvider).detail('/pagos/$id');
    });

class PagosScreen extends ConsumerStatefulWidget {
  const PagosScreen({super.key});
  @override
  ConsumerState<PagosScreen> createState() => _PagosScreenState();
}

class _PagosScreenState extends ConsumerState<PagosScreen> {
  int _page = 1;
  String _search = '';
  @override
  Widget build(BuildContext context) {
    ref.listen(globalSedeIdProvider, (_, __) => setState(() => _page = 1));
    final result = ref.watch(payrollProvider((_page, _search)));
    return OperationPage(
      title: 'Pagos del personal',
      subtitle: 'Sueldos, bonos, recargos y liquidaciones',
      loading: result.isLoading,
      error: result.error,
      page: _page,
      pages: result.valueOrNull?.pages ?? 1,
      reload: () async => ref.invalidate(payrollProvider),
      onPage: (page) => setState(() => _page = page),
      filters: [
        const SedeScopeSelector(),
        TextField(
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            labelText: 'Buscar personal',
            prefixIcon: Icon(Icons.search),
          ),
          onSubmitted: (value) => setState(() {
            _search = value.trim();
            _page = 1;
          }),
        ),
      ],
      cards: (result.valueOrNull?.items ?? []).map((person) {
        final summary = objectValue(person['resumen']);
        return Card(
          child: InkWell(
            onTap: () => ResponsiveForm.showPage(
              context: context,
              page: PagoDetalleScreen(userId: '${person['id']}'),
            ),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.account_balance_wallet_outlined),
                  const SizedBox(height: 12),
                  Text(
                    '${person['username']}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${objectValue(person['rol'])['nombre'] ?? ''} · ${objectValue(person['sede'])['nombre'] ?? ''}',
                  ),
                  const SizedBox(height: 16),
                  Text(
                    soles(summary['totalNetoPendiente']),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    person['pagoPeriodo'] == null
                        ? 'Pendiente de liquidación'
                        : 'Periodo liquidado',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cuenta por cobrar: ${soles(objectValue(person['cuentaPorCobrar'])['saldo'])}',
                  ),
                  const SizedBox(height: 12),
                  const Text('Ver detalle →'),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class PagoDetalleScreen extends ConsumerStatefulWidget {
  final String userId;
  const PagoDetalleScreen({super.key, required this.userId});
  @override
  ConsumerState<PagoDetalleScreen> createState() => _PagoDetalleScreenState();
}

class _PagoDetalleScreenState extends ConsumerState<PagoDetalleScreen> {
  bool _busy = false;
  void _reload() {
    ref.invalidate(payrollDetailProvider(widget.userId));
    ref.invalidate(payrollProvider);
    ref.invalidate(cajaProvider);
    ref.invalidate(cuentasProvider);
  }

  Future<void> _configure(OperationJson person) async {
    final config = objectValue(person['configuracion']);
    final amount = TextEditingController(text: '${config['montoBase'] ?? 0}');
    String period = config['periodicidad'] as String? ?? 'SEMANAL';
    await OperationForm.show(
      context,
      OperationForm(
        title: 'Configurar sueldo',
        fields: (refresh) => [
          DropdownButtonFormField<String>(
            initialValue: period,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Periodicidad'),
            items: const [
              DropdownMenuItem(value: 'SEMANAL', child: Text('Semanal')),
              DropdownMenuItem(value: 'QUINCENAL', child: Text('Quincenal')),
              DropdownMenuItem(value: 'MENSUAL', child: Text('Mensual')),
            ],
            onChanged: (value) {
              period = value!;
              refresh();
            },
          ),
          operationText(
            amount,
            'Sueldo base (S/)',
            money: true,
            allowZero: true,
          ),
          const Text(
            'Los recargos se incluyen automáticamente en la liquidación.',
          ),
        ],
        onSave: () async {
          await ref.read(operationsRepositoryProvider).configurePay(
            widget.userId,
            {'periodicidad': period, 'montoBase': moneyValue(amount.text)},
          );
          _reload();
        },
      ),
    );
    amount.dispose();
  }

  Future<void> _adjust(String kind) async {
    final amount = TextEditingController();
    final reason = TextEditingController();
    final title = switch (kind) {
      'BONO' => 'Asignar bono',
      'MULTA' => 'Registrar multa',
      'ADELANTO' => 'Adelanto de sueldo',
      _ => 'Descuento de planilla',
    };
    await OperationForm.show(
      context,
      OperationForm(
        title: title,
        fields: (_) => [
          operationText(amount, 'Monto (S/)', money: true),
          operationText(reason, 'Motivo'),
          if (kind == 'ADELANTO')
            const Text('El adelanto registra una salida de la caja abierta.'),
          if (kind == 'MULTA')
            const Text(
              'La multa genera los movimientos y cargos por cobrar definidos por la caja.',
            ),
        ],
        onSave: () async {
          final endpoint = kind == 'BONO'
              ? 'bonos'
              : kind == 'MULTA'
              ? 'multas'
              : 'ajustes';
          await ref
              .read(operationsRepositoryProvider)
              .create('/pagos/${widget.userId}/$endpoint', {
                'monto': moneyValue(amount.text),
                'motivo': reason.text.trim(),
                if (endpoint == 'ajustes') 'tipo': kind,
              });
          _reload();
        },
      ),
    );
    amount.dispose();
    reason.dispose();
  }

  Future<void> _pay(OperationJson person) async {
    final amount = TextEditingController(text: '0');
    final key = const Uuid().v4();
    OperationJson? submitted;
    final summary = objectValue(person['resumen']);
    await OperationForm.show(
      context,
      OperationForm(
        title: 'Liquidar periodo',
        submitLabel: 'Confirmar pago',
        fields: (_) => [
          Text(
            '${person['username']}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text('Total del periodo: ${soles(summary['total'])}'),
          Text('Ajustes: ${soles(summary['ajustes'])}'),
          Text('Neto pendiente: ${soles(summary['totalNetoPendiente'])}'),
          Text(
            'Cuenta por cobrar: ${soles(objectValue(person['cuentaPorCobrar'])['saldo'])}',
          ),
          AbsorbPointer(
            absorbing: submitted != null,
            child: operationText(
              amount,
              'Aplicar a la cuenta (S/)',
              money: true,
              allowZero: true,
            ),
          ),
          const Text(
            'El servidor calcula el neto definitivo y registra la liquidación del periodo.',
          ),
          if (submitted != null)
            const Text(
              'Al reintentar se conserva el mismo pago para evitar duplicados.',
            ),
        ],
        onSave: () async {
          submitted ??= {
            'descuentoCuenta': moneyValue(amount.text),
            'idempotencyKey': key,
          };
          await ref
              .read(operationsRepositoryProvider)
              .create('/pagos/${widget.userId}/pagar', submitted!);
          _reload();
        },
      ),
    );
    amount.dispose();
  }

  Future<void> _removeBonus(OperationJson bonus) async {
    if (_busy ||
        !await confirmOperation(
          context,
          'Retirar bono',
          '${bonus['motivo']} · ${soles(bonus['monto'])}',
        ))
      return;
    setState(() => _busy = true);
    try {
      await ref
          .read(operationsRepositoryProvider)
          .remove('/pagos/bonos/${bonus['id']}');
      _reload();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(payrollDetailProvider(widget.userId));
    final auth = ref.watch(authProvider);
    final manage = auth.hasPermission('pagos:gestionar');
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de pago')),
      body: result.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: TextButton(
            onPressed: _reload,
            child: const Text('No se pudo cargar. Reintentar'),
          ),
        ),
        data: (person) {
          final summary = objectValue(person['resumen']);
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  '${person['username']}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  '${objectValue(person['periodo'])['inicio'] ?? ''} — ${objectValue(person['periodo'])['fin'] ?? ''}',
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        for (final entry in const {
                          'montoBase': 'Sueldo base',
                          'bonos': 'Bonos',
                          'recargosIncluidos': 'Recargos',
                          'ajustes': 'Adelantos y descuentos',
                          'totalNetoPendiente': 'Neto pendiente',
                        }.entries)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Expanded(child: Text(entry.value)),
                                Text(
                                  soles(summary[entry.key]),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (manage)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => _configure(person),
                        child: const Text('Configurar sueldo'),
                      ),
                      OutlinedButton(
                        onPressed: () => _adjust('BONO'),
                        child: const Text('Bono'),
                      ),
                      OutlinedButton(
                        onPressed: () => _adjust('ADELANTO'),
                        child: const Text('Adelanto'),
                      ),
                      OutlinedButton(
                        onPressed: () => _adjust('DESCUENTO'),
                        child: const Text('Descuento'),
                      ),
                      if (auth.hasPermission('caja:movimientos'))
                        OutlinedButton(
                          onPressed: () => _adjust('MULTA'),
                          child: const Text('Multa'),
                        ),
                      FilledButton(
                        onPressed:
                            person['configuracion'] == null ||
                                person['pagoPeriodo'] != null
                            ? null
                            : () => _pay(person),
                        child: const Text('Liquidar periodo'),
                      ),
                    ],
                  ),
                const SizedBox(height: 20),
                Text(
                  'Bonos y ajustes',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final bonus in objectList(person['bonos']))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${bonus['motivo']}'),
                    subtitle: Text(soles(bonus['monto'])),
                    trailing: manage
                        ? IconButton(
                            tooltip: 'Retirar bono',
                            onPressed: _busy ? null : () => _removeBonus(bonus),
                            icon: const Icon(Icons.delete_outline),
                          )
                        : null,
                  ),
                for (final adjustment in objectList(person['ajustes']))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${adjustment['tipo']} · ${adjustment['motivo']}',
                    ),
                    subtitle: Text(soles(adjustment['monto'])),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Recargos por producto',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final surcharge in objectList(person['recargos']))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${objectValue(surcharge['producto'])['nombre'] ?? ''} · ${soles(surcharge['monto'])}',
                    ),
                    subtitle: Text(
                      '${objectValue(surcharge['venta'])['codigo'] ?? ''} · ${surcharge['motivo'] ?? ''}',
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Historial de liquidaciones',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (objectList(person['liquidaciones']).isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Todavía no hay liquidaciones.'),
                  ),
                for (final payment in objectList(person['liquidaciones']))
                  Card(
                    child: ExpansionTile(
                      title: Text('Neto: ${soles(payment['totalNeto'])}'),
                      subtitle: Text(
                        '${payment['periodoInicio']} — ${payment['periodoFin']}',
                      ),
                      childrenPadding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          'Bruto: ${soles(payment['totalBruto'])} · Cuenta: ${soles(payment['descuentoCuenta'])}',
                        ),
                        Text(
                          'Crédito aplicado: ${soles(payment['creditoCuentaAplicado'])} · Saldo a favor: ${soles(payment['saldoFavorGenerado'])}',
                        ),
                        for (final field in [
                          'bonosDetalle',
                          'ajustesDetalle',
                          'recargosDetalle',
                        ])
                          for (final detail in objectList(payment[field]))
                            ListTile(
                              title: Text(
                                '${detail['motivo'] ?? detail['producto'] ?? ''}',
                              ),
                              subtitle: Text(soles(detail['monto'])),
                            ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
