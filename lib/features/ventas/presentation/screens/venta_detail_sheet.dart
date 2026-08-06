import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/widgets/ds_card.dart';
import '../../../../core/widgets/ds_list_tile.dart';
import '../../../../core/widgets/ds_product_image.dart';
import '../../../../core/widgets/ds_states.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/venta_models.dart';
import '../providers/ventas_provider.dart';

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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Anular venta'),
        content: Text('¿Anular la venta ${widget.venta.codigo}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Anular'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() {
      _anulando = true;
      _errorAnular = null;
    });
    try {
      await ref
          .read(ventasRepositoryProvider)
          .anularVenta(widget.venta.id, motivo: 'Anulada manualmente');
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
    final venta = widget.venta;

    DateTime? dt;
    try {
      dt = DateTime.parse(venta.createdAt);
    } catch (_) {}

    final statusColor = venta.isAnulada
        ? AppColors.error
        : venta.isPendiente
        ? AppColors.warning
        : AppColors.success;
    final statusLabel = venta.isAnulada
        ? 'ANULADA'
        : venta.isPendiente
        ? 'PENDIENTE'
        : 'ACTIVA';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          _SheetHandle(),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Detalle de venta',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Información completa',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                DSStatusBadge(label: statusLabel, color: statusColor),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),

          // Contenido scrollable
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Resumen ──────────────────────────────────────────
                  DSCard(
                    child: Column(
                      children: [
                        _InfoRow('Código', venta.codigo, monospace: true),
                        const Divider(height: 16),
                        _InfoRow('Sede', venta.sedeId),
                        if (venta.vendedoraUsername != null) ...[
                          const Divider(height: 16),
                          _InfoRow('Vendedora', venta.vendedoraUsername!),
                        ],
                        const Divider(height: 16),
                        _InfoRow(
                          'Fecha',
                          dt != null ? FormatUtils.dateTime(dt) : '—',
                        ),
                        const Divider(height: 16),
                        _InfoRow(
                          'Total',
                          FormatUtils.currency(venta.total),
                          valueStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Conciliación ─────────────────────────────────────
                  if (venta.conciliacion != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    _SectionLabel('Clasificación de pago'),
                    DSCard(
                      child: Column(
                        children: [
                          _InfoRow(
                            'Estado',
                            estadoConciliacionLabel(venta.conciliacion!.estado),
                          ),
                          if (venta.conciliacion!.etiquetaNombre != null) ...[
                            const Divider(height: 16),
                            _InfoRow(
                              'Billetera',
                              venta.conciliacion!.etiquetaNombre!,
                            ),
                          ],
                          if (venta.conciliacion!.comprobante != null) ...[
                            const Divider(height: 16),
                            _InfoRow(
                              'Comprobante',
                              venta.conciliacion!.comprobante!,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  // ── Ítems ─────────────────────────────────────────────
                  const SizedBox(height: AppSpacing.md),
                  _SectionLabel('Detalle de ítems'),
                  DSCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: venta.items.asMap().entries.map((e) {
                        final i = e.key;
                        final item = e.value;
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.md),
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
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '${item.cantidad} × ${FormatUtils.currency(item.precioUnitario)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    FormatUtils.currency(item.subtotal),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (i < venta.items.length - 1)
                              const Divider(height: 1, indent: 72),
                          ],
                        );
                      }).toList(),
                    ),
                  ),

                  // ── Total ─────────────────────────────────────────────
                  const SizedBox(height: AppSpacing.xs),
                  DSCard(
                    backgroundColor: AppColors.primarySurface,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          FormatUtils.currency(venta.total),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Info técnica ─────────────────────────────────────
                  const SizedBox(height: AppSpacing.md),
                  _SectionLabel('Información técnica'),
                  DSCard(
                    child: Column(
                      children: [
                        _InfoRow('ID', venta.id, monospace: true),
                        const Divider(height: 16),
                        _InfoRow(
                          'Sesión de caja',
                          venta.cajaSesionId,
                          monospace: true,
                        ),
                      ],
                    ),
                  ),

                  // ── Error anular ──────────────────────────────────────
                  if (_errorAnular != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.errorLight,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMD,
                        ),
                      ),
                      child: Text(
                        _errorAnular!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],

                  // ── Botón anular ──────────────────────────────────────
                  if (canAnular) ...[
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _anulando ? null : _anular,
                        icon: _anulando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.cancel_outlined, size: 18),
                        label: Text(_anulando ? 'Anulando...' : 'Anular venta'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMD,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
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

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 0.2,
      ),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  final bool monospace;
  final TextStyle? valueStyle;
  const _InfoRow(
    this.label,
    this.value, {
    this.monospace = false,
    this.valueStyle,
  });
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
      const SizedBox(width: AppSpacing.sm),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.right,
          style:
              valueStyle ??
              TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontFamily: monospace ? 'monospace' : null,
              ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}
