import 'environment.dart';

/// Non-secret application configuration.
///
/// Package/bundle ID provisional: `com.posinowa.hitup` (HIT-078 — owner approval).
abstract final class AppConfig {
  static const String appName = 'HitUp';
  static const String provisionalApplicationId = 'com.posinowa.hitup';

  static Environment get environment => Environment.current;

  /// Public read-only media base URL placeholder (R2). Never put secrets here.
  static const String? remoteMediaBaseUrl = null;
}
