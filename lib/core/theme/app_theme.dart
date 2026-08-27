import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_typography.dart';

/// Central HitUp [ThemeData]. Seafoam baseline, approved in HIT-007.
///
/// See `docs/design/IDENTITY.md` for the token rationale. [AppColors.primary]
/// (not [AppColors.primaryContainer]) carries [Colors.white] foregrounds
/// because the lighter container swatch fails contrast with white text.
abstract final class AppTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.textPrimary,
      secondary: AppColors.secondary,
      onSecondary: AppColors.textPrimary,
      tertiary: AppColors.accent,
      onTertiary: AppColors.textPrimary,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      outline: AppColors.outline,
      error: AppColors.error,
      onError: Colors.white,
      // Spelled out rather than left to ColorScheme's fallbacks. Undeclared,
      // errorContainer resolves to error and onErrorContainer to onError, which
      // happens to be what HitUp wants today, but only by coincidence: the
      // moment onError or the error swatch changes, anything painted on an
      // error container follows silently. Naming the roles makes the pairing a
      // decision instead of a side effect.
      errorContainer: AppColors.error,
      onErrorContainer: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: AppTypography.textTheme(),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
    );
  }
}
