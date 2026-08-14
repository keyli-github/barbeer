import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Tile de lista estilo iOS — usado en ventas, usuarios, productos, etc.
class DSListTile extends StatelessWidget {
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showDivider;
  final EdgeInsetsGeometry? padding;

  const DSListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.showDivider = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
      child: Padding(
        padding:
            padding ??
            const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    subtitle!,
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Badge de estado compacto (ACTIVA, PENDIENTE, ANULADA, etc.)
class DSStatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool dot;

  const DSStatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.dot = false,
  });

  // Constructores predefinidos
  factory DSStatusBadge.active() =>
      const DSStatusBadge(label: 'ACTIVA', color: AppColors.success);
  factory DSStatusBadge.pending() =>
      const DSStatusBadge(label: 'PENDIENTE', color: AppColors.warning);
  factory DSStatusBadge.cancelled() =>
      const DSStatusBadge(label: 'ANULADA', color: AppColors.error);
  factory DSStatusBadge.inactive(BuildContext context) =>
      DSStatusBadge(label: 'INACTIVO', color: context.colors.textTertiary);

  factory DSStatusBadge.fromString(BuildContext context, String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVA':
        return DSStatusBadge.active();
      case 'PENDIENTE':
        return DSStatusBadge.pending();
      case 'ANULADA':
        return DSStatusBadge.cancelled();
      case 'INACTIVO':
        return DSStatusBadge.inactive(context);
      default:
        return DSStatusBadge(label: status, color: context.colors.textTertiary);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusRound),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.75),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge de rol (SUPERADMIN, ADMIN, CAJERO, VENDEDORA)
class DSRoleBadge extends StatelessWidget {
  final String role;

  const DSRoleBadge({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.roleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Separador de sección con título (como "VENTAS Y CAJA")
class DSSectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const DSSectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colors.textSecondary,
                letterSpacing: 0.3,
              ),
            ),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                action!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
