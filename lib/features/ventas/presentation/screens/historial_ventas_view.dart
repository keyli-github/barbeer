import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/navigation/app_nav.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/ds_states.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/venta_models.dart';
import '../providers/ventas_provider.dart';
import '../widgets/anular_venta_dialog.dart';
import 'conciliar_venta_screen.dart';

class HistorialVentasView extends ConsumerStatefulWidget {
  final VoidCallback? onCreate;

  const HistorialVentasView({super.key, this.onCreate});

  @override
  ConsumerState<HistorialVentasView> createState() => _HistorialState();
}

class _HistorialState extends ConsumerState<HistorialVentasView> {
  bool get _useMis => !canReadAllVentas(ref.read(authProvider));

  Future<void> _refresh() =>
      ref.read(ventasListProvider(_useMis).notifier).refresh();

  void _openConciliar(Venta venta) => AppNav.push(
    context,
    ConciliarVentaScreen(venta: venta, onDone: _refresh),
  );

  Future<void> _anular(Venta venta) async {
    final motivo = await showAnularVentaDialog(context, codigo: venta.codigo);
    if (motivo == null || !mounted) return;
    try {
      await ref
          .read(ventasRepositoryProvider)
          .anularVenta(venta.id, motivo: motivo);
      if (!mounted) return;
      AppFeedback.success(context, 'Venta anulada');
      await _refresh();
    } catch (error) {
      if (mounted) AppFeedback.error(context, 'No se pudo anular la venta');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final state = ref.watch(ventasListProvider(_useMis));

    return Column(
      children: [
        _FiltersBar(
          currentFilter: state.filterEstado,
          total: state.total,
          loading: state.loading,
          onCreate: widget.onCreate,
          onRefresh: _refresh,
          onFilter: (estado) => ref
              .read(ventasListProvider(_useMis).notifier)
              .load(estado: estado),
        ),
        Expanded(
          child: state.loading && state.ventas.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: DSSkeletonList(count: 6),
                )
              : state.error != null && state.ventas.isEmpty
              ? DSErrorState(message: state.error, onRetry: _refresh)
              : state.ventas.isEmpty
              ? DSEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Sin ventas',
                  message: 'No hay ventas registradas para este estado.',
                  actionLabel: 'Actualizar',
                  onAction: _refresh,
                )
              : RefreshIndicator(
                  color: AppColors.brand,
                  onRefresh: _refresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(15, 4, 15, 120),
                    itemCount:
                        state.ventas.length +
                        (state.totalPaginas > state.pagina ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == state.ventas.length) {
                        return _LoadMoreButton(
                          loading: state.loading,
                          onTap: state.loading
                              ? null
                              : () => ref
                                    .read(ventasListProvider(_useMis).notifier)
                                    .loadMore(),
                        );
                      }
                      final venta = state.ventas[index];
                      final classified =
                          venta.conciliacion != null && !venta.isPendiente;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _VentaCard(
                          venta: venta,
                          onConciliar: canConciliar(auth) && venta.isPendiente
                              ? () => _openConciliar(venta)
                              : canConciliarCorregir(auth) && classified
                              ? () => _openConciliar(venta)
                              : null,
                          correction: classified,
                          onAnular: canAnularVenta(auth) && !venta.isAnulada
                              ? () => _anular(venta)
                              : null,
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _FiltersBar extends StatelessWidget {
  final String? currentFilter;
  final int total;
  final bool loading;
  final VoidCallback? onCreate;
  final Future<void> Function() onRefresh;
  final ValueChanged<String?> onFilter;

  const _FiltersBar({
    required this.currentFilter,
    required this.total,
    required this.loading,
    required this.onRefresh,
    required this.onFilter,
    this.onCreate,
  });

  @override
  Widget build(BuildContext context) => Container(
    color: context.colors.background,
    padding: const EdgeInsets.fromLTRB(15, 10, 15, 12),
    child: Column(
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey(currentFilter ?? 'TODAS'),
          initialValue: currentFilter ?? 'TODAS',
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          items: const [
            DropdownMenuItem(value: 'TODAS', child: Text('Todos los estados')),
            DropdownMenuItem(value: 'ACTIVA', child: Text('Activas')),
            DropdownMenuItem(value: 'ANULADA', child: Text('Anuladas')),
          ],
          onChanged: loading
              ? null
              : (value) => onFilter(value == 'TODAS' ? null : value),
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            SizedBox(
              width: 44,
              height: 40,
              child: OutlinedButton(
                onPressed: loading ? null : onRefresh,
                style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                child: AnimatedRotation(
                  turns: loading ? 1 : 0,
                  duration: const Duration(milliseconds: 350),
                  child: const Icon(Icons.refresh_rounded, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                '$total venta${total == 1 ? '' : 's'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: context.colors.textTertiary,
                ),
              ),
            ),
            const Spacer(),
            if (onCreate != null)
              SizedBox(
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.shopping_cart_outlined, size: 17),
                  label: const Text(
                    'Nueva venta',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

class _VentaCard extends StatefulWidget {
  final Venta venta;
  final VoidCallback? onConciliar;
  final VoidCallback? onAnular;
  final bool correction;

  const _VentaCard({
    required this.venta,
    required this.correction,
    this.onConciliar,
    this.onAnular,
  });

  @override
  State<_VentaCard> createState() => _VentaCardState();
}

class _VentaCardState extends State<_VentaCard> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final venta = widget.venta;
    final date = DateTime.tryParse(venta.createdAt)?.toLocal();

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: venta.isAnulada ? 0.7 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: code + total + anular + chevron  (exact web layout)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          venta.codigo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: context.colors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        FormatUtils.currency(venta.total),
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      if (widget.onAnular != null) ...[
                        const SizedBox(width: 6),
                        _SquareAction(
                          icon: Icons.cancel_outlined,
                          color: AppColors.error,
                          onTap: widget.onAnular!,
                        ),
                      ],
                      const SizedBox(width: 4),
                      _SquareAction(
                        icon: expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: context.colors.textTertiary,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => expanded = !expanded);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  // Row 2: username + date (muted)
                  Row(
                    children: [
                      if (venta.vendedoraUsername != null) ...[
                        Flexible(
                          child: Text(
                            venta.vendedoraUsername!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.colors.textTertiary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                      ],
                      if (date != null)
                        Flexible(
                          child: Text(
                            DateFormat('dd/MM/yy, h:mm a').format(date),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.colors.textTertiary,
                            ),
                          ),
                        ),
                      // Conciliar/corregir action (inline, subtle)
                      if (widget.onConciliar != null) ...[
                        const Spacer(),
                        _ActionButton(
                          label: widget.correction ? 'Corregir' : 'Clasificar',
                          icon: Icons.account_balance_wallet_outlined,
                          color: widget.correction
                              ? context.colors.textSecondary
                              : AppColors.warning,
                          onTap: widget.onConciliar!,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              child: expanded ? _ExpandedSale(venta: venta) : const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }

}

class _ExpandedSale extends StatelessWidget {
  final Venta venta;

  const _ExpandedSale({required this.venta});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: context.colors.border)),
    ),
    child: Column(
      children: [
        for (final item in venta.items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.productoNombre ?? item.productoId,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ),
                Flexible(
                  child: Text(
                    '${item.cantidad} × ${FormatUtils.currency(item.precioUnitario)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      FormatUtils.currency(item.subtotal),
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (venta.conciliacion?.etiquetaNombre != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Billetera: ${venta.conciliacion!.etiquetaNombre}',
                style: const TextStyle(fontSize: 11, color: AppColors.info),
              ),
            ),
          ),
        if (venta.motivoAnulacion != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Anulación: ${venta.motivoAnulacion}',
                style: const TextStyle(fontSize: 11, color: AppColors.error),
              ),
            ),
          ),
      ],
    ),
  );
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );
}

class _SquareAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SquareAction({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Icon(icon, size: 17, color: color),
    ),
  );
}

class _LoadMoreButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool loading;

  const _LoadMoreButton({required this.onTap, required this.loading});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: TextButton(
        onPressed: onTap,
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Cargar más'),
      ),
    ),
  );
}
