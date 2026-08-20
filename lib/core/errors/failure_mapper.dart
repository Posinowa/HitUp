import 'dart:async';
import 'dart:io';

// firebase_auth re-exports FirebaseException from firebase_core, so both the
// auth specific and the generic Firebase error types come from here.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hitup/core/errors/app_exception.dart';
import 'package:hitup/core/errors/failure.dart';
import 'package:hitup/core/errors/failure_code.dart';

/// Turns anything thrown anywhere into a [Failure].
///
/// This is the only place that knows what a Firebase error code means. Nothing
/// above this layer should ever inspect a plugin exception, and nothing below
/// it should ever build a user message.
///
/// The function is total: every input produces a [Failure], so an error can be
/// mishandled but never silently swallowed.
Failure mapErrorToFailure(Object error) {
  final detail = error.toString();

  return switch (error) {
    final Failure failure => failure,
    final AppException e => _fromAppException(e),
    final FirebaseAuthException e => _fromFirebaseAuth(e, detail),
    final FirebaseException e => _fromFirebaseGeneric(e, detail),
    final SocketException _ => const NetworkFailure(
        code: FailureCode.networkOffline,
      ),
    final TimeoutException _ => const NetworkFailure(
        code: FailureCode.networkTimeout,
      ),
    final HttpException _ => NetworkFailure(
        code: FailureCode.networkUnavailable,
        technicalDetail: detail,
      ),
    final FormatException _ => ContentFailure(
        code: FailureCode.contentMalformed,
        technicalDetail: detail,
      ),
    final FlutterError e => _fromFlutterError(e, detail),
    final PlatformException _ => ContentFailure(
        code: FailureCode.contentMediaUnavailable,
        technicalDetail: detail,
      ),
    _ => UnknownFailure(technicalDetail: detail),
  };
}

/// A repository that already knew what went wrong keeps its meaning.
Failure _fromAppException(AppException e) {
  final detail = e.toString();
  final code = e.code;
  if (code == null) {
    return UnknownFailure(technicalDetail: detail);
  }

  final family = code.split('.').first;
  return switch (family) {
    'auth' => AuthFailure(code: code, technicalDetail: detail),
    'network' => NetworkFailure(code: code, technicalDetail: detail),
    'permission' => PermissionFailure(code: code, technicalDetail: detail),
    'content' => ContentFailure(code: code, technicalDetail: detail),
    'data' => DataFailure(code: code, technicalDetail: detail),
    _ => UnknownFailure(code: code, technicalDetail: detail),
  };
}

Failure _fromFirebaseAuth(FirebaseAuthException e, String detail) {
  // A dropped connection during sign in is a connectivity problem wearing an
  // auth exception. Telling the user their password is wrong would be a lie.
  if (e.code == 'network-request-failed') {
    return NetworkFailure(
      code: FailureCode.networkOffline,
      technicalDetail: detail,
    );
  }

  final code = switch (e.code) {
    'invalid-credential' ||
    'invalid-login-credentials' ||
    'wrong-password' =>
      FailureCode.authInvalidCredentials,
    'user-not-found' => FailureCode.authUserNotFound,
    'user-disabled' => FailureCode.authUserDisabled,
    'email-already-in-use' => FailureCode.authEmailInUse,
    'invalid-email' => FailureCode.authInvalidEmail,
    'weak-password' => FailureCode.authWeakPassword,
    'too-many-requests' => FailureCode.authTooManyRequests,
    'requires-recent-login' => FailureCode.authRequiresRecentLogin,
    _ => FailureCode.authUnknown,
  };

  return AuthFailure(code: code, technicalDetail: detail);
}

/// Firestore and other Firebase plugins share [FirebaseException] and its
/// gRPC style status codes.
Failure _fromFirebaseGeneric(FirebaseException e, String detail) {
  return switch (e.code) {
    'permission-denied' => PermissionFailure(
        code: FailureCode.permissionDenied,
        technicalDetail: detail,
      ),
    'unavailable' => NetworkFailure(
        code: FailureCode.networkUnavailable,
        technicalDetail: detail,
      ),
    'deadline-exceeded' => NetworkFailure(
        code: FailureCode.networkTimeout,
        technicalDetail: detail,
      ),
    'not-found' => DataFailure(
        code: FailureCode.dataNotFound,
        technicalDetail: detail,
      ),
    'already-exists' || 'aborted' => DataFailure(
        code: FailureCode.dataConflict,
        technicalDetail: detail,
      ),
    _ => DataFailure(code: FailureCode.dataUnknown, technicalDetail: detail),
  };
}

/// `rootBundle` reports a missing asset as a [FlutterError].
Failure _fromFlutterError(FlutterError e, String detail) {
  final missingAsset = e.message.contains('Unable to load asset');
  return ContentFailure(
    code: missingAsset
        ? FailureCode.contentAssetMissing
        : FailureCode.contentMalformed,
    technicalDetail: detail,
  );
}
