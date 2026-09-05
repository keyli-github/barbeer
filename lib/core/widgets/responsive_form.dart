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
      builder: (_) => _AdaptivePageDialog(
        dialogKey: dialogKey,
        width: dialogWidth,
        maxHeight: dialogHeight,
        child: page,
      ),
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

    return _AdaptivePageDialog(
      dialogKey: dialogKey,
      width: dialogWidth,
      maxHeight: dialogHeight,
      child: scaffold,
    );
  }
}

class _AdaptivePageDialog extends StatefulWidget {
  final Key? dialogKey;
  final double width;
  final double maxHeight;
  final Widget child;

  const _AdaptivePageDialog({
    required this.dialogKey,
    required this.width,
    required this.maxHeight,
    required this.child,
  });

  @override
  State<_AdaptivePageDialog> createState() => _AdaptivePageDialogState();
}

class _AdaptivePageDialogState extends State<_AdaptivePageDialog> {
  static const _compactHeight = 320.0;
  double _height = _compactHeight;
  bool _resizeScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final viewportHeight = MediaQuery.sizeOf(context).height - 48;
    final maxHeight = math.min(widget.maxHeight, viewportHeight);
    _height = math.min(_height, maxHeight);
  }

  bool _onMetrics(ScrollMetricsNotification notification) {
    final metrics = notification.metrics;
    if (metrics.axis != Axis.vertical || metrics.maxScrollExtent <= 1) {
      return false;
    }
    final viewportHeight = MediaQuery.sizeOf(context).height - 48;
    final maxHeight = math.min(widget.maxHeight, viewportHeight);
    final target = math.min(_height + metrics.maxScrollExtent, maxHeight);
    if (target <= _height + 1 || _resizeScheduled) return false;

    _resizeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resizeScheduled = false;
      if (mounted) setState(() => _height = target);
    });
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: SizedBox(
          key: widget.dialogKey,
          width: math.min(widget.width, viewport.width - 48),
          height: _height,
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: _onMetrics,
            child: widget.child,
          ),
        ),
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
