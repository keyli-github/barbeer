import 'package:flutter/material.dart';

export 'app_theme_colors.dart';

/// Colores semanticos invariantes de marca y roles.
///
/// Los colores de interfaz se obtienen con `context.colors`.
class AppColors {
  AppColors._();

  // ── Primario BarBeer (acciones, tabs activos, botones) ───────────────────
  static const Color primary = Color(0xFFF97316);
  static const Color primaryDark = Color(0xFFEA580C);
  static const Color primaryLight = Color(0xFFFB923C);

  // ── Naranja BarBeer (marca, etiqueta de rol, acentos) ───────────────────
  static const Color brand = Color(0xFFF97316);
  static const Color brandDark = Color(0xFFEA580C);

  // ── Estados semánticos ───────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);

  static const Color warning = Color(0xFFF59E0B);

  static const Color error = Color(0xFFEF4444);

  static const Color info = Color(0xFF3B82F6);

  // ── Navegación ───────────────────────────────────────────────────────────
  static const Color navActive = Color(0xFFF97316);

  // ── Roles ────────────────────────────────────────────────────────────────
  static const Color roleSuperadmin = Color(0xFF7C3AED);
  static const Color roleAdmin = Color(0xFF059669);
  static const Color roleCajero = Color(0xFF2563EB);
  static const Color roleVendedora = Color(0xFFF97316);

  // ── Avatares ─────────────────────────────────────────────────────────────
  static const List<Color> avatarColors = [
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFF10B981),
    Color(0xFFEF4444),
    Color(0xFFF97316),
    Color(0xFF0EA5E9),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
    Color(0xFF6366F1),
  ];

  static Color avatarColor(String seed) =>
      avatarColors[seed.hashCode.abs() % avatarColors.length];

  static Color roleColor(String role) {
    switch (role.toUpperCase()) {
      case 'SUPERADMIN':
        return roleSuperadmin;
      case 'ADMIN':
        return roleAdmin;
      case 'CAJERO':
        return roleCajero;
      case 'VENDEDORA':
        return roleVendedora;
      default:
        return primary;
    }
  }
}

/// Sombras calibradas para estilo iOS/iPhone
class AppShadows {
  AppShadows._();

  static final List<BoxShadow> card = [
    BoxShadow(
      color: const Color(0xFF000000).withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: const Color(0xFF000000).withValues(alpha: 0.02),
      blurRadius: 2,
      offset: const Offset(0, 0),
    ),
  ];

  static final List<BoxShadow> cardElevated = [
    BoxShadow(
      color: const Color(0xFF000000).withValues(alpha: 0.08),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static final List<BoxShadow> sheet = [
    BoxShadow(
      color: const Color(0xFF000000).withValues(alpha: 0.10),
      blurRadius: 32,
      offset: const Offset(0, -4),
    ),
  ];

  static final List<BoxShadow> nav = [
    BoxShadow(
      color: const Color(0xFF000000).withValues(alpha: 0.06),
      blurRadius: 20,
      offset: const Offset(0, -4),
    ),
    BoxShadow(
      color: const Color(0xFF000000).withValues(alpha: 0.03),
      blurRadius: 4,
      offset: const Offset(0, -1),
    ),
  ];

  static final List<BoxShadow> button = [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.25),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static final List<BoxShadow> none = [];
}
