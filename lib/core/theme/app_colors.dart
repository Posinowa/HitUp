import 'package:flutter/painting.dart';

/// HitUp design tokens. Seafoam baseline, approved in HIT-007.
///
/// See `docs/design/IDENTITY.md` for the full rationale, contrast notes,
/// and the variants that were considered.
///
/// [primary] is the accessible, interactive tone (buttons, links). The
/// lighter [primaryContainer] swatch fails contrast with white text, so it
/// is a soft surface color, always paired with dark text.
abstract final class AppColors {
  static const Color primary = Color(0xFF257C6C);
  static const Color primaryContainer = Color(0xFF48BCA2);
  static const Color secondary = Color(0xFF48BCA2);
  static const Color accent = Color(0xFFA3E4D7);

  static const Color background = Color(0xFFF4F9F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color outline = Color(0xFFD3E6E1);

  static const Color textPrimary = Color(0xFF132522);
  static const Color textSecondary = Color(0xFF516B66);

  static const Color success = Color(0xFF2ECC71);
  static const Color error = Color(0xFFE74C3C);
  static const Color warning = Color(0xFFF39C12);

  /// Surface behind an error message, and the text that sits on it.
  ///
  /// [error] is the alert tone: strong enough to be noticed, too dark to read
  /// small text on. White on it measures 3.82:1 and the darkest text token
  /// measures 4.18:1, both under the 4.5:1 needed for body text, so nothing in
  /// the palette could be written on it legibly. That is why an error message
  /// gets its own quieter surface instead of being painted on [error] itself.
  ///
  /// Neither value is a new colour invented for this: both are [error] itself,
  /// [errorContainer] lightened towards white and [onErrorContainer] deepened
  /// towards black. The pair keeps the warmth of Coral Red rather than falling
  /// back to a neutral grey, and measures 9.86:1 together.
  ///
  /// [error] stays the right choice for anything that is not text on a
  /// surface: an icon, a border, a validation underline.
  static const Color errorContainer = Color(0xFFFCEAE8);
  static const Color onErrorContainer = Color(0xFF68221B);

  // Dark-mode tokens: not wired into a ThemeData yet (HIT-008 scope is
  // light-only), kept alongside the light set so dark mode can be added
  // later without re-deriving values.
  static const Color backgroundDark = Color(0xFF101A18);
  static const Color surfaceDark = Color(0xFF1B2A27);
  static const Color textPrimaryDark = Color(0xFFE8F6F3);
  static const Color textSecondaryDark = Color(0xFF8EABA5);
}
