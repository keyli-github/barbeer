import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../data/models/venta_models.dart';

String _fmtCurrency(double v) => FormatUtils.currency(v);

/// Widget que muestra una venta en la lista del historial.
class VentaListItem extends StatelessWidget {
  final Venta venta;
  final VoidCallback? onTap;
  final VoidCallback? onConciliar;
  final VoidCallback? onAnular;
  final bool showConciliarButton;
  final bool showCorregirButton;
  final bool showAnularButton;

  const VentaListItem({
    super.key,
    required this.venta,
    this.onTap,
    this.onConciliar,
    this.onAnular,
    this.showConciliarButton = false,
    this.showCorregirButton = false,
    this.showAnularButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final conc = venta.conciliacion;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: context.colors.borderLight),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: código + estado + total
              Row(
                children: [
                  Text(
                    venta.codigo,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 8),
                  _EstadoBadge(venta: venta),
                  const Spacer(),
                  Text(
                    _fmtCurrency(venta.total),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Info: vendedora + fecha
              Row(
                children: [
                  if (venta.vendedoraUsername != null)
                    Text(
                      venta.vendedoraUsername!,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  if (venta.vendedoraUsername != null)
                    const SizedBox(width: 12),
                  Text(
                    _formatDate(venta.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.textTertiary,
                    ),
                  ),
                ],
              ),
              // Actions
              if (!venta.isAnulada &&
                  (showConciliarButton ||
                      showCorregirButton ||
                      showAnularButton))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      if (showConciliarButton && venta.isPendiente)
                        _ActionChip(
                          label: 'Clasificar',
                          icon: Icons.account_balance_wallet_rounded,
                          color: AppColors.warning,
                          onTap: onConciliar,
                        ),
                      if (showCorregirButton &&
                          conc != null &&
                          conc.estado != EstadoConciliacion.pendiente)
                        _ActionChip(
                          label: 'Corregir',
                          icon: Icons.edit_rounded,
                          color: context.colors.textSecondary,
                          onTap: onConciliar,
                        ),
                      if (showAnularButton)
                        _ActionChip(
                          label: 'Anular',
                          icon: Icons.cancel_rounded,
                          color: AppColors.error,
                          onTap: onAnular,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

class _EstadoBadge extends StatelessWidget {
  final Venta venta;
  const _EstadoBadge({required this.venta});

  @override
  Widget build(BuildContext context) {
    if (venta.isAnulada) {
      return _badge('Anulada', AppColors.error);
    }
    final conc = venta.conciliacion;
    if (conc == null) return const SizedBox.shrink();
    switch (conc.estado) {
      case EstadoConciliacion.pendiente:
        return _badge('Pendiente', AppColors.warning);
      case EstadoConciliacion.efectivo:
        return _badge('Efectivo', AppColors.success);
      case EstadoConciliacion.billetera:
        return _badge(conc.etiquetaNombre ?? 'Billetera', AppColors.primary);
    }
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _ActionChip({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
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
      ),
    );
  }
}
