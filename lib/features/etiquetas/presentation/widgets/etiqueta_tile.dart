import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/etiqueta.dart';

/// Tarjeta que muestra una etiqueta (billetera digital) en la lista.
class EtiquetaTile extends StatelessWidget {
  final Etiqueta etiqueta;
  final bool canEdit;
  final bool canDeactivate;
  final VoidCallback? onEdit;
  final VoidCallback? onToggle;

  const EtiquetaTile({
    super.key,
    required this.etiqueta,
    this.canEdit = false,
    this.canDeactivate = false,
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
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.borderLight),
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
                    : context.colors.backgroundAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                color: etiqueta.activo
                    ? AppColors.primary
                    : context.colors.textTertiary,
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
                            color: context.colors.backgroundAlt,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: context.colors.borderLight,
                            ),
                          ),
                          child: Text(
                            'INACTIVA',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: context.colors.textTertiary,
                            ),
                          ),
                        ),
                      ],
                      if (etiqueta.esSistema) ...[
                        const SizedBox(width: 6),
                        _Badge(label: 'SISTEMA', color: AppColors.info),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 10,
                    runSpacing: 5,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _Badge(
                        label: etiqueta.tipo.value,
                        color: switch (etiqueta.tipo) {
                          EtiquetaTipo.entrada => AppColors.success,
                          EtiquetaTipo.salida => AppColors.error,
                          EtiquetaTipo.ambos => AppColors.primary,
                        },
                      ),
                      _Meta(
                        icon: etiqueta.requiereComprobante
                            ? Icons.check_circle_rounded
                            : Icons.remove_circle_outline_rounded,
                        label: etiqueta.requiereComprobante
                            ? 'Comprobante'
                            : 'Sin comprobante',
                        color: etiqueta.requiereComprobante
                            ? AppColors.success
                            : context.colors.textTertiary,
                      ),
                      _Meta(
                        icon: etiqueta.sedeId == null
                            ? Icons.public_rounded
                            : Icons.store_rounded,
                        label: etiqueta.sedeId == null
                            ? 'Global'
                            : 'Sede específica',
                        color: etiqueta.sedeId == null
                            ? context.colors.textTertiary
                            : AppColors.warning,
                      ),
                      _Meta(
                        icon: Icons.sort_rounded,
                        label: 'Orden ${etiqueta.orden}',
                        color: context.colors.textTertiary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Actions
            if (canEdit && !etiqueta.esSistema)
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded, size: 18),
                color: context.colors.textSecondary,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            if (canDeactivate && !etiqueta.esSistema)
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
                    : context.colors.textTertiary,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(fontSize: 10, color: color)),
    ],
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: color),
    ),
  );
}
