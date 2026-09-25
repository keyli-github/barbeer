import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/operation_page.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../ventas/data/models/venta_models.dart';
import '../../ventas/presentation/providers/ventas_provider.dart';
import '../../ventas/presentation/widgets/seller_authorization.dart';

final offlineSalesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      ref.watch(authProvider.select((state) => state.user?.id));
      final store = ref.watch(offlineStoreProvider);
      final scope = await store.scope();
      return scope == null ? [] : (await store.sales(scope)).reversed.toList();
    });

class OfflineSalesScreen extends ConsumerStatefulWidget {
  const OfflineSalesScreen({super.key});
  @override
  ConsumerState<OfflineSalesScreen> createState() => _OfflineSalesScreenState();
}

class _OfflineSalesScreenState extends ConsumerState<OfflineSalesScreen> {
  bool _busy = false;
  Future<void> _retry(Map<String, dynamic> record) async {
    if (record['status'] == 'DRAFT') return;
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final stored = Map<String, dynamic>.from(record['payload'] as Map);
      if (stored['kind'] == 'HTTP_COMMAND') {
        await ApiClient.instance.replayCommand(stored);
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Operación confirmada por el servidor.'),
            ),
          );
        return;
      }
      var payload = CreateVentaPayload.fromRecovery(
        Map<String, dynamic>.from(record['payload'] as Map),
      );
      final repo = ref.read(ventasRepositoryProvider);
      if (ref.read(authProvider).user?.rol == 'VENDEDORA') {
        final pin = await requestSellerAuthorization(context);
        if (pin == null || !mounted) return;
        await repo.validarClaveSuperadmin(pin);
        payload = payload.withEphemeralPin(pin);
      }
      await repo.crearVenta(payload: payload);
      if (!mounted) return;
      invalidateSaleSideEffects(ref);
      ref.invalidate(ventasListProvider(false));
      ref.invalidate(ventasListProvider(true));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Venta sincronizada con el servidor.')),
      );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) {
        ref.invalidate(offlineSalesProvider);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(offlineSalesProvider);
    return OperationPage(
      title: 'Alertas y revisiones',
      subtitle:
          'Revisa operaciones pendientes y borradores manuales antes de volver a registrarlas.',
      loading: result.isLoading,
      error: result.error,
      page: 1,
      pages: 1,
      filters: const [],
      reload: () async => ref.invalidate(offlineSalesProvider),
      onPage: (_) {},
      cards: (result.valueOrNull ?? []).map((record) {
        final payload = Map<String, dynamic>.from(record['payload'] as Map);
        final status = record['status'];
        final isDraft = status == 'DRAFT';
        final isCommand = payload['kind'] == 'HTTP_COMMAND';
        final manualReviewOnly = isDraft || (!isCommand && status != 'SYNCED');
        final items = (payload['items'] as List? ?? const [])
            .whereType<Map>()
            .toList();
        final reviewItems = (payload['_manualReviewItems'] as List? ?? const [])
            .whereType<Map>()
            .toList();
        final displayedItems = reviewItems.isNotEmpty ? reviewItems : items;
        final originalCajaId = payload['_originalCajaId'];

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  status == 'SYNCED'
                      ? Icons.check_circle_outline
                      : isDraft
                      ? Icons.edit_note_rounded
                      : Icons.sync_problem,
                ),
                const SizedBox(height: 8),
                Text(
                  status == 'SYNCED'
                      ? 'Operación sincronizada'
                      : isDraft
                      ? 'Borrador para revisión manual (sin confirmar)'
                      : status == 'REVIEW'
                      ? 'Requiere revisión manual'
                      : manualReviewOnly
                      ? 'Venta pendiente de revisión manual'
                      : 'Pendiente de sincronización',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  isCommand
                      ? '${payload['method']} ${payload['path']}'
                      : isDraft
                      ? 'Borrador local de venta'
                      : manualReviewOnly
                      ? 'Venta sin confirmación local'
                      : 'Registro de venta',
                ),
                if (manualReviewOnly) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Sin confirmación guardada. Esta venta no se sincroniza automáticamente; consulta ventas registradas antes de volver a ingresarla.',
                  ),
                  Text(
                    'Sede: ${payload['sedeId'] ?? 'asignada desde la cuenta autenticada'}',
                  ),
                  Text(
                    'Caja original: ${originalCajaId is String && originalCajaId.isNotEmpty ? originalCajaId : 'no verificada'}',
                  ),
                  Text(
                    'Estado de pago solicitado: ${payload['estadoConciliacion'] ?? 'no indicado'}',
                  ),
                  ...displayedItems.map((item) {
                    final quantity =
                        item['quantity'] ?? item['cantidad'] ?? '?';
                    final productName = item['productName'];
                    final productId = item['productId'] ?? item['productoId'];
                    final label =
                        productName is String && productName.isNotEmpty
                        ? productName
                        : 'Producto ${productId ?? 'sin identificador'}';
                    return Text('$quantity × $label');
                  }),
                ],
                Text('${record['createdAt']}'),
                if (manualReviewOnly)
                  const Text('Clave de idempotencia / revisión:'),
                SelectableText(
                  '${record['id']}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (record['error'] != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('${record['error']}'),
                  ),
                if (status != 'SYNCED' && !manualReviewOnly)
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _retry(record),
                    icon: const Icon(Icons.sync),
                    label: const Text('Reintentar operación'),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
