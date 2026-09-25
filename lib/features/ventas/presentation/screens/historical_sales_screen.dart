import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/sede_scope_provider.dart';
import '../../../../core/utils/business_time.dart';
import '../../../../core/widgets/operation_form.dart';
import '../../../../core/widgets/operation_page.dart';
import '../../../../core/widgets/responsive_form.dart';
import '../../../../core/widgets/sede_scope_selector.dart';
import '../../../operaciones/data/operations_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'nueva_venta_view.dart';

final historicalBoxesProvider = FutureProvider.autoDispose
    .family<OperationsPage, (int, String?)>((ref, query) {
      ref.watch(authProvider.select((state) => state.user?.id));
      return ref
          .watch(operationsRepositoryProvider)
          .list(
            '/caja/historial',
            sedeId: ref.watch(globalSedeIdProvider),
            page: query.$1,
            filters: {'estado': 'CERRADA', 'fecha': ?query.$2},
          );
    });
final historicalSalesProvider = FutureProvider.autoDispose
    .family<OperationsPage, (String, int)>(
      (ref, query) => ref
          .watch(operationsRepositoryProvider)
          .list(
            '/ventas',
            sedeId: ref.watch(globalSedeIdProvider),
            page: query.$2,
            filters: {'cajaSesionId': query.$1},
          ),
    );

class HistoricalSalesScreen extends ConsumerStatefulWidget {
  const HistoricalSalesScreen({super.key});
  @override
  ConsumerState<HistoricalSalesScreen> createState() =>
      _HistoricalSalesScreenState();
}

