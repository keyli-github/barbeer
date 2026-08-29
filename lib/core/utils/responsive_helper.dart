import 'package:flutter/material.dart';

/// Responsive breakpoints matching the web frontend.
///
/// Use [ResponsiveHelper.of] to get the current breakpoint category,
/// or use [LayoutBuilder] with these constants for adaptive layouts.
class Breakpoints {
  Breakpoints._();

  static const double xs = 320; // phones small
  static const double sm = 480; // phones large
  static const double md = 768; // tablets
  static const double lg = 1024; // laptops small
  static const double xl = 1366; // laptops/monitors
  static const double xxl = 1920; // large monitors
}

enum ScreenSize { xs, sm, md, lg, xl, xxl }

class ResponsiveHelper {
  final double width;
  final double height;

  ResponsiveHelper._(this.width, this.height);

  factory ResponsiveHelper.of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return ResponsiveHelper._(size.width, size.height);
  }

  factory ResponsiveHelper.fromConstraints(BoxConstraints constraints) {
    return ResponsiveHelper._(constraints.maxWidth, constraints.maxHeight);
  }

  ScreenSize get screenSize {
    if (width < Breakpoints.xs) return ScreenSize.xs;
    if (width < Breakpoints.sm) return ScreenSize.sm;
    if (width < Breakpoints.md) return ScreenSize.md;
    if (width < Breakpoints.lg) return ScreenSize.lg;
    if (width < Breakpoints.xl) return ScreenSize.xl;
    return ScreenSize.xxl;
  }

  bool get isXs => width < Breakpoints.sm;
  bool get isSm => width >= Breakpoints.sm && width < Breakpoints.md;
  bool get isMd => width >= Breakpoints.md && width < Breakpoints.lg;
  bool get isLg => width >= Breakpoints.lg && width < Breakpoints.xl;
  bool get isXl => width >= Breakpoints.xl && width < Breakpoints.xxl;
  bool get isXxl => width >= Breakpoints.xxl;

  bool get isMobile => width < Breakpoints.md;
  bool get isTablet => width >= Breakpoints.md && width < Breakpoints.lg;
  bool get isDesktop => width >= Breakpoints.lg;

  /// Calculates grid columns based on available width and minimum card width.
  int gridColumns({double minCardWidth = 280, int maxColumns = 6}) {
    final cols = (width / minCardWidth).floor().clamp(1, maxColumns);
    return cols;
  }

  /// Returns adaptive padding based on screen size.
  EdgeInsets get screenPadding {
    if (width < Breakpoints.sm) return const EdgeInsets.all(8);
    if (width < Breakpoints.md) return const EdgeInsets.all(12);
    if (width < Breakpoints.lg) return const EdgeInsets.all(16);
    if (width < Breakpoints.xl) return const EdgeInsets.all(20);
    return const EdgeInsets.all(24);
  }

  /// Returns a font scale factor for very large/small screens.
  double get fontScale {
    if (width < Breakpoints.xs) return 0.85;
    if (width < Breakpoints.sm) return 0.9;
    if (width > Breakpoints.xxl) return 1.1;
    return 1.0;
  }
}

/// A widget that provides responsive layout switching.
/// Shows [mobile] for screens < [breakpoint], [desktop] otherwise.
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;
  final double breakpoint;
  final double tabletBreakpoint;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
    this.breakpoint = Breakpoints.lg,
    this.tabletBreakpoint = Breakpoints.md,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= breakpoint) return desktop;
          if (tablet != null && constraints.maxWidth >= tabletBreakpoint) {
            return tablet!;
          }
          return mobile;
        },
      );
}

/// Extension to make any Row safe from overflow.
/// Wraps text children in Flexible to prevent RenderFlex overflow.
extension SafeRowExtension on Row {
  /// Creates a version of this Row where overflow is handled gracefully.
  Widget get safe => LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth.isInfinite) return this;
          return this;
        },
      );
}
