import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/ds_states.dart';
import '../../../../core/widgets/responsive_form.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/venta_models.dart';
import '../providers/ventas_provider.dart';
import '../widgets/anular_venta_dialog.dart';
import 'conciliar_venta_screen.dart';

class HistorialVentasView extends ConsumerStatefulWidget {
  final VoidCallback? onCreate;
  final VoidCallback? onRecargoControl;

  const HistorialVentasView({super.key, this.onCreate, this.onRecargoControl});

  @override
  ConsumerState<HistorialVentasView> createState() => _HistorialState();
}

class _HistorialState extends ConsumerState<HistorialVentasView> {
  bool get _useMis => !canReadAllVentas(ref.read(authProvider));

  Future<void> _refresh() =>
      ref.read(ventasListProvider(_useMis).notifier).refresh();

  void _openConciliar(Venta venta) => ResponsiveForm.showPage<void>(
    context: context,
    dialogWidth: 840,
    dialogHeight: 800,
    page: ConciliarVentaScreen(venta: venta, onDone: _refresh),
  );

  Future<void> _anular(Venta venta) async {
    final motivo = await showAnularVentaDialog(context, codigo: venta.codigo);
    if (motivo == null || !mounted) return;
    try {
      await ref
          .read(ventasRepositoryProvider)
          .anularVenta(venta.id, motivo: motivo);
      if (!mounted) return;
      invalidateSaleSideEffects(ref);
      AppFeedback.success(context, 'Venta anulada');
      await _refresh();
    } catch (error) {
      if (mounted) AppFeedback.error(context, saleMutationError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final state = ref.watch(ventasListProvider(_useMis));
    final desktop = MediaQuery.sizeOf(context).width >= 1024;

    return Column(
      children: [
        Expanded(
          child: state.loading && state.ventas.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: DSSkeletonList(count: 6),
                )
              : state.error != null && state.ventas.isEmpty
              ? _RefreshableHistoryState(
                  onRefresh: _refresh,
                  child: DSErrorState(message: state.error, onRetry: _refresh),
                )
              : state.ventas.isEmpty
              ? _RefreshableHistoryState(
                  onRefresh: _refresh,
                  child: const DSEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Sin ventas',
                    message: 'No hay ventas registradas para este estado.',
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.brand,
                  onRefresh: _refresh,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      desktop ? 20 : 15,
                      desktop ? 0 : 4,
                      desktop ? 20 : 15,
                      24,
                    ),
                    itemCount:
                        state.ventas.length +
                        1 +
                        (state.totalPaginas > state.pagina ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _FiltersBar(
                          currentFilter: state.filterEstado,
                          total: state.total,
                          loading: state.loading,
                          onCreate: widget.onCreate,
                          onRecargoControl: widget.onRecargoControl,
                          onFilter: (estado) => ref
                              .read(ventasListProvider(_useMis).notifier)
                              .load(estado: estado),
                        );
                      }
                      final saleIndex = index - 1;
                      if (saleIndex == state.ventas.length) {
                        return _LoadMoreButton(
                          loading: state.loading,
                          onTap: state.loading
                              ? null
                              : () => ref
                                    .read(ventasListProvider(_useMis).notifier)
                                    .loadMore(),
                        );
                      }
                      final venta = state.ventas[saleIndex];
                      final classified =
                          venta.conciliacion != null && !venta.isPendiente;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: VentaHistoryCard(
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

class _RefreshableHistoryState extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  const _RefreshableHistoryState({
    required this.child,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    color: AppColors.brand,
    onRefresh: onRefresh,
    child: LayoutBuilder(
      builder: (context, constraints) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [SizedBox(height: constraints.maxHeight, child: child)],
      ),
    ),
  );
}

class _FiltersBar extends StatelessWidget {
  final String? currentFilter;
  final int total;
  final bool loading;
  final VoidCallback? onCreate;
  final VoidCallback? onRecargoControl;
  final ValueChanged<String?> onFilter;

  const _FiltersBar({
    required this.currentFilter,
    required this.total,
    required this.loading,
    required this.onFilter,
    this.onCreate,
    this.onRecargoControl,
  });

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 1024;
    return Container(
      key: const Key('ventas-filters'),
      color: context.colors.background,
      padding: EdgeInsets.fromLTRB(0, desktop ? 0 : 10, 0, 12),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            key: ValueKey(currentFilter ?? 'TODAS'),
            initialValue: currentFilter ?? 'TODAS',
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
            items: const [
              DropdownMenuItem(
                value: 'TODAS',
                child: Text('Todos los estados'),
              ),
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
              if (onRecargoControl != null) ...[
                IconButton(
                  key: const Key('recargo-control-open'),
                  onPressed: onRecargoControl,
                  icon: const Icon(Icons.visibility_outlined),
                ),
                const SizedBox(width: 4),
              ],
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
                  height: desktop ? 36 : 40,
                  child: ElevatedButton.icon(
                    onPressed: onCreate,
                    icon: const Icon(Icons.shopping_cart_outlined, size: 17),
                    label: const Text(
                      'Nueva venta',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class VentaHistoryCard extends StatefulWidget {
  final Venta venta;
  final VoidCallback? onConciliar;
  final VoidCallback? onAnular;
  final bool correction;

  const VentaHistoryCard({
    super.key,
    required this.venta,
    required this.correction,
    this.onConciliar,
    this.onAnular,
  });

  @override
  State<VentaHistoryCard> createState() => _VentaCardState();
}

class _VentaCardState extends State<VentaHistoryCard> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final venta = widget.venta;
    final date = DateTime.tryParse(venta.createdAt)?.toLocal();
    final desktop = MediaQuery.sizeOf(context).width >= 1024;

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
              padding: EdgeInsets.symmetric(
                horizontal: desktop ? 16 : 14,
                vertical: 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: code + payment state + total + actions.
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
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
                            if (desktop) ...[
                              const SizedBox(width: 8),
                              _PaymentBadge(venta: venta),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        venta.hasAuthoritativeTotal
                            ? FormatUtils.currency(venta.total)
                            : 'No disponible',
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
                        active: expanded,
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
                          label: widget.correction ? 'Corregir' : 'Pendiente',
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

class _PaymentBadge extends StatelessWidget {
  final Venta venta;

  const _PaymentBadge({required this.venta});

  @override
  Widget build(BuildContext context) {
    final payment = venta.conciliacion;
    final (label, color) = venta.isAnulada
        ? ('Anulada', AppColors.error)
        : payment == null
        ? ('Sin clasificar', context.colors.textTertiary)
        : payment.estado == EstadoConciliacion.efectivo
        ? ('Efectivo', AppColors.success)
        : payment.estado == EstadoConciliacion.billetera
        ? (payment.etiquetaNombre ?? 'Billetera', AppColors.success)
        : ('Pendiente', AppColors.warning);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Text(
        '✓  $label',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _ExpandedSale extends StatelessWidget {
  final Venta venta;

  const _ExpandedSale({required this.venta});

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 1024;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        desktop ? 16 : 14,
        12,
        desktop ? 16 : 14,
        14,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.colors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (desktop) ...[
            const _DesktopSaleRow(
              header: true,
              product: 'Producto',
              quantity: 'Cant.',
              unitPrice: 'P.Unit',
              subtotal: 'Subtotal',
            ),
            Divider(height: 1, color: context.colors.borderLight),
          ],
          for (final item in venta.items)
            desktop
                ? _DesktopSaleRow(
                    product: item.productoNombre ?? item.productoId,
                    quantity: '${item.cantidad}',
                    unitPrice: FormatUtils.currency(item.precioUnitario),
                    subtotal: FormatUtils.currency(item.subtotal),
                  )
                : _MobileSaleRow(item: item),
          if (desktop) ...[
            Divider(height: 1, color: context.colors.borderLight),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SaleMetadata(
                    label: 'REGISTRADO POR',
                    value: venta.registradaPorUsername ?? 'No disponible',
                  ),
                ),
                Expanded(
                  child: _SaleMetadata(
                    label: 'VENDIDO POR (VENDEDORA)',
                    value: venta.vendedoraUsername ?? 'No disponible',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: context.colors.borderLight),
            const SizedBox(height: 12),
            Text(
              'MÉTODOS DE PAGO Y COMPROBANTES',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: .8,
                color: context.colors.textTertiary,
              ),
            ),
          ] else if (venta.registradaPorUsername != null)
            _PaymentLine('Registrado por: ${venta.registradaPorUsername}'),
          for (final payment
              in venta.conciliaciones.isNotEmpty
                  ? venta.conciliaciones
                  : [if (venta.conciliacion != null) venta.conciliacion!]) ...[
            _PaymentLine(
              payment.estado == EstadoConciliacion.pendiente
                  ? payment.metodoPagoPendiente == 'BILLETERA'
                        ? 'Pendiente · Transferencia'
                        : 'Pendiente · Efectivo'
                  : estadoConciliacionLabel(payment.estado),
            ),
            if (payment.monto != null)
              _PaymentLine('Monto: ${FormatUtils.currency(payment.monto!)}'),
            if (payment.comprobante != null)
              _PaymentLine('Comprobante: ${payment.comprobante}'),
            if (payment.pagoRestoEfectivo)
              const _PaymentLine('Resto en efectivo'),
          ],
          if (venta.cuentaNombre != null && venta.cuentaMonto != null)
            _PaymentLine(
              'Cuenta: ${venta.cuentaNombre} · ${FormatUtils.currency(venta.cuentaMonto!)}',
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
}

class _DesktopSaleRow extends StatelessWidget {
  final bool header;
  final String product;
  final String quantity;
  final String unitPrice;
  final String subtotal;

  const _DesktopSaleRow({
    this.header = false,
    required this.product,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: header ? 10 : 11,
      fontWeight: header ? FontWeight.w600 : FontWeight.w500,
      color: header ? context.colors.textTertiary : context.colors.textPrimary,
    );
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(product, style: style)),
          Expanded(child: Text(quantity, style: style)),
          Expanded(child: Text(unitPrice, style: style)),
          Expanded(
            child: Text(
              subtotal,
              style: style.copyWith(
                fontWeight: header ? FontWeight.w600 : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileSaleRow extends StatelessWidget {
  final VentaItem item;

  const _MobileSaleRow({required this.item});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            item.productoNombre ?? item.productoId,
            style: TextStyle(fontSize: 12, color: context.colors.textPrimary),
          ),
        ),
        Flexible(
          child: Text(
            '${item.cantidad} × ${FormatUtils.currency(item.precioUnitario)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: context.colors.textTertiary),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          FormatUtils.currency(item.subtotal),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
      ],
    ),
  );
}

class _SaleMetadata extends StatelessWidget {
  final String label;
  final String value;

  const _SaleMetadata({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 10,
          letterSpacing: .7,
          color: context.colors.textTertiary,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        value,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: context.colors.textPrimary,
        ),
      ),
    ],
  );
}

class _PaymentLine extends StatelessWidget {
  final String text;
  const _PaymentLine(this.text);

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: context.colors.textSecondary),
      ),
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
  final bool active;

  const _SquareAction({
    required this.icon,
    required this.color,
    required this.onTap,
    this.active = false,
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
        border: Border.all(
          color: active ? AppColors.primary : color.withValues(alpha: 0.35),
        ),
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
