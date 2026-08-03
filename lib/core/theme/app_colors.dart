import 'package:flutter/material.dart';

class AppColors {
  AppColors._();
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primarySurface = Color(0xFFEFF6FF);
  static const Color primaryBorder = Color(0xFFBFDBFE);
  static const Color accent = Color(0xFFF59E0B);
  static const Color accentLight = Color(0xFFFEF3C7);
  static const Color background = Color(0xFFFFFFFF);
  static const Color backgroundAlt = Color(0xFFF6F8FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color textHint = Color(0xFFBCC5D3);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFEDF2F7);
  static const Color divider = Color(0xFFF1F5F9);
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color navActive = Color(0xFF2563EB);
  static const Color navInactive = Color(0xFF94A3B8);
  static const Color roleSuperadmin = Color(0xFF7C3AED);
  static const Color roleAdmin = Color(0xFF16A34A);
  static const Color roleCajero = Color(0xFF2563EB);
  static const Color roleMozo = Color(0xFFF97316);
  static const Color roleCocina = Color(0xFFEF4444);
  static const Color roleBartender = Color(0xFF0EA5E9);

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
      case 'MOZO':
        return roleMozo;
      case 'COCINA':
        return roleCocina;
      case 'BARTENDER':
        return roleBartender;
      default:
        return primary;
    }
  }
}

class AppShadows {
  AppShadows._();
  static final List<BoxShadow> card = [
    BoxShadow(
      color: Colors.black.withOpacity(0.035),
      blurRadius: 14,
      offset: const Offset(0, 4),
      spreadRadius: -3,
    ),
  ];
  static final List<BoxShadow> cardElevated = [
    BoxShadow(
      color: Colors.black.withOpacity(0.07),
      blurRadius: 22,
      offset: const Offset(0, 8),
      spreadRadius: -5,
    ),
  ];
  static final List<BoxShadow> sheet = [
    BoxShadow(
      color: Colors.black.withOpacity(0.10),
      blurRadius: 32,
      offset: const Offset(0, -6),
    ),
  ];
  static final List<BoxShadow> nav = [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 20,
      offset: const Offset(0, -4),
      spreadRadius: -4,
    ),
  ];
  static final List<BoxShadow> button = [
    BoxShadow(
      color: primary.withOpacity(0.22),
      blurRadius: 14,
      offset: const Offset(0, 5),
      spreadRadius: -3,
    ),
  ];
}