class _HistoricalSalesScreenState extends ConsumerState<HistoricalSalesScreen> {
  int _page = 1;
  String? _date;
  Future<void> _create() async {
    final sede = ref.read(globalSedeIdProvider);
    if (sede == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecciona una sede.')));
      return;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(
        businessDate(),
      ).subtract(const Duration(days: 1)),
      firstDate: DateTime(2020),
      lastDate: DateTime.parse(
        businessDate(),
      ).subtract(const Duration(days: 1)),
    );
    if (picked == null || !mounted) return;
    final date = picked.toIso8601String().substring(0, 10);
    await OperationForm.show(
      context,
      OperationForm(
        title: 'Crear caja histórica',
        submitLabel: 'Crear caja',
        fields: (_) => [
          Text('Fecha: $date'),
          const Text(
            'Los registros afectarán el cuadre original y quedarán auditados.',
          ),
        ],
        onSave: () async {
          await ref.read(operationsRepositoryProvider).create('/caja/sin-luz', {
            'sedeId': sede,
            'fecha': date,
          });
          ref.invalidate(historicalBoxesProvider);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(globalSedeIdProvider, (_, _) => setState(() => _page = 1));
    final selected = ref.watch(globalSedeIdProvider);
    final result = ref.watch(historicalBoxesProvider((_page, _date)));
    return OperationPage(
      title: 'Ventas sin luz',
      subtitle: 'Registro de ventas de días anteriores en su caja original',
      loading: result.isLoading,
      error: result.error,
      page: _page,
      pages: result.valueOrNull?.pages ?? 1,
      reload: () async => ref.invalidate(historicalBoxesProvider),
      onPage: (page) => setState(() => _page = page),
      onCreate: selected == null ? null : _create,
      filters: [
        const SedeScopeSelector(),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.date_range),
              label: Text(_date ?? 'Filtrar por fecha'),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.parse(_date ?? businessDate()),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.parse(businessDate()),
                );
                if (picked != null && mounted)
                  setState(() {
                    _date = picked.toIso8601String().substring(0, 10);
                    _page = 1;
                  });
              },
            ),
            if (_date != null)
              TextButton(
                onPressed: () => setState(() {
                  _date = null;
                  _page = 1;
                }),
                child: const Text('Limpiar'),
              ),
          ],
        ),
      ],
      cards: (result.valueOrNull?.items ?? [])
          .map(
            (box) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.history),
                    Text(
                      '${objectValue(box['sede'])['nombre'] ?? ''}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text('${box['abiertaAt']}'),
                    Text('Apertura: ${soles(box['montoApertura'])}'),
                    Text('Cierre: ${soles(box['montoDeclaradoCierre'])}'),
                    FilledButton(
                      onPressed: selected == null
                          ? null
                          : () => ResponsiveForm.showPage(
                              context: context,
                              page: _HistoricalBoxScreen(box: box),
                            ),
                      child: const Text('Ver caja'),
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

class _HistoricalBoxScreen extends ConsumerStatefulWidget {
  final OperationJson box;
  const _HistoricalBoxScreen({required this.box});
  @override
  ConsumerState<_HistoricalBoxScreen> createState() =>
      _HistoricalBoxScreenState();
}

class _HistoricalBoxScreenState extends ConsumerState<_HistoricalBoxScreen> {
  int _page = 1;
  String get _id => '${widget.box['id']}';
  void _reload() {
    ref.invalidate(historicalSalesProvider);
    ref.invalidate(historicalBoxesProvider);
  }

  Future<void> _count() async {
    final amount = TextEditingController();
    final reason = TextEditingController();
    String type = 'APERTURA';
    await OperationForm.show(
      context,
      OperationForm(
        title: 'Corregir conteo histórico',
        fields: (refresh) => [
          DropdownButtonFormField<String>(
            initialValue: type,
            isExpanded: true,
            items: ['APERTURA', 'PRECUADRE', 'CIERRE']
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
            onChanged: (value) {
              type = value!;
              refresh();
            },
          ),
          operationText(amount, 'Monto (S/)', money: true, allowZero: true),
          operationText(reason, 'Motivo de la corrección', maxLength: 500),
        ],
        onSave: () async {
          await ref
              .read(operationsRepositoryProvider)
              .update('/caja/sin-luz/$_id/conteo', {
                'tipo': type,
                'monto': moneyValue(amount.text),
                'motivo': reason.text.trim(),
              });
          _reload();
        },
      ),
    );
    amount.dispose();
    reason.dispose();
  }

  Future<void> _annul(OperationJson sale) async {
    final reason = TextEditingController();
    await OperationForm.show(
      context,
      OperationForm(
        title: 'Anular venta histórica',
        fields: (_) => [
          Text('${sale['codigo']}'),
          operationText(reason, 'Motivo'),
        ],
        onSave: () async {
          await ref.read(operationsRepositoryProvider).create(
            '/ventas/sin-luz/${sale['id']}/anular',
            {'motivo': reason.text.trim()},
          );
          _reload();
        },
      ),
    );
    reason.dispose();
  }

  Future<void> _sale() async {
    final day = businessDate(DateTime.parse('${widget.box['abiertaAt']}'));
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 12, minute: 0),
    );
    if (time == null || !mounted) return;
    final date = DateTime.parse(
      '${day}T${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00-05:00',
    ).toUtc().toIso8601String();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text('Venta histórica · $day')),
          body: NuevaVentaView(historicalCajaId: _id, historicalDate: date),
        ),
      ),
    );
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(historicalSalesProvider((_id, _page)));
    return Scaffold(
      appBar: AppBar(title: const Text('Caja histórica')),
      body: OperationPage(
        title: 'Ventas registradas',
        subtitle: 'Las correcciones recalculan el cuadre original.',
        loading: result.isLoading,
        error: result.error,
        page: _page,
        pages: result.valueOrNull?.pages ?? 1,
        reload: () async => _reload(),
        onPage: (page) => setState(() => _page = page),
        onCreate: _sale,
        filters: [
          OutlinedButton.icon(
            onPressed: _count,
            icon: const Icon(Icons.edit_note),
            label: const Text('Corregir conteo'),
          ),
        ],
        cards: (result.valueOrNull?.items ?? [])
            .map(
              (sale) => Card(
                child: ListTile(
                  title: Text('${sale['codigo']} · ${soles(sale['total'])}'),
                  subtitle: Text('${sale['estado']}'),
                  trailing: sale['estado'] == 'ANULADA'
                      ? null
                      : IconButton(
                          tooltip: 'Anular venta',
                          onPressed: () => _annul(sale),
                          icon: const Icon(Icons.cancel_outlined),
                        ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
