import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/core/errors/app_exception.dart';
import 'package:hitup/core/errors/failure.dart';
import 'package:hitup/core/errors/failure_code.dart';
import 'package:hitup/core/errors/failure_mapper.dart';

void main() {
  group('authentication errors', () {
    test(
      'credential problems map to a single shared code, so a login '
      'screen cannot tell an attacker which emails have an account',
      () {
        for (final code in [
          'invalid-credential',
          'invalid-login-credentials',
          'wrong-password',
          'user-not-found',
        ]) {
          final failure = mapErrorToFailure(FirebaseAuthException(code: code));
          expect(failure, isA<AuthFailure>(), reason: code);
          expect(
            failure.code,
            FailureCode.authInvalidCredentials,
            reason: code,
          );
        }
      },
    );

    test('each known auth code maps to its own failure code', () {
      const expected = {
        'user-disabled': FailureCode.authUserDisabled,
        'email-already-in-use': FailureCode.authEmailInUse,
        'invalid-email': FailureCode.authInvalidEmail,
        'weak-password': FailureCode.authWeakPassword,
        'too-many-requests': FailureCode.authTooManyRequests,
        'requires-recent-login': FailureCode.authRequiresRecentLogin,
      };

      expected.forEach((firebaseCode, failureCode) {
        final failure = mapErrorToFailure(
          FirebaseAuthException(code: firebaseCode),
        );
        expect(failure, isA<AuthFailure>(), reason: firebaseCode);
        expect(failure.code, failureCode, reason: firebaseCode);
      });
    });

    test('an unrecognised auth code still produces an auth failure', () {
      final failure = mapErrorToFailure(
        FirebaseAuthException(code: 'something-new-from-firebase'),
      );
      expect(failure, isA<AuthFailure>());
      expect(failure.code, FailureCode.authUnknown);
    });

    test(
      'a dropped connection during sign in is reported as a network problem',
      () {
        // Firebase reports this as an auth exception, but telling the user
        // their password is wrong would be a lie.
        final failure = mapErrorToFailure(
          FirebaseAuthException(code: 'network-request-failed'),
        );
        expect(failure, isA<NetworkFailure>());
        expect(failure.code, FailureCode.networkOffline);
        expect(failure.isRetryable, isTrue);
      },
    );
  });

  group('firestore and other firebase plugins', () {
    FirebaseException firestore(String code) =>
        FirebaseException(plugin: 'cloud_firestore', code: code);

    test('permission denied is not treated as retryable', () {
      final failure = mapErrorToFailure(firestore('permission-denied'));
      expect(failure, isA<PermissionFailure>());
      expect(failure.code, FailureCode.permissionDenied);
      expect(failure.isRetryable, isFalse);
    });

    test('transport level codes become network failures', () {
      expect(
        mapErrorToFailure(firestore('unavailable')),
        isA<NetworkFailure>().having(
          (f) => f.code,
          'code',
          FailureCode.networkUnavailable,
        ),
      );
      expect(
        mapErrorToFailure(firestore('deadline-exceeded')),
        isA<NetworkFailure>().having(
          (f) => f.code,
          'code',
          FailureCode.networkTimeout,
        ),
      );
    });

    test('record level codes become data failures', () {
      expect(
        mapErrorToFailure(firestore('not-found')),
        isA<DataFailure>().having(
          (f) => f.code,
          'code',
          FailureCode.dataNotFound,
        ),
      );
      expect(
        mapErrorToFailure(firestore('already-exists')),
        isA<DataFailure>().having(
          (f) => f.code,
          'code',
          FailureCode.dataConflict,
        ),
      );
      expect(
        mapErrorToFailure(firestore('resource-exhausted')),
        isA<DataFailure>().having(
          (f) => f.code,
          'code',
          FailureCode.dataUnknown,
        ),
      );
    });
  });

  group('platform and content errors', () {
    test('no connection maps to offline', () {
      final failure = mapErrorToFailure(const SocketException('no route'));
      expect(failure, isA<NetworkFailure>());
      expect(failure.code, FailureCode.networkOffline);
    });

    test('a timeout maps to timeout', () {
      final failure = mapErrorToFailure(TimeoutException('too slow'));
      expect(failure, isA<NetworkFailure>());
      expect(failure.code, FailureCode.networkTimeout);
    });

    test('unparseable content is a content failure, not retryable', () {
      final failure = mapErrorToFailure(const FormatException('bad json'));
      expect(failure, isA<ContentFailure>());
      expect(failure.code, FailureCode.contentMalformed);
      expect(failure.isRetryable, isFalse);
    });

    test('a missing bundled asset is recognised as such', () {
      final failure = mapErrorToFailure(
        FlutterError('Unable to load asset: assets/content/program.json'),
      );
      expect(failure, isA<ContentFailure>());
      expect(failure.code, FailureCode.contentAssetMissing);
    });
  });

  group('application exceptions', () {
    test('a code from the domain layer keeps its meaning', () {
      const cases = {
        FailureCode.authInvalidEmail: AuthFailure,
        FailureCode.networkTimeout: NetworkFailure,
        FailureCode.permissionDenied: PermissionFailure,
        FailureCode.contentMalformed: ContentFailure,
        FailureCode.dataNotFound: DataFailure,
      };

      cases.forEach((code, type) {
        final failure = mapErrorToFailure(
          AppException('thrown by a repository', code: code),
        );
        expect(failure.runtimeType, type, reason: code);
        expect(failure.code, code, reason: code);
      });
    });

    test('an exception without a code is not guessed at', () {
      final failure = mapErrorToFailure(AppException('something broke'));
      expect(failure, isA<UnknownFailure>());
      expect(failure.code, FailureCode.unknown);
    });
  });

  group('totality', () {
    test('an unrecognised object still produces a failure', () {
      final failure = mapErrorToFailure(Object());
      expect(failure, isA<UnknownFailure>());
      expect(failure.code, FailureCode.unknown);
    });

    test('a failure passed back in is returned unchanged', () {
      const original = NetworkFailure(code: FailureCode.networkOffline);
      expect(identical(mapErrorToFailure(original), original), isTrue);
    });

    test('the original error is preserved for logs, not for the user', () {
      final failure = mapErrorToFailure(
        FirebaseAuthException(
          code: 'wrong-password',
          message: 'The password is invalid.',
        ),
      );
      expect(failure.technicalDetail, isNotNull);
      expect(failure.technicalDetail, contains('wrong-password'));
    });
  });
}
