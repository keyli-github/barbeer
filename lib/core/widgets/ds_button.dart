import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

enum DSButtonVariant { primary, secondary, outline, ghost, danger }

enum DSButtonSize { sm, md, lg }

/// Botón unificado BarBeer — todos los tamaños y variantes
class DSButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final DSButtonVariant variant;
  final DSButtonSize size;
  final IconData? icon;
  final bool iconTrailing;
  final bool loading;
  final bool fullWidth;

  const DSButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = DSButtonVariant.primary,
    this.size = DSButtonSize.md,
    this.icon,
    this.iconTrailing = false,
    this.loading = false,
    this.fullWidth = false,
  });

  // Conveniences
  const DSButton.primary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.iconTrailing = false,
    this.loading = false,
    this.fullWidth = false,
    this.size = DSButtonSize.md,
  }) : variant = DSButtonVariant.primary;

  const DSButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.iconTrailing = false,
    this.loading = false,
    this.fullWidth = false,
    this.size = DSButtonSize.md,
  }) : variant = DSButtonVariant.secondary;

  const DSButton.outline({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.iconTrailing = false,
    this.loading = false,
    this.fullWidth = false,
    this.size = DSButtonSize.md,
  }) : variant = DSButtonVariant.outline;

  const DSButton.danger({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.iconTrailing = false,
    this.loading = false,
    this.fullWidth = false,
    this.size = DSButtonSize.md,
  }) : variant = DSButtonVariant.danger;

  @override
  Widget build(BuildContext context) {
    final h = _height();
    final fs = _fontSize();
    final px = _padX();

    final bg = _bg();
    final fg = _fg();
    final border = _border();

    Widget content = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(fg),
            ),
          ),
          const SizedBox(width: 8),
        ] else if (icon != null && !iconTrailing) ...[
          Icon(icon, size: fs + 2, color: fg),
          const SizedBox(width: 6),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: fs,
            fontWeight: FontWeight.w600,
            color: fg,
            letterSpacing: -0.1,
          ),
        ),
        if (icon != null && iconTrailing && !loading) ...[
          const SizedBox(width: 6),
          Icon(icon, size: fs + 2, color: fg),
        ],
      ],
    );

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: h,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: (onPressed == null || loading)
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onPressed!();
                },
          borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(horizontal: px),
            decoration: BoxDecoration(
              color: (onPressed == null || loading)
                  ? bg.withValues(alpha: 0.5)
                  : bg,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
              border: border,
            ),
            alignment: Alignment.center,
            child: content,
          ),
        ),
      ),
    );
  }

  double _height() {
    switch (size) {
      case DSButtonSize.sm:
        return 36;
      case DSButtonSize.lg:
        return 52;
      default:
        return 44;
    }
  }

  double _fontSize() {
    switch (size) {
      case DSButtonSize.sm:
        return 13;
      case DSButtonSize.lg:
        return 16;
      default:
        return 15;
    }
  }

  double _padX() {
    switch (size) {
      case DSButtonSize.sm:
        return 14;
      case DSButtonSize.lg:
        return 24;
      default:
        return 20;
    }
  }

  Color _bg() {
    switch (variant) {
      case DSButtonVariant.primary:
        return AppColors.brand; // naranja
      case DSButtonVariant.secondary:
        return AppColors.brandSurface;
      case DSButtonVariant.danger:
        return AppColors.error;
      default:
        return Colors.transparent;
    }
  }

  Color _fg() {
    switch (variant) {
      case DSButtonVariant.primary:
        return Colors.white;
      case DSButtonVariant.secondary:
        return AppColors.brand;
      case DSButtonVariant.danger:
        return Colors.white;
      case DSButtonVariant.ghost:
        return AppColors.textSecondary;
      default:
        return AppColors.primary;
    }
  }

  Border? _border() {
    if (variant == DSButtonVariant.outline) {
      return Border.all(color: AppColors.border, width: 1.5);
    }
    return null;
  }
}

/// Botón de ícono circular compacto
class DSIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? backgroundColor;
  final double size;
  final String? tooltip;

  const DSIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.color,
    this.backgroundColor,
    this.size = 20,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final btn = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: size, color: color ?? AppColors.textSecondary),
    );

    return GestureDetector(
      onTap: onPressed != null
          ? () {
              HapticFeedback.lightImpact();
              onPressed!();
            }
          : null,
      child: tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn,
    );
  }
}
