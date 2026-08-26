/// Base application exception for domain/data layers.
///
/// Throw this when a repository or use case already knows what went wrong.
/// Passing a [code] from `FailureCode` lets the mapper keep that meaning
/// instead of falling back to an unknown failure.
class AppException implements Exception {
  const AppException(this.message, {this.code, this.cause});

  /// Developer facing description. Never shown to users.
  final String message;

  /// Optional `FailureCode` value describing what went wrong.
  final String? code;

  final Object? cause;

  @override
  String toString() => 'AppException${code == null ? '' : '($code)'}: $message';
}
