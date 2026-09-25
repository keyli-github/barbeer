import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/providers/sede_scope_provider.dart';
import '../../../core/utils/business_time.dart';
import '../../../core/widgets/operation_form.dart';
import '../../../core/widgets/operation_page.dart';
import '../../../core/widgets/sede_scope_selector.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../operaciones/data/operations_repository.dart';
import '../../caja/presentation/providers/caja_provider.dart';
import '../../cuentas/presentation/providers/cuentas_provider.dart';
import '../../pagos/presentation/pagos_screen.dart';

final expensesProvider = FutureProvider.autoDispose
    .family<OperationsPage, (int, String?, String?)>((ref, query) {
      ref.watch(authProvider.select((state) => state.user?.id));
      return ref
          .watch(operationsRepositoryProvider)
          .list(
            '/gastos-internos',
            sedeId: ref.watch(globalSedeIdProvider),
            page: query.$1,
            filters: {'desde': ?query.$2, 'hasta': ?query.$3},
          );
    });

class GastosInternosScreen extends ConsumerStatefulWidget {
  const GastosInternosScreen({super.key});
  @override
  ConsumerState<GastosInternosScreen> createState() =>
      _GastosInternosScreenState();
}

class _GastosInternosScreenState extends ConsumerState<GastosInternosScreen> {
  int _page = 1;
  DateTimeRange? _range;
  bool _busy = false;
  final _destinations = const {
    'GENERAL': 'Gasto general',
    'CUENTA_PERSONAL': 'Cuenta del personal',
    'ADELANTO': 'Adelanto de sueldo',
    'MULTA': 'Multa',
  };

  void _reload() {
    ref.invalidate(expensesProvider);
    ref.invalidate(cajaProvider);
    ref.invalidate(cuentasProvider);
    ref.invalidate(payrollProvider);
  }

