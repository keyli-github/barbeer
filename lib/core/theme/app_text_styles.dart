import "package:flutter/material.dart";
import "app_colors.dart";

class AppTextStyles {
  AppTextStyles._();
  static const TextStyle displayLarge = TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.5, height: 1.2);
  static const TextStyle displayMedium = TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.3, height: 1.25);
  static const TextStyle headlineLarge = TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.2, height: 1.3);
  static const TextStyle headlineMedium = TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary, height: 1.3);
  static const TextStyle titleLarge = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary, height: 1.4);
  static const TextStyle titleMedium = TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary, height: 1.4);
  static const TextStyle bodyLarge = TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.textPrimary, height: 1.5);
  static const TextStyle bodyMedium = TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textSecondary, height: 1.5);
  static const TextStyle bodySmall = TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.textSecondary, height: 1.45);
  static const TextStyle labelLarge = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.3);
  static const TextStyle labelSmall = TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textTertiary, letterSpacing: 0.2);
  static const TextStyle appBarTitle = TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static const TextStyle buttonText = TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.2);
  static const TextStyle inputText = TextStyle(fontSize: 14.5, fontWeight: FontWeight.w400, color: AppColors.textPrimary);
  static const TextStyle hintText = TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textHint);
}
