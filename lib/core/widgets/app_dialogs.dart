import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_buttons.dart';

/// Modal de confirmación para acciones destructivas
class ConfirmationDialog {
  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Confirmar',
    String cancelText = 'Cancelar',
    bool isDestructive = false,
    IconData? icon,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
        ),
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isDestructive
                        ? context.colors.errorLight
                        : context.colors.primarySurface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: isDestructive ? AppColors.error : AppColors.primary,
                  ),
                ),
                SizedBox(height: AppSpacing.lg),
              ],
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppSpacing.sm),
              Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  color: context.colors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      text: cancelText,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: isDestructive
                        ? DestructiveButton(
                            text: confirmText,
                            onPressed: () => Navigator.of(context).pop(true),
                          )
                        : PrimaryButton(
                            text: confirmText,
                            onPressed: () => Navigator.of(context).pop(true),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return result ?? false;
  }
}

/// Mensaje de éxito animado
class SuccessMessage {
  static Future<void> show({
    required BuildContext context,
    required String message,
    IconData icon = Icons.check_circle_rounded,
    Duration duration = const Duration(seconds: 2),
  }) async {
    await showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (context) => _AnimatedMessageDialog(
        message: message,
        icon: icon,
        color: AppColors.success,
        backgroundColor: context.colors.successLight,
        duration: duration,
      ),
    );
  }
}

/// Mensaje de error animado
class ErrorMessage {
  static Future<void> show({
    required BuildContext context,
    required String message,
    IconData icon = Icons.error_rounded,
    Duration duration = const Duration(seconds: 2),
  }) async {
    await showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (context) => _AnimatedMessageDialog(
        message: message,
        icon: icon,
        color: AppColors.error,
        backgroundColor: context.colors.errorLight,
        duration: duration,
      ),
    );
  }
}

/// Widget interno para mensajes animados
class _AnimatedMessageDialog extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final Duration duration;

  const _AnimatedMessageDialog({
    required this.message,
    required this.icon,
    required this.color,
    required this.backgroundColor,
    required this.duration,
  });

  @override
  State<_AnimatedMessageDialog> createState() => _AnimatedMessageDialogState();
}

class _AnimatedMessageDialogState extends State<_AnimatedMessageDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _opacityAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _controller.forward();

    Future.delayed(widget.duration, () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
              boxShadow: AppShadows.sheet,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: widget.backgroundColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.icon, size: 40, color: widget.color),
                ),
                SizedBox(height: AppSpacing.lg),
                Text(
                  widget.message,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet personalizado
class AppBottomSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    bool isDismissible = true,
    bool enableDrag = true,
    double? heightFactor,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * (heightFactor ?? 0.9),
        ),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusXL),
          ),
          boxShadow: AppShadows.sheet,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Indicador visual de drag
            if (enableDrag)
              Padding(
                padding: EdgeInsets.only(top: AppSpacing.sm),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            // Título si existe
            if (title != null)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: context.colors.textSecondary,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            // Divisor
            if (title != null)
              Divider(height: 1, color: context.colors.divider),
            // Contenido
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}
