import 'environment.dart';

/// Non-secret application configuration.
abstract final class AppConfig {
  static const String appName = 'HitUp';

  /// The package and bundle identifier the app ships under, settled by HIT-078.
  ///
  /// Written here as well as in `android/app/build.gradle` and the Xcode
  /// project because Dart cannot read either. The platform files are the ones
  /// that decide what gets built; this is a copy for code that needs to know
  /// the value, and the two have to be changed together.
  ///
  /// See `docs/architecture/ARCHITECTURE.md` for when this stops being
  /// changeable, which is earlier than most people expect.
  static const String applicationId = 'com.posinowa.hitup';

  static Environment get environment => Environment.current;

  /// Public read-only media base URL placeholder (R2). Never put secrets here.
  static const String? remoteMediaBaseUrl = null;
}
