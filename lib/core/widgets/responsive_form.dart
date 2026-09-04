import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../navigation/app_nav.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

class ResponsiveForm {
  ResponsiveForm._();

  static const double desktopBreakpoint = 1024;

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget Function(bool dialogMode) builder,
  }) {
    if (MediaQuery.sizeOf(context).width >= desktopBreakpoint) {
      return showDialog<T>(
        context: context,
        useRootNavigator: true,
        builder: (_) => builder(true),
      );
    }
    return AppNav.push<T>(context, builder(false));
  }

  static Future<T?> showPage<T>({
    required BuildContext context,
    required Widget page,
    double dialogWidth = 720,
    double dialogHeight = 720,
    Key? dialogKey,
  }) {
    if (MediaQuery.sizeOf(context).width < desktopBreakpoint) {
      return AppNav.push<T>(context, page);
    }

    return showDialog<T>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) {
        final viewport = MediaQuery.sizeOf(dialogContext);
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: SizedBox(
            key: dialogKey,
            width: math.min(dialogWidth, viewport.width - 48),
            height: math.min(dialogHeight, viewport.height - 48),
            child: page,
          ),
        );
      },
    );
  }
}

class ResponsiveFormScaffold extends StatelessWidget {
  final bool dialogMode;
  final String title;
  final String? subtitle;
  final Widget body;
  final double dialogWidth;
  final double dialogHeight;
  final Key? dialogKey;

  const ResponsiveFormScaffold({
    super.key,
    required this.dialogMode,
    required this.title,
    this.subtitle,
    required this.body,
    this.dialogWidth = 560,
    this.dialogHeight = 560,
    this.dialogKey,
  });

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: context.colors.surface,
      appBar: dialogMode
          ? AppBar(
              automaticallyImplyLeading: false,
              title: _DialogTitle(title: title, subtitle: subtitle),
              actions: [
                IconButton(
                  key: const ValueKey('responsive-form-close'),
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
                const SizedBox(width: 8),
              ],
            )
          : SubPageAppBar(title: title, subtitle: subtitle),
      body: body,
    );

    if (!dialogMode) return scaffold;

    final viewport = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: SizedBox(
        key: dialogKey,
        width: math.min(dialogWidth, viewport.width - 48),
        height: math.min(dialogHeight, viewport.height - 48),
        child: scaffold,
      ),
    );
  }
}

class _DialogTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _DialogTitle({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      if (subtitle != null)
        Text(
          subtitle!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: context.colors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
    ],
  );
}
