import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/offline/offline_store.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/operation_page.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../ventas/data/models/venta_models.dart';
import '../../ventas/presentation/providers/ventas_provider.dart';
import '../../ventas/presentation/widgets/seller_authorization.dart';

final offlineSalesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      ref.watch(authProvider.select((state) => state.user?.id));
      final scope = await OfflineStore.instance.scope();
      return scope == null
          ? []
          : (await OfflineStore.instance.sales(scope)).reversed.toList();
    });

class OfflineSalesScreen extends ConsumerStatefulWidget {
  const OfflineSalesScreen({super.key});
  @override
  ConsumerState<OfflineSalesScreen> createState() => _OfflineSalesScreenState();
}

class _OfflineSalesScreenState extends ConsumerState<OfflineSalesScreen> {
  bool _busy = false;
  Future<void> _retry(Map<String, dynamic> record) async {
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
          'Recupera ventas pendientes conservando su identificador original.',
      loading: result.isLoading,
      error: result.error,
      page: 1,
      pages: 1,
      filters: const [],
      reload: () async => ref.invalidate(offlineSalesProvider),
      onPage: (_) {},
      cards: (result.valueOrNull ?? [])
          .map(
            (record) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      record['status'] == 'SYNCED'
                          ? Icons.check_circle_outline
                          : Icons.sync_problem,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      record['status'] == 'SYNCED'
                          ? 'Operación sincronizada'
                          : record['status'] == 'REVIEW'
                          ? 'Requiere revisión'
                          : 'Pendiente de sincronización',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      (record['payload'] as Map)['kind'] == 'HTTP_COMMAND'
                          ? '${record['payload']['method']} ${record['payload']['path']}'
                          : 'Registro de venta',
                    ),
                    Text('${record['createdAt']}'),
                    SelectableText(
                      '${record['id']}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (record['error'] != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('${record['error']}'),
                      ),
                    if (record['status'] != 'SYNCED')
                      FilledButton.icon(
                        onPressed: _busy ? null : () => _retry(record),
                        icon: const Icon(Icons.sync),
                        label: const Text('Reintentar operación'),
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
