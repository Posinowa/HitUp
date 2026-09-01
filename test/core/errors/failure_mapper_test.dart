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
      final failure = mapErrorToFailure(const AppException('something broke'));
      expect(failure, isA<UnknownFailure>());
      expect(failure.code, FailureCode.unknown);
    });

    test('a code from a family this build does not know keeps its code', () {
      // The families above are the ones that exist today. A later release adds
      // one, and an exception carrying it reaches this build through stored
      // data or a shared package. Falling back to UnknownFailure is right;
      // throwing the code away is not, because the code is what logs and
      // analytics key off, and dropping it turns a specific report into an
      // unattributable one.
      final failure = mapErrorToFailure(
        const AppException(
          'thrown by a newer layer',
          code: 'billing.card_declined',
        ),
      );

      expect(failure, isA<UnknownFailure>());
      expect(failure.code, 'billing.card_declined');
      expect(failure.code, isNot(FailureCode.unknown));
    });
  });

  group('retryability', () {
    // Whether the error surface offers a "try again" button is decided here and
    // nowhere else, so each failure kind needs its own case. Three of the six
    // were covered through the mapper tests above; these are the rest.
    test('each failure kind decides for itself', () {
      const cases = <Failure, bool>{
        AuthFailure(code: FailureCode.authInvalidEmail): false,
        NetworkFailure(code: FailureCode.networkOffline): true,
        PermissionFailure(code: FailureCode.permissionDenied): false,
        ContentFailure(code: FailureCode.contentMalformed): false,
        DataFailure(code: FailureCode.dataNotFound): true,
        UnknownFailure(): true,
      };

      cases.forEach((Failure failure, bool retryable) {
        expect(
          failure.isRetryable,
          retryable,
          reason: '${failure.runtimeType} should '
              '${retryable ? '' : 'not '}offer a retry',
        );
      });
    });

    test('a data problem is worth retrying but a content one is not', () {
      // Stored data can succeed on a second attempt; the bundle ships with the
      // app, so re-reading it reads the same broken file.
      expect(
        mapErrorToFailure(
          const AppException('write failed', code: FailureCode.dataUnknown),
        ).isRetryable,
        isTrue,
      );
      expect(
        mapErrorToFailure(
          const AppException('bad json', code: FailureCode.contentMalformed),
        ).isRetryable,
        isFalse,
      );
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
