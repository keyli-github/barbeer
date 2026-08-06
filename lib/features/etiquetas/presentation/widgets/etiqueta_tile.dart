import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../ventas/data/models/venta_models.dart';

/// Tarjeta que muestra una etiqueta (billetera digital) en la lista.
class EtiquetaTile extends StatelessWidget {
  final Etiqueta etiqueta;
  final bool canEdit;
  final VoidCallback? onEdit;
  final VoidCallback? onToggle;

  const EtiquetaTile({
    super.key,
    required this.etiqueta,
    this.canEdit = false,
    this.onEdit,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: etiqueta.activo ? 1.0 : 0.55,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: etiqueta.activo
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : AppColors.backgroundAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                color: etiqueta.activo
                    ? AppColors.primary
                    : AppColors.textTertiary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          etiqueta.nombre,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!etiqueta.activo) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundAlt,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Text(
                            'INACTIVA',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Orden: ${etiqueta.orden}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        etiqueta.requiereComprobante
                            ? Icons.check_circle_rounded
                            : Icons.remove_circle_outline_rounded,
                        size: 12,
                        color: etiqueta.requiereComprobante
                            ? AppColors.success
                            : AppColors.textTertiary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        etiqueta.requiereComprobante
                            ? 'Comprobante'
                            : 'Sin comprobante',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      if (etiqueta.sedeId != null) ...[
                        const SizedBox(width: 12),
                        Icon(
                          Icons.store_rounded,
                          size: 12,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Sede',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Actions
            if (canEdit) ...[
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded, size: 18),
                color: AppColors.textSecondary,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              IconButton(
                onPressed: onToggle,
                icon: Icon(
                  etiqueta.activo
                      ? Icons.toggle_on_rounded
                      : Icons.toggle_off_rounded,
                  size: 28,
                ),
                color: etiqueta.activo
                    ? AppColors.success
                    : AppColors.textTertiary,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
