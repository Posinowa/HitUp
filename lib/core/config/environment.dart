/// Runtime environment selector.
///
/// Keep simple: development vs production. Avoid over-engineering.
enum Environment {
  development,
  production;

  /// Foundation default until env flavors are wired with Firebase (HIT-009).
  static Environment get current => Environment.development;
}