  Future<void> _edit([OperationJson? item]) async {
    final repo = ref.read(operationsRepositoryProvider);
    final sede = ref.read(globalSedeIdProvider);
    if (item == null && sede == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona una sede para registrar el gasto.'),
        ),
      );
      return;
    }
    final reason = TextEditingController(text: item?['motivo'] as String?);
    final amount = TextEditingController(
      text: item == null ? '' : '${item['monto']}',
    );
    final date = TextEditingController(text: businessDate());
    String destination = 'GENERAL';
    String? staffId;
    final staff = item == null
        ? repo.expenseStaff(sede!)
        : Future.value(<OperationJson>[]);
    if (!mounted) return;
    await OperationForm.show(
      context,
      OperationForm(
        title: item == null ? 'Nuevo gasto interno' : 'Editar gasto',
        fields: (refresh) => [
          if (item == null) ...[
            TextFormField(
              controller: date,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Fecha del gasto',
                suffixIcon: Icon(Icons.calendar_today),
              ),
              onTap: () async {
                final chosen = await showDatePicker(
                  context: context,
                  initialDate: DateTime.parse(date.text),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.parse(businessDate()),
                );
                if (chosen != null) {
                  date.text = chosen.toIso8601String().substring(0, 10);
                  refresh();
                }
              },
            ),
            DropdownButtonFormField<String>(
              initialValue: destination,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Destino'),
              items: _destinations.entries
                  .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  )
                  .toList(),
              onChanged: (value) {
                destination = value!;
                staffId = null;
                refresh();
              },
            ),
            if (destination != 'GENERAL')
              FutureBuilder<List<OperationJson>>(
                future: staff,
                builder: (context, snapshot) {
                  if (snapshot.hasError)
                    return const Text(
                      'No se pudo cargar el personal. Cierra e intenta nuevamente.',
                    );
                  if (!snapshot.hasData) return const LinearProgressIndicator();
                  return DropdownButtonFormField<String>(
                    key: ValueKey(destination),
                    initialValue: staffId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Personal'),
                    validator: requiredText,
                    items: snapshot.data!
                        .map(
                          (person) => DropdownMenuItem(
                            value: '${person['id']}',
                            child: Text('${person['username']}'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      staffId = value;
                      refresh();
                    },
                  );
                },
              ),
            const Text(
              'El gasto se vincula a la caja disponible para la sede y fecha seleccionadas.',
            ),
          ],
          operationText(reason, 'Motivo', maxLength: 240),
          operationText(amount, 'Monto (S/)', money: true),
        ],
        onSave: () async {
          final payload = {
            'motivo': reason.text.trim(),
            'monto': moneyValue(amount.text),
          };
          if (item != null) {
            await repo.update('/gastos-internos/${item['id']}', payload);
          } else {
            if (destination != 'GENERAL' && staffId == null)
              throw const AppException(message: 'Selecciona un empleado.');
            final target = objectValue(
              (await repo.expenseDestination(sede!, date.text))['caja'],
            );
            if (target['disponible'] != true)
              throw const AppException(
                message: 'No hay una caja disponible para esa fecha y sede.',
              );
            await repo.create('/gastos-internos', {
              ...payload,
              'sedeId': sede,
              'fecha': date.text,
              'destino': destination,
              if (destination != 'GENERAL') 'personalUsuarioId': staffId,
            });
          }
          _reload();
        },
      ),
    );
    reason.dispose();
    amount.dispose();
    date.dispose();
  }

  Future<void> _delete(OperationJson item) async {
    if (_busy ||
        !await confirmOperation(
          context,
          'Eliminar gasto',
          'Se revertirán los movimientos asociados a este gasto.',
        ))
      return;
    setState(() => _busy = true);
    try {
      await ref
          .read(operationsRepositoryProvider)
          .remove('/gastos-internos/${item['id']}');
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
    ref.listen(globalSedeIdProvider, (_, __) => setState(() => _page = 1));
    final auth = ref.watch(authProvider);
    final result = ref.watch(
      expensesProvider((
        _page,
        _range?.start.toIso8601String().substring(0, 10),
        _range?.end.toIso8601String().substring(0, 10),
      )),
    );
    final data = result.valueOrNull;
    return OperationPage(
      title: 'Gastos internos',
      subtitle: 'Control de gastos y cargos al personal',
      loading: result.isLoading,
      error: result.error,
      page: _page,
      pages: data?.pages ?? 1,
      reload: () async => _reload(),
      onPage: (page) => setState(() => _page = page),
      onCreate: auth.hasPermission('gastos-internos:crear')
          ? () => _edit()
          : null,
      filters: [
        const SedeScopeSelector(),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.date_range),
              label: Text(
                _range == null
                    ? 'Filtrar fechas'
                    : '${_range!.start.toIso8601String().substring(0, 10)} — ${_range!.end.toIso8601String().substring(0, 10)}',
              ),
              onPressed: () async {
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  initialDateRange: _range,
                );
                if (range != null && mounted)
                  setState(() {
                    _range = range;
                    _page = 1;
                  });
              },
            ),
            if (_range != null)
              TextButton(
                onPressed: () => setState(() {
                  _range = null;
                  _page = 1;
                }),
                child: const Text('Limpiar'),
              ),
          ],
        ),
        if (data != null && !result.isLoading && !result.hasError)
          Text(
            '${data.total} gastos · Total ${soles(data.totalAmount)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
      ],
      cards: (data?.items ?? [])
          .map(
            (item) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      soles(item['monto']),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${item['motivo']}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text('${item['fecha']}'.split('T').first),
                    Text(
                      '${objectValue(item['sede'])['nombre'] ?? ''} · ${_destinations[item['destino']] ?? item['destino']}',
                    ),
                    if (item['personalUsuario'] != null)
                      Text(
                        '${objectValue(item['personalUsuario'])['username']}',
                      ),
                    Wrap(
                      children: [
                        if (auth.hasPermission('gastos-internos:editar'))
                          TextButton.icon(
                            onPressed: _busy ? null : () => _edit(item),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Editar'),
                          ),
                        if (auth.hasPermission('gastos-internos:eliminar'))
                          TextButton.icon(
                            onPressed: _busy ? null : () => _delete(item),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Eliminar'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
