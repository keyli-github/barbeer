import 'package:flutter/material.dart';
import '../../../../core/widgets/app_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../ventas/data/models/venta_models.dart';
import '../../../ventas/presentation/providers/ventas_provider.dart';
import '../widgets/etiqueta_form_sheet.dart';
import '../widgets/etiqueta_tile.dart';

/// Pantalla administrativa de billeteras digitales (Yape, Plin, Agora, etc.).
/// Solo accesible para ADMIN y SUPERADMIN.
class EtiquetasScreen extends ConsumerStatefulWidget {
  const EtiquetasScreen({super.key});
  @override
  ConsumerState<EtiquetasScreen> createState() => _EtiquetasScreenState();
}

class _EtiquetasScreenState extends ConsumerState<EtiquetasScreen> {
  List<Etiqueta> _etiquetas = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(ventasRepositoryProvider);
      final result = await repo.listEtiquetas();
      if (!mounted) return;
      setState(() {
        _etiquetas = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendlyError(e);
      });
    }
  }

  void _openCreate() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EtiquetaFormSheet(onDone: _load),
    );
  }

  void _openEdit(Etiqueta etiqueta) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EtiquetaFormSheet(etiqueta: etiqueta, onDone: _load),
    );
  }

  Future<void> _toggleEstado(Etiqueta etiqueta) async {
    final nuevoEstado = !etiqueta.activo;
    // Confirmar desactivación
    if (!nuevoEstado) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Desactivar billetera'),
          content: Text(
            '¿Desactivar "${etiqueta.nombre}"?\n\n'
            'No se podrá usar para clasificar nuevos pagos hasta que se reactive.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Desactivar'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    try {
      final repo = ref.read(ventasRepositoryProvider);
      await repo.toggleEtiqueta(etiqueta.id, activo: nuevoEstado);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nuevoEstado
                ? '"${etiqueta.nombre}" activada'
                : '"${etiqueta.nombre}" desactivada',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(e)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('403')) return 'No tienes permiso para gestionar billeteras';
    if (s.contains('conciliaciones') || s.contains('pendiente')) {
      return 'La billetera tiene pagos pendientes de confirmar';
    }
    if (s.contains('SocketException') || s.contains('connection')) {
      return 'Sin conexión al servidor';
    }
    return 'No se pudo completar la operación';
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final canManage = auth.user?.hasPermission('etiquetas:crear') ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (canManage)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: _openCreate,
                    icon: const Icon(Icons.add_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
            // Info banner
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primaryBorder),
                ),
                child: Text(
                  'Solo billeteras digitales autorizadas. '
                  'No deben representar tarjetas, retiros ni depósitos.',
                  style: TextStyle(fontSize: 11, color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Content
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: AppColors.error,
                            size: 40,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _error!,
                            style: TextStyle(color: AppColors.error),
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    )
                  : _etiquetas.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 48,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No hay billeteras configuradas',
                            style: TextStyle(color: AppColors.textTertiary),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        itemCount: _etiquetas.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final et = _etiquetas[i];
                          return EtiquetaTile(
                            etiqueta: et,
                            canEdit: canManage,
                            onEdit: () => _openEdit(et),
                            onToggle: () => _toggleEstado(et),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
