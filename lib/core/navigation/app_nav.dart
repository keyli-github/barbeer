import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Navegación hacia subpantallas usando el navegador RAÍZ.
///
/// Usando el navegador raíz (rootNavigator: true) la subpantalla se muestra
/// ENCIMA del Shell completo, ocultando correctamente:
///   • El header BarBeer del Shell
///   • La barra de navegación inferior flotante
///
/// La subpantalla tiene su propio AppBar con flecha de retroceso.
///
/// USO:
///   AppNav.push(context, DetalleVentaScreen(venta: v));
///   final result = await AppNav.push<bool>(context, FormScreen());
class AppNav {
  AppNav._();

  /// Navega a una subpantalla por encima del Shell (sin bottom nav ni header del Shell).
  static Future<T?> push<T>(BuildContext context, Widget page) {
    return Navigator.of(
      context,
      rootNavigator: true,
    ).push<T>(_SubPageRoute(page: page));
  }

  /// Reemplaza la pantalla actual (útil para flujos lineales).
  static Future<T?> replace<T>(BuildContext context, Widget page) {
    return Navigator.of(
      context,
      rootNavigator: true,
    ).pushReplacement<T, dynamic>(_SubPageRoute(page: page));
  }
}

/// Ruta con transición iOS-style (slide desde la derecha).
class _SubPageRoute<T> extends MaterialPageRoute<T> {
  _SubPageRoute({required Widget page})
    : super(builder: (_) => page, fullscreenDialog: false);

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(curved),
      child: child,
    );
  }
}

/// AppBar estándar para subpantallas — siempre blanco, flecha atrás.
class SubPageAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  final bool showLogo;

  const SubPageAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.onBack,
    this.showLogo = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: context.colors.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: GestureDetector(
        onTap: onBack ?? () => Navigator.of(context).pop(),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: context.colors.textPrimary,
            ),
          ),
        ),
      ),
      title: subtitle != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            )
          : Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
      actions: actions,
    );
  }
}
