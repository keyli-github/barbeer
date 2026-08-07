import 'package:flutter/material.dart';

/// Propaga desde ShellScreen si hay drawer disponible y cómo abrirlo.
/// Resuelve el problema de que Scaffold.maybeOf() detecta el Scaffold
/// interno de cada pantalla (sin drawer) en lugar del Shell externo.
class DrawerScope extends InheritedWidget {
  final bool hasDrawer;
  final VoidCallback openDrawer;

  const DrawerScope({
    super.key,
    required this.hasDrawer,
    required this.openDrawer,
    required super.child,
  });

  static DrawerScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DrawerScope>();

  @override
  bool updateShouldNotify(DrawerScope oldWidget) =>
      oldWidget.hasDrawer != hasDrawer;
}
