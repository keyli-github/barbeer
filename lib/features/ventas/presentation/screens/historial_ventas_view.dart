import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/venta_models.dart';
import '../providers/ventas_provider.dart';
import '../widgets/venta_list_item.dart';
import 'conciliar_venta_sheet.dart';
import 'venta_detail_sheet.dart';

/// Vista del historial de ventas con conciliación y anulación.
class HistorialVentasView extends ConsumerStatefulWidget {
  const HistorialVentasView({super.key});
  @override
  ConsumerState<HistorialVentasView> createState() =>
      _HistorialVentasViewState();
}

class _HistorialVentasViewState extends ConsumerState<HistorialVentasView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final useMis = !canReadAllVentas(ref.read(authProvider));
      ref.read(ventasListProvider(useMis).notifier).load();
    });
  }

  bool get _useMisVentas => !canReadAllVentas(ref.read(authProvider));

  Future<void> _refresh() =>
      ref.read(ventasListProvider(_useMisVentas).notifier).refresh();

  void _openConciliar(Venta venta) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ConciliarVentaSheet(venta: venta, onDone: _refresh),
    );
  }

  void _openDetail(Venta venta) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VentaDetailSheet(venta: venta, onChanged: _refresh),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final state = ref.watch(ventasListProvider(_useMisVentas));
    final showConciliar = canConciliar(auth);
    final showCorregir = canConciliarCorregir(auth);
    final showAnular = canAnularVenta(auth);

    if (state.loading && state.ventas.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.ventas.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: AppColors.error, size: 40),
            const SizedBox(height: 8),
            Text(state.error!, style: TextStyle(color: AppColors.error)),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (state.ventas.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_rounded,
              size: 48,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              'No hay ventas registradas',
              style: TextStyle(color: AppColors.textTertiary),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Actualizar'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        itemCount: state.ventas.length,
        itemBuilder: (_, i) {
          final venta = state.ventas[i];
          return VentaListItem(
            venta: venta,
            onTap: () => _openDetail(venta),
            showConciliarButton: showConciliar,
            showCorregirButton: showCorregir,
            showAnularButton: showAnular,
            onConciliar: () => _openConciliar(venta),
            onAnular: () => _openAnular(venta),
          );
        },
      ),
    );
  }

  void _openAnular(Venta venta) {
    final motiveCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Anular venta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Venta ${venta.codigo}',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: motiveCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Motivo de anulación *',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (motiveCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              try {
                final repo = ref.read(ventasRepositoryProvider);
                await repo.anularVenta(
                  venta.id,
                  motivo: motiveCtrl.text.trim(),
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Venta anulada'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
                _refresh();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_friendlyError(e)),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Anular'),
          ),
        ],
      ),
    );
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('VENTA_EN_CAJA_CERRADA'))
      return 'La venta pertenece a una caja cerrada';
    if (s.contains('VENTA_YA_ANULADA')) return 'La venta ya fue anulada';
    if (s.contains('403')) return 'No tienes permiso para anular ventas';
    return 'No se pudo anular la venta';
  }
}
