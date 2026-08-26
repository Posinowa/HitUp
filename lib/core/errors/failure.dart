import 'package:hitup/core/errors/failure_code.dart';

/// A problem, described in a form the presentation layer can act on.
///
/// A `Failure` carries **no user facing text**. It carries a [code], which the
/// message table turns into a sentence, and [technicalDetail], which is for
/// logs and crash reporting and must never reach the screen.
///
/// The type is sealed so a `switch` over failures is checked for
/// exhaustiveness: adding a new kind makes every handler that forgot it fail
/// to compile, instead of silently falling through.
sealed class Failure {
  const Failure({required this.code, this.technicalDetail});

  /// Stable identifier from [FailureCode]. Never shown to users.
  final String code;

  /// Raw detail from the underlying error, for logs and crash reporting.
  /// Never shown to users.
  final String? technicalDetail;

  /// Whether offering the user a "try again" action makes sense.
  bool get isRetryable;

  @override
  String toString() => '$runtimeType($code)'
      '${technicalDetail == null ? '' : ': $technicalDetail'}';
}

/// Sign in, sign up, session and credential problems.
final class AuthFailure extends Failure {
  const AuthFailure({required super.code, super.technicalDetail});

  /// Retrying the same credentials changes nothing. The user must act.
  @override
  bool get isRetryable => false;
}

/// The device could not reach the service, or the service was unreachable.
final class NetworkFailure extends Failure {
  const NetworkFailure({required super.code, super.technicalDetail});

  @override
  bool get isRetryable => true;
}

/// The request was understood and refused. Retrying will be refused again.
final class PermissionFailure extends Failure {
  const PermissionFailure({required super.code, super.technicalDetail});

  @override
  bool get isRetryable => false;
}

/// Bundled curriculum, assets or media could not be loaded or parsed.
///
/// Not retryable: the bundle ships with the app, so a second attempt reads the
/// same broken file.
final class ContentFailure extends Failure {
  const ContentFailure({required super.code, super.technicalDetail});

  @override
  bool get isRetryable => false;
}

/// Stored user data could not be read or written for a reason that is neither
/// connectivity nor permission.
final class DataFailure extends Failure {
  const DataFailure({required super.code, super.technicalDetail});

  @override
  bool get isRetryable => true;
}

/// Nothing recognised the error. Always mapped, never swallowed.
final class UnknownFailure extends Failure {
  const UnknownFailure({
    super.code = FailureCode.unknown,
    super.technicalDetail,
  });

  @override
  bool get isRetryable => true;
}
