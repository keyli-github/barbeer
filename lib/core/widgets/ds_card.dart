import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Tarjeta base estilo iPhone — fondo blanco, borde gris claro, radio 14
class DSCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final double? radius;
  final List<BoxShadow>? shadow;
  final Border? border;

  const DSCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.backgroundColor,
    this.radius,
    this.shadow,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        borderRadius: BorderRadius.circular(radius ?? AppSpacing.radiusLG),
        border: border ?? Border.all(color: AppColors.border, width: 0.75),
        boxShadow: shadow ?? AppShadows.card,
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: content,
      );
    }
    return content;
  }
}

/// Tarjeta de métrica compacta — KPI estilo iPhone
class DSStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? change;
  final bool positive;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback? onTap;

  const DSStatCard({
    super.key,
    required this.label,
    required this.value,
    this.change,
    this.positive = true,
    this.icon,
    this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DSCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if (change != null) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  positive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  size: 11,
                  color: positive ? AppColors.success : AppColors.error,
                ),
                const SizedBox(width: 2),
                Text(
                  change!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: positive ? AppColors.success : AppColors.error,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
