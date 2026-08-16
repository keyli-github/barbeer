import 'package:flutter/material.dart';

@immutable
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  final Color primary;
  final Color primaryDark;
  final Color primaryLight;
  final Color primarySurface;
  final Color primaryBorder;
  final Color brand;
  final Color brandDark;
  final Color brandLight;
  final Color brandSurface;
  final Color background;
  final Color backgroundAlt;
  final Color surface;
  final Color surfaceAlt;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textDisabled;
  final Color border;
  final Color borderLight;
  final Color divider;
  final Color success;
  final Color successLight;
  final Color successBorder;
  final Color warning;
  final Color warningLight;
  final Color warningBorder;
  final Color error;
  final Color errorLight;
  final Color errorBorder;
  final Color info;
  final Color infoLight;
  final Color infoBorder;
  final Color navActive;
  final Color navInactive;
  final Color navBackground;

  const AppThemeColors({
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.primarySurface,
    required this.primaryBorder,
    required this.brand,
    required this.brandDark,
    required this.brandLight,
    required this.brandSurface,
    required this.background,
    required this.backgroundAlt,
    required this.surface,
    required this.surfaceAlt,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.border,
    required this.borderLight,
    required this.divider,
    required this.success,
    required this.successLight,
    required this.successBorder,
    required this.warning,
    required this.warningLight,
    required this.warningBorder,
    required this.error,
    required this.errorLight,
    required this.errorBorder,
    required this.info,
    required this.infoLight,
    required this.infoBorder,
    required this.navActive,
    required this.navInactive,
    required this.navBackground,
  });

  static const light = AppThemeColors(
    primary: Color(0xFFF97316),
    primaryDark: Color(0xFFEA580C),
    primaryLight: Color(0xFFFB923C),
    primarySurface: Color(0xFFFFF7ED),
    primaryBorder: Color(0xFFFDBA74),
    brand: Color(0xFFF97316),
    brandDark: Color(0xFFEA580C),
    brandLight: Color(0xFFFED7AA),
    brandSurface: Color(0xFFFFF7ED),
    background: Color(0xFFF5F7FB),
    backgroundAlt: Color(0xFFF0F2F7),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF3F4F6),
    textPrimary: Color(0xFF111827),
    textSecondary: Color(0xFF6B7280),
    textTertiary: Color(0xFF9CA3AF),
    textDisabled: Color(0xFFD1D5DB),
    border: Color(0xFFE5E7EB),
    borderLight: Color(0xFFF3F4F6),
    divider: Color(0xFFF3F4F6),
    success: Color(0xFF059669),
    successLight: Color(0xFFD1FAE5),
    successBorder: Color(0xFF6EE7B7),
    warning: Color(0xFFD97706),
    warningLight: Color(0xFFFEF3C7),
    warningBorder: Color(0xFFFCD34D),
    error: Color(0xFFDC2626),
    errorLight: Color(0xFFFEE2E2),
    errorBorder: Color(0xFFFCA5A5),
    info: Color(0xFF2563EB),
    infoLight: Color(0xFFDCEAFE),
    infoBorder: Color(0xFF93C5FD),
    navActive: Color(0xFFF97316),
    navInactive: Color(0xFF9CA3AF),
    navBackground: Color(0xFFFFFFFF),
  );

  static const dark = AppThemeColors(
    primary: Color(0xFFF97316),
    primaryDark: Color(0xFFEA580C),
    primaryLight: Color(0xFFFB923C),
    primarySurface: Color(0xFF431407),
    primaryBorder: Color(0xFF9A3412),
    brand: Color(0xFFF97316),
    brandDark: Color(0xFFEA580C),
    brandLight: Color(0xFF9A3412),
    brandSurface: Color(0xFF431407),
    background: Color(0xFF0B0B0D),
    backgroundAlt: Color(0xFF080809),
    surface: Color(0xFF131316),
    surfaceAlt: Color(0xFF181820),
    textPrimary: Color(0xFFE8EAF2),
    textSecondary: Color(0xFFC9CCDB),
    textTertiary: Color(0xFF7E839E),
    textDisabled: Color(0xFF4F5263),
    border: Color(0xFF29292E),
    borderLight: Color(0xFF242428),
    divider: Color(0xFF242428),
    success: Color(0xFF34D399),
    successLight: Color(0xFF063D31),
    successBorder: Color(0xFF087F5B),
    warning: Color(0xFFFBBF24),
    warningLight: Color(0xFF422F08),
    warningBorder: Color(0xFF8A5D08),
    error: Color(0xFFF87171),
    errorLight: Color(0xFF481B1B),
    errorBorder: Color(0xFF8F3030),
    info: Color(0xFF60A5FA),
    infoLight: Color(0xFF172554),
    infoBorder: Color(0xFF1E40AF),
    navActive: Color(0xFFF97316),
    navInactive: Color(0xFF7E839E),
    navBackground: Color(0xFF080809),
  );

  @override
  AppThemeColors copyWith() => this;

  @override
  AppThemeColors lerp(covariant AppThemeColors? other, double t) {
    if (other == null) return this;
    return AppThemeColors(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      primarySurface: Color.lerp(primarySurface, other.primarySurface, t)!,
      primaryBorder: Color.lerp(primaryBorder, other.primaryBorder, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      brandDark: Color.lerp(brandDark, other.brandDark, t)!,
      brandLight: Color.lerp(brandLight, other.brandLight, t)!,
      brandSurface: Color.lerp(brandSurface, other.brandSurface, t)!,
      background: Color.lerp(background, other.background, t)!,
      backgroundAlt: Color.lerp(backgroundAlt, other.backgroundAlt, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderLight: Color.lerp(borderLight, other.borderLight, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      success: Color.lerp(success, other.success, t)!,
      successLight: Color.lerp(successLight, other.successLight, t)!,
      successBorder: Color.lerp(successBorder, other.successBorder, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningLight: Color.lerp(warningLight, other.warningLight, t)!,
      warningBorder: Color.lerp(warningBorder, other.warningBorder, t)!,
      error: Color.lerp(error, other.error, t)!,
      errorLight: Color.lerp(errorLight, other.errorLight, t)!,
      errorBorder: Color.lerp(errorBorder, other.errorBorder, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoLight: Color.lerp(infoLight, other.infoLight, t)!,
      infoBorder: Color.lerp(infoBorder, other.infoBorder, t)!,
      navActive: Color.lerp(navActive, other.navActive, t)!,
      navInactive: Color.lerp(navInactive, other.navInactive, t)!,
      navBackground: Color.lerp(navBackground, other.navBackground, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppThemeColors get colors =>
      Theme.of(this).extension<AppThemeColors>() ?? AppThemeColors.light;
}
