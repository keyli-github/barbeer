import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/providers/sede_scope_provider.dart';
import '../../../../core/utils/business_time.dart';
import '../../../operaciones/data/operations_repository.dart';

final cashPeriodProvider = FutureProvider.autoDispose
    .family<OperationJson, (String, String)>((ref, dates) async {
      final result = await ApiClient.instance.get(
        '/caja/resumen-periodo',
        queryParameters: {
          'sedeId': ?ref.watch(globalSedeIdProvider),
          'fechaInicio': dates.$1,
          'fechaFin': dates.$2,
        },
      );
      return objectValue(result.data);
    });

class CashPeriodScreen extends ConsumerStatefulWidget {
  const CashPeriodScreen({super.key});
  @override
  ConsumerState<CashPeriodScreen> createState() => _CashPeriodScreenState();
}

class _CashPeriodScreenState extends ConsumerState<CashPeriodScreen> {
  late DateTimeRange _range = DateTimeRange(
    start: DateTime.parse(businessDate()).subtract(const Duration(days: 6)),
    end: DateTime.parse(businessDate()),
  );
  @override
  Widget build(BuildContext context) {
    final dates = (
      _range.start.toIso8601String().substring(0, 10),
      _range.end.toIso8601String().substring(0, 10),
    );
    final result = ref.watch(cashPeriodProvider(dates));
    return Scaffold(
      appBar: AppBar(title: const Text('Resumen del periodo')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.date_range),
              label: Text('${dates.$1} — ${dates.$2}'),
              onPressed: () async {
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.parse(businessDate()),
                  initialDateRange: _range,
                );
                if (range != null && mounted) setState(() => _range = range);
              },
            ),
            const SizedBox(height: 16),
            result.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Column(
                children: [
                  Text('$error'),
                  TextButton(
                    onPressed: () => ref.invalidate(cashPeriodProvider(dates)),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
              data: (data) => Column(
                children: [
                  for (final metric in const {
                    'totalVentasNeto': 'Ventas netas',
                    'costoProductosVendidos': 'Costo de productos',
                    'utilidadBruta': 'Utilidad bruta',
                    'otrosGastos': 'Otros gastos',
                    'utilidadNeta': 'Utilidad neta',
                  }.entries)
                    Card(
                      child: ListTile(
                        title: Text(metric.value),
                        subtitle: Text(
                          soles(data[metric.key]),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ),
                  Card(
                    child: ListTile(
                      title: const Text('Unidades vendidas'),
                      subtitle: Text('${data['unidadesVendidas'] ?? 0}'),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      title: const Text('Margen neto'),
                      subtitle: Text(
                        '${decimalValue(data['margenNeto']).toStringAsFixed(2)} %',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
