import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/widgets/ds_product_image.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/venta_models.dart';
import '../providers/ventas_provider.dart';
import '../widgets/anular_venta_dialog.dart';
import '../../../../core/widgets/ds_states.dart';

class VentaDetailSheet extends ConsumerStatefulWidget {
  final Venta venta;
  final VoidCallback? onChanged;

  const VentaDetailSheet({super.key, required this.venta, this.onChanged});

  @override
  ConsumerState<VentaDetailSheet> createState() => _VentaDetailSheetState();
}

class _VentaDetailSheetState extends ConsumerState<VentaDetailSheet> {
  bool _anulando = false;
  String? _errorAnular;

  Future<void> _anular() async {
    if (_anulando) return;
    final motivo = await showAnularVentaDialog(
      context,
      codigo: widget.venta.codigo,
    );
    if (motivo == null || !mounted) return;

    setState(() {
      _anulando = true;
      _errorAnular = null;
    });
    try {
      await ref
          .read(ventasRepositoryProvider)
          .anularVenta(widget.venta.id, motivo: motivo);
      if (mounted) {
        Navigator.pop(context);
        widget.onChanged?.call();
        DSSuccessOverlay.show(context, title: 'Venta anulada');
      }
    } catch (e) {
      setState(() {
        _anulando = false;
        _errorAnular = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final canAnular = canAnularVenta(auth) && !widget.venta.isAnulada;
    final v = widget.venta;

    DateTime? dt;
    try {
      dt = DateTime.parse(v.createdAt);
    } catch (_) {}

    final isAnulada = v.isAnulada;
    final isPendiente = v.isPendiente;
    final statusColor = isAnulada
        ? AppColors.error
        : isPendiente
        ? AppColors.warning
        : AppColors.success;
    final statusLabel = isAnulada
        ? 'ANULADA'
        : isPendiente
        ? 'PENDIENTE'
        : 'ACTIVA';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: context.colors.backgroundAlt,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ── Handle ─────────────────────────────────────────────────
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Cabecera ───────────────────────────────────────────────
          Container(
            color: context.colors.background,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        v.codigo,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: context.colors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dt != null ? FormatUtils.dateTime(dt) : '—',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Badge de estado grande
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: context.colors.border),

          // ── Contenido scrollable ───────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Total prominente ────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total de la venta',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          FormatUtils.currency(v.total),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // ── Info general ────────────────────────────────────
                  _SectionLabel('Información general'),
                  _InfoCard(
                    children: [
                      _InfoRow('Sede', v.sedeId),
                      if (v.vendedoraUsername != null) ...[
                        const _Divider(),
                        _InfoRow('Vendedora', v.vendedoraUsername!),
                      ],
                      const _Divider(),
                      _InfoRow(
                        'Sesión de caja',
                        v.cajaSesionId.length > 8
                            ? '...${v.cajaSesionId.substring(v.cajaSesionId.length - 8)}'
                            : v.cajaSesionId,
                        mono: true,
                      ),
                    ],
                  ),

                  if (v.recargoMonto != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    _SectionLabel('Recargo'),
                    _InfoCard(
                      children: [
                        _InfoRow(
                          'Monto',
                          FormatUtils.currency(v.recargoMonto!),
                        ),
                        if (v.recargoMotivo != null) ...[
                          const _Divider(),
                          _InfoRow('Motivo', v.recargoMotivo!),
                        ],
                      ],
                    ),
                  ],

                  const SizedBox(height: AppSpacing.md),

                  // ── Ítems de la venta ───────────────────────────────
                  _SectionLabel('Productos (${v.items.length})'),
                  _InfoCard(
                    padding: EdgeInsets.zero,
                    children: [
                      ...v.items.asMap().entries.map((e) {
                        final idx = e.key;
                        final item = e.value;
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  DSProductImageSquare(
                                    imageUrl: null,
                                    productName: item.productoNombre,
                                    size: 44,
                                    radius: 10,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.productoNombre ??
                                              item.productoCodigo ??
                                              '—',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: context.colors.textPrimary,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '${item.cantidad} × ${FormatUtils.currency(item.precioUnitario)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: context.colors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    FormatUtils.currency(item.subtotal),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: context.colors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (idx < v.items.length - 1)
                              Divider(
                                height: 1,
                                indent: 72,
                                color: context.colors.borderLight,
                              ),
                          ],
                        );
                      }),
                    ],
                  ),

                  // ── Clasificación de pago ───────────────────────────
                  if (v.conciliacion != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    _SectionLabel('Método de pago'),
                    _InfoCard(
                      children: [
                        _InfoRow(
                          'Estado',
                          estadoConciliacionLabel(v.conciliacion!.estado),
                        ),
                        if (v.conciliacion!.etiquetaNombre != null) ...[
                          const _Divider(),
                          _InfoRow(
                            'Billetera',
                            v.conciliacion!.etiquetaNombre!,
                          ),
                        ],
                        if (v.conciliacion!.codigoOperacion != null) ...[
                          const _Divider(),
                          _InfoRow(
                            'Código op.',
                            v.conciliacion!.codigoOperacion!,
                          ),
                        ],
                        if (v.conciliacion!.comprobante != null) ...[
                          const _Divider(),
                          _InfoRow('Comprobante', v.conciliacion!.comprobante!),
                        ],
                      ],
                    ),
                  ],

                  // ── Error y botón anular ────────────────────────────
                  if (_errorAnular != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: context.colors.errorLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 16,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorAnular!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (canAnular) ...[
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _anulando ? null : _anular,
                        icon: _anulando
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.error,
                                ),
                              )
                            : const Icon(Icons.block_rounded, size: 18),
                        label: Text(
                          _anulando ? 'Anulando...' : 'Anular esta venta',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Widgets auxiliares ───────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: context.colors.textTertiary,
        letterSpacing: 0.5,
        textBaseline: TextBaseline.alphabetic,
      ),
    ),
  );
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  const _InfoCard({required this.children, this.padding});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: context.colors.background,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: context.colors.border, width: 0.75),
    ),
    padding:
        padding ??
        const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  final bool mono;
  const _InfoRow(this.label, this.value, {this.mono = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, color: context.colors.textSecondary),
        ),
        const SizedBox(width: AppSpacing.md),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
              fontFamily: mono ? 'monospace' : null,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, color: context.colors.borderLight);
}
