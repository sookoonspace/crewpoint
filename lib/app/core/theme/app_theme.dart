import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_typography.dart';

/// Centralized theme configuration for CrewPoint.
abstract final class AppTheme {
  static ThemeData light() {
    final textTheme = AppTypography.textTheme(Brightness.light);
    return ThemeData(
      useMaterial3: true,
      brightness: .light,
      colorScheme: const ColorScheme.light(
        primary: AppColors.charcoal,
        onPrimary: AppColors.white,
        secondary: AppColors.sage,
        onSecondary: AppColors.white,
        tertiary: AppColors.terracotta,
        onTertiary: AppColors.white,
        surface: AppColors.white,
        onSurface: AppColors.charcoal,
        surfaceContainerHighest: AppColors.offWhite,
        error: AppColors.terracotta,
        onError: AppColors.white,
        outline: AppColors.lightGrey,
      ),
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.offWhite,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.charcoal,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.sage,
          foregroundColor: AppColors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lightGrey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lightGrey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.sage, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.lightGrey),
    );
  }

  static ThemeData dark() {
    final textTheme = AppTypography.textTheme(Brightness.dark);
    return ThemeData(
      useMaterial3: true,
      brightness: .dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.sageLight,
        onPrimary: AppColors.charcoalDark,
        secondary: AppColors.sage,
        onSecondary: AppColors.white,
        tertiary: AppColors.terracottaLight,
        onTertiary: AppColors.white,
        surface: AppColors.surfaceDark,
        onSurface: AppColors.offWhite,
        surfaceContainerHighest: AppColors.surfaceDarkElevated,
        error: AppColors.terracottaLight,
        onError: AppColors.charcoalDark,
        outline: AppColors.darkGrey,
      ),
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.surfaceDark,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surfaceDark,
        foregroundColor: AppColors.offWhite,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.sage,
          foregroundColor: AppColors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceDarkElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.darkGrey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.darkGrey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.sageLight, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceDarkElevated,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.darkGrey),
    );
  }
}
