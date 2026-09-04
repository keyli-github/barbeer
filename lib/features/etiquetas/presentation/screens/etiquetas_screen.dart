import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/responsive_form.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/etiqueta.dart';
import '../providers/etiquetas_provider.dart';
import '../widgets/etiqueta_form_sheet.dart';
import '../widgets/etiqueta_tile.dart';

class EtiquetasScreen extends ConsumerStatefulWidget {
  const EtiquetasScreen({super.key});
  @override
  ConsumerState<EtiquetasScreen> createState() => _EtiquetasScreenState();
}

class _EtiquetasScreenState extends ConsumerState<EtiquetasScreen> {
  List<Etiqueta> _etiquetas = [];
  bool _loading = true;
  String? _error;
  bool _showInfo = true;
  Timer? _infoTimer;

  @override
  void initState() {
    super.initState();
    _load();
    // El aviso de solo lectura se muestra brevemente y se oculta solo.
    _infoTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showInfo = false);
    });
  }

  @override
  void dispose() {
    _infoTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(etiquetasRepositoryProvider);
      final result = await repo.list();
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
    ResponsiveForm.showPage<void>(
      context: context,
      dialogWidth: 560,
      dialogHeight: 560,
      page: EtiquetaFormSheet(onDone: _load),
    );
  }

  void _openEdit(Etiqueta etiqueta) {
    if (etiqueta.esSistema) return;
    ResponsiveForm.showPage<void>(
      context: context,
      dialogWidth: 560,
      dialogHeight: 560,
      page: EtiquetaFormSheet(etiqueta: etiqueta, onDone: _load),
    );
  }

  Future<void> _toggleEstado(Etiqueta etiqueta) async {
    if (etiqueta.esSistema) return;
    final nuevoEstado = !etiqueta.activo;
    // Confirmar desactivación
    if (!nuevoEstado) {
      final confirm = await showDialog<bool>(
        context: context,
        useRootNavigator: true,
        builder: (ctx) => AlertDialog(
          title: const Text('Desactivar etiqueta'),
          content: Text(
            '¿Desactivar "${etiqueta.nombre}"?\n\n'
            'No se podrá usar en nuevas operaciones hasta que se reactive.',
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
      final repo = ref.read(etiquetasRepositoryProvider);
      await repo.updateActivo(etiqueta.id, activo: nuevoEstado);
      if (!mounted) return;
      AppFeedback.success(
        context,
        nuevoEstado
            ? '"${etiqueta.nombre}" activada'
            : '"${etiqueta.nombre}" desactivada',
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, _friendlyError(e));
    }
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('403')) return 'No tienes permiso para gestionar etiquetas';
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
    final canCreate = auth.hasPermission('etiquetas:crear');
    final canEdit = auth.hasPermission('etiquetas:editar');
    final canDeactivate = auth.hasPermission('etiquetas:desactivar');

    return Scaffold(
      backgroundColor: context.colors.background,
      floatingActionButton: canCreate
          ? FloatingActionButton(
              heroTag: 'etiquetas_fab',
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              onPressed: _openCreate,
              child: const Icon(Icons.add_rounded),
            )
          : null,
      body: Column(
        children: [
          // Info banner transitorio: se muestra al entrar y se oculta solo
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _showInfo
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.colors.primarySurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.colors.primaryBorder),
                      ),
                      child: Text(
                        'Clasifica métodos de pago, ingresos y salidas. '
                        'Las etiquetas del sistema son de solo lectura.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
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
                        Text(_error!, style: TextStyle(color: AppColors.error)),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Reintentar'),
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
                          color: context.colors.textTertiary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No hay etiquetas configuradas',
                          style: TextStyle(color: context.colors.textTertiary),
                        ),
                      ],
                    ),
                  )
                : LayoutBuilder(
                    builder: (_, constraints) {
                      Widget tile(int index) {
                        final etiqueta = _etiquetas[index];
                        return EtiquetaTile(
                          etiqueta: etiqueta,
                          canEdit: canEdit,
                          canDeactivate: canDeactivate,
                          onEdit: () => _openEdit(etiqueta),
                          onToggle: () => _toggleEstado(etiqueta),
                        );
                      }

                      final content = constraints.maxWidth >= 640
                          ? GridView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisExtent: 142,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                  ),
                              itemCount: _etiquetas.length,
                              itemBuilder: (_, index) => tile(index),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                              itemCount: _etiquetas.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (_, index) => tile(index),
                            );
                      return RefreshIndicator(onRefresh: _load, child: content);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
