import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_dimensions.dart';
import 'app_text_styles.dart';

class AppTheme {
  AppTheme._();
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: Brightness.light,
        surface: AppColors.surface, onSurface: AppColors.textPrimary, primary: AppColors.primary,
        onPrimary: Colors.white, error: AppColors.error, onError: Colors.white),
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(backgroundColor: AppColors.surface, foregroundColor: AppColors.textPrimary,
        elevation: 0, scrolledUnderElevation: 0, centerTitle: false, titleTextStyle: AppTextStyles.appBarTitle,
        systemOverlayStyle: SystemUiOverlayStyle(statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark, statusBarBrightness: Brightness.light,
            systemNavigationBarColor: Colors.white, systemNavigationBarIconBrightness: Brightness.dark)),
    cardTheme: CardThemeData(color: AppColors.surface, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(color: AppColors.borderLight, width: 0.5)), margin: EdgeInsets.zero),
    inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: AppColors.backgroundAlt,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.error)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.error, width: 1.5)),
        hintStyle: AppTextStyles.hintText, labelStyle: AppTextStyles.bodyMedium,
        errorStyle: TextStyle(fontSize: 12, color: AppColors.error)),
    elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary, foregroundColor: Colors.white,
        disabledBackgroundColor: Color(0x802563EB), elevation: 0, shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        textStyle: AppTextStyles.buttonText, padding: EdgeInsets.symmetric(vertical: 15, horizontal: 24))),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: AppColors.primary,
        textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)))),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textSecondary, side: BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        padding: EdgeInsets.symmetric(vertical: 14))),
    chipTheme: ChipThemeData(backgroundColor: AppColors.backgroundAlt, selectedColor: AppColors.primarySurface,
        side: BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
        labelStyle: AppTextStyles.labelLarge, padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
    dialogTheme: DialogThemeData(backgroundColor: AppColors.surface, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg))),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: AppColors.surface, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)))),
    dividerTheme: DividerThemeData(color: AppColors.divider, thickness: 1, space: 1),
    floatingActionButtonTheme: FloatingActionButtonThemeData(backgroundColor: AppColors.primary,
        foregroundColor: Colors.white, elevation: 0, shape: CircleBorder()),
    snackBarTheme: SnackBarThemeData(backgroundColor: AppColors.textPrimary,
        contentTextStyle: TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        behavior: SnackBarBehavior.floating, elevation: 0),
    switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : AppColors.textTertiary),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.primary : AppColors.border)),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: AppColors.primary, linearTrackColor: AppColors.primarySurface),
  );
}
