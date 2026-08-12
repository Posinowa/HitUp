import 'package:flutter/painting.dart';

/// Temporary design tokens until HIT-007 corporate identity is approved.
///
/// STATUS: DRAFT / TEMPORARY
/// Feature widgets MUST use these tokens (or ThemeData) — never scattered Color(0xFF...).
abstract final class AppColors {
  static const Color primary = Color(0xFF0F3D3E);
  static const Color secondary = Color(0xFF1A5F61);
  static const Color accent = Color(0xFFC45C26);
  static const Color background = Color(0xFFF7F4EF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1B1B1B);
  static const Color textSecondary = Color(0xFF5C5C5C);
  static const Color success = Color(0xFF2E7D4F);
  static const Color error = Color(0xFFB3261E);
  static const Color outline = Color(0xFFD6D0C8);
}
