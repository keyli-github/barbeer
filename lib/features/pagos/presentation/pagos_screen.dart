import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/providers/sede_scope_provider.dart';
import '../../../core/widgets/operation_form.dart';
import '../../../core/widgets/operation_page.dart';
import '../../../core/widgets/responsive_form.dart';
import '../../../core/widgets/sede_scope_selector.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../operaciones/data/operations_repository.dart';
import '../../recargo/data/recargo_control_repository.dart';
import '../../recargo/presentation/providers/recargo_control_provider.dart';
import '../../caja/presentation/providers/caja_provider.dart';
import '../../cuentas/presentation/providers/cuentas_provider.dart';
import 'manual_recargo_rules.dart';

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
final payrollRecargoStatusProvider =
    FutureProvider.autoDispose<RecargoControlData>(
      (ref) => ref.watch(recargoControlRepositoryProvider).estado(),
    );
final uncertainManualRecargoEmployeesProvider = StateProvider<Set<String>>(
  (ref) => const {},
);
final uncertainManualRecargoDeletesProvider = StateProvider<Set<String>>(
  (ref) => const {},
);

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
    ref.listen(globalSedeIdProvider, (_, _) => setState(() => _page = 1));
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
  final _feedbackMessengerKey = GlobalKey<ScaffoldMessengerState>();
  bool _busy = false;
  String? _pendingManualRecargoId;

  void _reload() {
    ref.invalidate(payrollDetailProvider(widget.userId));
    ref.invalidate(payrollProvider);
    ref.invalidate(cajaProvider);
    ref.invalidate(cuentasProvider);
  }

  Future<bool> _refreshPayroll() async {
    ref.invalidate(payrollDetailProvider(widget.userId));
    ref.invalidate(payrollProvider);
    try {
      await ref.read(payrollDetailProvider(widget.userId).future);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _showMutationFeedback(String message, {bool isError = false}) {
    final messenger = _feedbackMessengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        ),
      );
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

  Future<void> _createManualRecargo(
    OperationJson person,
    ManualRecargoPeriod period,
  ) async {
    if (_busy ||
        ref
            .read(uncertainManualRecargoEmployeesProvider)
            .contains(widget.userId)) {
      return;
    }
    final amount = TextEditingController();
    final reason = TextEditingController();
    final date = TextEditingController(text: period.initialDateKey());
    var outcomeUnknown = false;

    Future<void> pickDate(VoidCallback refresh) async {
      final current = DateTime.tryParse(date.text) ?? period.inicio;
      final selected = await showDatePicker(
        context: context,
        initialDate: current,
        firstDate: period.inicio,
        lastDate: period.fin,
        helpText: 'Fecha del recargo manual',
      );
      if (selected == null) return;
      date.text = period.dateKey(selected);
      refresh();
    }

    final result = await OperationForm.show(
      context,
      OperationForm(
        title: 'Agregar recargo manual',
        submitLabel: 'Agregar recargo',
        fields: (refresh) => [
          Text(
            'Empleado: ${person['username'] ?? ''}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          TextFormField(
            key: const ValueKey('manual-recargo-amount'),
            controller: amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Monto (S/)'),
            validator: moneyValidator,
          ),
          TextFormField(
            key: const ValueKey('manual-recargo-reason'),
            controller: reason,
            maxLength: 240,
            decoration: const InputDecoration(labelText: 'Motivo'),
            validator: requiredText,
          ),
          TextFormField(
            key: const ValueKey('manual-recargo-date'),
            controller: date,
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'Fecha del período',
              helperText: 'Selecciona una fecha dentro del período actual.',
              suffixIcon: IconButton(
                tooltip: 'Elegir fecha',
                onPressed: () => pickDate(refresh),
                icon: const Icon(Icons.calendar_month_outlined),
              ),
            ),
            validator: period.validateDate,
            onTap: () => pickDate(refresh),
          ),
          Text(
            'Período de pago: ${period.dateKey(period.inicio)} – ${period.dateKey(period.fin)}.',
          ),
        ],
        onSave: () async {
          try {
            await ref
                .read(operationsRepositoryProvider)
                .createManualRecargo(
                  usuarioId: widget.userId,
                  monto: (moneyValue(amount.text) * 100).round() / 100,
                  motivo: reason.text.trim(),
                  fecha: date.text,
                );
          } catch (error) {
            if (manualRecargoOutcomeIsUncertain(error)) {
              outcomeUnknown = true;
              final uncertainEmployees = ref.read(
                uncertainManualRecargoEmployeesProvider,
              );
              ref.read(uncertainManualRecargoEmployeesProvider.notifier).state =
                  {...uncertainEmployees, widget.userId};
              await _refreshPayroll();
              return;
            }
            if (error is AppException && error.statusCode == 409) {
              ref.invalidate(payrollRecargoStatusProvider);
              await _refreshPayroll();
            }
            rethrow;
          }
        },
      ),
    );

    amount.dispose();
    reason.dispose();
    date.dispose();
    if (!mounted) return;

    if (outcomeUnknown) {
      _showMutationFeedback(
        'No se pudo confirmar el resultado. Revisa la nómina y no repitas el envío.',
        isError: true,
      );
      return;
    }
    if (result == true) {
      final refreshed = await _refreshPayroll();
      if (!mounted) return;
      _showMutationFeedback(
        refreshed
            ? 'Recargo manual agregado al pago del período.'
            : 'Recargo manual agregado, pero no se pudo actualizar la nómina.',
        isError: !refreshed,
      );
    }
  }

  Future<void> _removeManualRecargo(OperationJson recargo) async {
    final recargoId = '${recargo['id'] ?? ''}';
    if (_busy ||
        recargoId.isEmpty ||
        ref.read(uncertainManualRecargoDeletesProvider).contains(recargoId)) {
      return;
    }
    final confirmed = await confirmOperation(
      context,
      'Retirar recargo manual',
      'Se retirará el recargo "${recargo['motivo'] ?? ''}". Solo se pueden retirar recargos no liquidados.',
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _busy = true;
      _pendingManualRecargoId = recargoId;
    });
    try {
      await ref
          .read(operationsRepositoryProvider)
          .removeManualRecargo(recargoId);
      final refreshed = await _refreshPayroll();
      if (mounted) {
        _showMutationFeedback(
          refreshed
              ? 'Recargo manual retirado.'
              : 'Recargo manual retirado, pero no se pudo actualizar la nómina.',
          isError: !refreshed,
        );
      }
    } catch (error) {
      if (manualRecargoOutcomeIsUncertain(error)) {
        if (mounted) {
          final uncertainDeletes = ref.read(
            uncertainManualRecargoDeletesProvider,
          );
          ref.read(uncertainManualRecargoDeletesProvider.notifier).state = {
            ...uncertainDeletes,
            recargoId,
          };
        }
        await _refreshPayroll();
        if (mounted) {
          _showMutationFeedback(
            'No se pudo confirmar la retirada. Revisa la nómina y no repitas la operación.',
            isError: true,
          );
        }
      } else {
        if (error is AppException &&
            (error.statusCode == 404 || error.statusCode == 409)) {
          await _refreshPayroll();
        }
        if (mounted) {
          _showMutationFeedback(
            error is AppException
                ? error.message
                : 'No se pudo retirar el recargo manual.',
            isError: true,
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _pendingManualRecargoId = null;
        });
      }
    }
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
        )) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(operationsRepositoryProvider)
          .remove('/pagos/bonos/${bonus['id']}');
      _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(payrollDetailProvider(widget.userId));
    final auth = ref.watch(authProvider);
    final manage =
        auth.user?.isSuperAdmin == true ||
        auth.hasPermission('pagos:gestionar');
    final recargoStatus = manage
        ? ref.watch(payrollRecargoStatusProvider)
        : null;
    return ScaffoldMessenger(
      key: _feedbackMessengerKey,
      child: Scaffold(
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
            final periodData = objectValue(person['periodo']);
            final recargoPeriod = ManualRecargoPeriod.tryParse(
              periodData['inicio'],
              periodData['fin'],
            );
            final recargosOcultos = recargoStatus?.valueOrNull?.oculto;
            final uncertainCreateEmployees = ref.watch(
              uncertainManualRecargoEmployeesProvider,
            );
            final uncertainDeleteIds = ref.watch(
              uncertainManualRecargoDeletesProvider,
            );
            final recargoActionsReady =
                manage &&
                recargoStatus?.hasValue == true &&
                recargoStatus?.hasError != true &&
                recargoStatus?.isLoading != true &&
                recargosOcultos == false;
            final recargosManuales = objectList(person['recargosManuales']);
            final createOutcomeUnknown = uncertainCreateEmployees.contains(
              widget.userId,
            );
            final deleteOutcomeUnknown = recargosManuales.any(
              (recargo) =>
                  uncertainDeleteIds.contains('${recargo['id'] ?? ''}'),
            );
            String? recargoActionDisabledReason() {
              if (createOutcomeUnknown) {
                return 'Verifica el resultado anterior antes de intentar otro recargo.';
              }
              if (recargoStatus?.isLoading ?? false) {
                return 'Verificando el estado de los recargos.';
              }
              if (recargoStatus?.hasError ?? false) {
                return 'No se pudo verificar si los recargos están ocultos.';
              }
              if (recargosOcultos == true) {
                return 'Restaura los recargos antes de agregar o retirar uno.';
              }
              if (recargoPeriod == null) {
                return 'No se pudo verificar el período de pago actual.';
              }
              if (person['configuracion'] == null) {
                return 'Primero configura el pago del empleado.';
              }
              if (person['pagoPeriodo'] != null) {
                return 'El período actual ya fue liquidado.';
              }
              return null;
            }

            final canAddManualRecargo =
                recargoActionsReady &&
                recargoPeriod != null &&
                person['configuracion'] != null &&
                person['pagoPeriodo'] == null &&
                !createOutcomeUnknown;
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
                        Tooltip(
                          message:
                              recargoActionDisabledReason() ??
                              'Agregar recargo manual',
                          child: OutlinedButton.icon(
                            key: ValueKey(
                              'manual-recargo-add-${widget.userId}',
                            ),
                            onPressed: canAddManualRecargo
                                ? () => _createManualRecargo(
                                    person,
                                    recargoPeriod,
                                  )
                                : null,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 44),
                            ),
                            icon: const Icon(Icons.receipt_long_outlined),
                            label: const Text('Recargo manual'),
                          ),
                        ),
                      ],
                    ),
                  if (manage && (recargoStatus?.isLoading ?? false))
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Verificando el estado de los recargos…'),
                    ),
                  if (manage && (recargoStatus?.hasError ?? false))
                    TextButton.icon(
                      onPressed: () =>
                          ref.invalidate(payrollRecargoStatusProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text(
                        'No se pudo verificar el estado de los recargos. Reintentar',
                      ),
                    ),
                  if (manage && recargosOcultos == true)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Los recargos están ocultos. Restáuralos antes de gestionarlos.',
                      ),
                    ),
                  if (manage && recargoPeriod == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'No se pudo verificar el período actual; actualiza la nómina.',
                      ),
                    ),
                  if (createOutcomeUnknown || deleteOutcomeUnknown)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Hay una operación de recargo sin confirmar. Revisa la nómina y no repitas el envío.',
                      ),
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
                              onPressed: _busy
                                  ? null
                                  : () => _removeBonus(bonus),
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
                    'Recargos manuales pendientes',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (recargosManuales.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Sin recargos manuales pendientes.'),
                    ),
                  for (final surcharge in recargosManuales)
                    Builder(
                      builder: (context) {
                        final recargoId = '${surcharge['id'] ?? ''}';
                        final creator =
                            '${objectValue(surcharge['creadoPor'])['username'] ?? ''}';
                        final fecha = '${surcharge['fecha'] ?? ''}';
                        final dateLabel = fecha.length >= 10
                            ? fecha.substring(0, 10)
                            : fecha;
                        final outcomeUnknown = uncertainDeleteIds.contains(
                          recargoId,
                        );
                        final deleteEnabled =
                            recargoActionsReady &&
                            !_busy &&
                            !outcomeUnknown &&
                            recargoId.isNotEmpty;
                        return ListTile(
                          key: ValueKey('manual-recargo-$recargoId'),
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Recargo manual · ${surcharge['motivo'] ?? ''}',
                          ),
                          subtitle: Text(
                            [
                              dateLabel,
                              if (creator.isNotEmpty) creator,
                            ].where((value) => value.isNotEmpty).join(' · '),
                          ),
                          trailing: manage
                              ? IconButton(
                                  key: ValueKey(
                                    'manual-recargo-remove-$recargoId',
                                  ),
                                  tooltip: outcomeUnknown
                                      ? 'Resultado sin confirmar; no repitas la retirada.'
                                      : 'Retirar recargo manual no liquidado',
                                  onPressed: deleteEnabled
                                      ? () => _removeManualRecargo(surcharge)
                                      : null,
                                  constraints: const BoxConstraints(
                                    minWidth: 44,
                                    minHeight: 44,
                                  ),
                                  icon: _pendingManualRecargoId == recargoId
                                      ? const SizedBox.square(
                                          dimension: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.delete_outline),
                                )
                              : null,
                        );
                      },
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
      ),
    );
  }
}
