import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/core/errors/failure.dart';
import 'package:hitup/core/errors/failure_code.dart';
import 'package:hitup/core/errors/failure_mapper.dart';
import 'package:hitup/features/auth/data/auth_gateway.dart';
import 'package:hitup/features/auth/data/firebase_auth_repository.dart';
import 'package:hitup/features/auth/data/user_profile_store.dart';
import 'package:hitup/features/auth/domain/models/auth_user.dart';
import 'package:hitup/features/auth/domain/repositories/auth_repository.dart';

import '../../../support/firestore_rules.dart';

/// A gateway that records what it was asked and fails on request.
class _FakeGateway implements AuthGateway {
  final List<String> calls = <String>[];
  final StreamController<AuthUser?> states =
      StreamController<AuthUser?>.broadcast();

  AuthUser? signedIn;
  String? lastEmail;
  String? lastPassword;
  String? lastDisplayName;

  Object? createError;
  Object? signInError;
  Object? updateNameError;
  Object? deleteError;

  /// Closes [states]; called from `tearDown`.
  Future<void> close() => states.close();

  @override
  Stream<AuthUser?> authStateChanges() => states.stream;

  @override
  AuthUser? get currentUser => signedIn;

  @override
  Future<AuthUser> createUser({
    required String email,
    required String password,
  }) async {
    calls.add('createUser');
    lastEmail = email;
    lastPassword = password;
    if (createError != null) throw createError!;
    return signedIn = AuthUser(uid: 'uid-1', email: email);
  }

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    calls.add('signIn');
    lastEmail = email;
    lastPassword = password;
    if (signInError != null) throw signInError!;
    return signedIn = AuthUser(uid: 'uid-1', email: email);
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    calls.add('updateDisplayName');
    lastDisplayName = displayName;
    if (updateNameError != null) throw updateNameError!;
  }

  @override
  Future<void> deleteCurrentUser() async {
    calls.add('deleteCurrentUser');
    if (deleteError != null) throw deleteError!;
    signedIn = null;
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    signedIn = null;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    calls.add('sendPasswordResetEmail');
    lastEmail = email;
  }
}

/// A profile store that records the profile it was given.
class _FakeStore implements UserProfileStore {
  final List<Map<String, String>> created = <Map<String, String>>[];
  Object? error;

  @override
  Future<void> createProfile({
    required String uid,
    required String email,
    required String displayName,
  }) async {
    if (error != null) throw error!;
    created.add(<String, String>{
      'uid': uid,
      'email': email,
      'displayName': displayName,
    });
  }
}

void main() {
  late _FakeGateway gateway;
  late _FakeStore store;
  late FirebaseAuthRepository repository;

  setUp(() {
    gateway = _FakeGateway();
    store = _FakeStore();
    repository = FirebaseAuthRepository(gateway: gateway, profiles: store);
  });

  tearDown(() => gateway.close());

  group('register', () {
    test('creates the account, names it, and writes its profile', () async {
      final AuthUser user = await repository.register(
        email: 'ada@example.com',
        password: 'correct horse',
        displayName: 'Ada',
      );

      expect(gateway.calls, <String>['createUser', 'updateDisplayName']);
      expect(gateway.lastPassword, 'correct horse');
      expect(gateway.lastDisplayName, 'Ada');
      expect(store.created, <Map<String, String>>[
        <String, String>{
          'uid': 'uid-1',
          'email': 'ada@example.com',
          'displayName': 'Ada',
        },
      ]);
      expect(
        user,
        const AuthUser(
          uid: 'uid-1',
          email: 'ada@example.com',
          displayName: 'Ada',
        ),
      );
    });

    test('trims the email but never the password', () async {
      await repository.register(
        email: '  ada@example.com ',
        password: ' spaced password ',
      );

      expect(gateway.lastEmail, 'ada@example.com');
      expect(gateway.lastPassword, ' spaced password ');
      expect(store.created.single['email'], 'ada@example.com');
    });

    test('without a display name, sets none and stores an empty one', () async {
      final AuthUser user = await repository.register(
        email: 'ada@example.com',
        password: 'correct horse',
      );

      expect(gateway.calls, <String>['createUser']);
      expect(store.created.single['displayName'], '');
      expect(user.displayName, isNull);
    });

    test('a display name over the limit is refused before any account exists',
        () async {
      await expectLater(
        repository.register(
          email: 'ada@example.com',
          password: 'correct horse',
          displayName: 'a' * (maxDisplayNameLength + 1),
        ),
        throwsArgumentError,
      );
      expect(gateway.calls, isEmpty);
      expect(store.created, isEmpty);
    });

    test('a display name exactly at the limit is accepted', () async {
      await repository.register(
        email: 'ada@example.com',
        password: 'correct horse',
        displayName: 'a' * maxDisplayNameLength,
      );
      expect(store.created, hasLength(1));
    });

    test('an email already in use writes no profile and deletes nothing',
        () async {
      gateway.createError = FirebaseAuthException(code: 'email-already-in-use');

      final Object error = await repository
          .register(email: 'ada@example.com', password: 'correct horse')
          .then<Object>((_) => fail('expected an error'))
          .catchError((Object e) => e);

      expect(gateway.calls, <String>['createUser']);
      expect(store.created, isEmpty);
      expect(mapErrorToFailure(error).code, FailureCode.authEmailInUse);
    });
  });

  group('register rolls back a half-created account', () {
    test('a failed profile write deletes the new account and rethrows',
        () async {
      final FirebaseException refused =
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
      store.error = refused;

      final Object error = await repository
          .register(email: 'ada@example.com', password: 'correct horse')
          .then<Object>((_) => fail('expected an error'))
          .catchError((Object e) => e);

      expect(identical(error, refused), isTrue);
      expect(gateway.calls, <String>['createUser', 'deleteCurrentUser']);
      expect(gateway.signedIn, isNull);
      expect(mapErrorToFailure(error).code, FailureCode.networkUnavailable);
    });

    test('a failed display name update deletes the new account too', () async {
      gateway.updateNameError =
          FirebaseAuthException(code: 'network-request-failed');

      await expectLater(
        repository.register(
          email: 'ada@example.com',
          password: 'correct horse',
          displayName: 'Ada',
        ),
        throwsA(isA<FirebaseAuthException>()),
      );

      expect(
        gateway.calls,
        <String>['createUser', 'updateDisplayName', 'deleteCurrentUser'],
      );
      expect(store.created, isEmpty);
    });

    test('if the delete fails as well, the original error is the one thrown',
        () async {
      final FirebaseException refused =
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
      store.error = refused;
      gateway.deleteError =
          FirebaseAuthException(code: 'requires-recent-login');

      final Object error = await repository
          .register(email: 'ada@example.com', password: 'correct horse')
          .then<Object>((_) => fail('expected an error'))
          .catchError((Object e) => e);

      expect(identical(error, refused), isTrue);
      expect(gateway.calls.last, 'deleteCurrentUser');
    });
  });

  group('sign in, sign out, password reset', () {
    test('sign in trims the email and returns the account', () async {
      final AuthUser user = await repository.signIn(
        email: ' ada@example.com',
        password: 'correct horse',
      );

      expect(gateway.lastEmail, 'ada@example.com');
      expect(gateway.lastPassword, 'correct horse');
      expect(user.uid, 'uid-1');
    });

    test('a wrong password maps to invalid credentials, not user not found',
        () async {
      gateway.signInError = FirebaseAuthException(code: 'wrong-password');

      final Object error = await repository
          .signIn(email: 'ada@example.com', password: 'nope')
          .then<Object>((_) => fail('expected an error'))
          .catchError((Object e) => e);

      final Failure failure = mapErrorToFailure(error);
      expect(failure, isA<AuthFailure>());
      expect(failure.code, FailureCode.authInvalidCredentials);
    });

    test('sign out reaches the provider', () async {
      await repository.register(email: 'ada@example.com', password: 'pw');
      await repository.signOut();

      expect(gateway.calls.last, 'signOut');
      expect(repository.currentUser, isNull);
    });

    test('password reset trims the email', () async {
      await repository.sendPasswordResetEmail(email: 'ada@example.com  ');

      expect(gateway.calls, <String>['sendPasswordResetEmail']);
      expect(gateway.lastEmail, 'ada@example.com');
    });
  });

  group('signed-in state', () {
    test('authStateChanges passes the provider stream through', () async {
      const AuthUser ada = AuthUser(uid: 'uid-1', email: 'ada@example.com');
      final Future<List<AuthUser?>> seen =
          repository.authStateChanges().take(3).toList();

      gateway.states
        ..add(null)
        ..add(ada)
        ..add(null);

      expect(await seen, <AuthUser?>[null, ada, null]);
    });

    test('currentUser is the provider current user', () async {
      expect(repository.currentUser, isNull);
      await repository.signIn(email: 'ada@example.com', password: 'pw');
      expect(repository.currentUser?.uid, 'uid-1');
    });
  });

  group('the documents a new account starts with', () {
    test('the profile carries the model defaults and nothing else', () {
      final Map<String, Object> fields = newUserProfileFields(
        email: 'ada@example.com',
        displayName: 'Ada',
      );

      expect(fields, <String, Object>{
        'displayName': 'Ada',
        'email': 'ada@example.com',
        'currentProgramDay': 1,
        'totalTrainingMinutes': 0,
        'currentStreak': 0,
        'longestStreak': 0,
      });
      // Absent means never trained; an empty string or null would blur that.
      expect(fields.containsKey('lastTrainingDate'), isFalse);
    });

    test('preferences start with reminders off and no invented hour', () {
      expect(newUserPreferences(), <String, Object>{
        'reminderEnabled': false,
        'soundEnabled': true,
        'hapticEnabled': true,
      });
    });

    test('every field written on registration is one the rules allow', () {
      // The rules refuse any field outside their list. A field added here but
      // not there would pass every test above and fail on the first real
      // registration, as a permission error the user could do nothing about.
      final Set<String> profile = <String>{
        ...newUserProfileFields(email: 'a@b.c', displayName: '').keys,
        'createdAt',
      };
      expect(rulesFieldsOf('isValidUser'), containsAll(profile));
      expect(
        rulesFieldsOf('isValidPreferences'),
        containsAll(newUserPreferences().keys),
      );
    });
  });

  test('users compare by every field, and equal users hash alike', () {
    // Built at run time rather than as constants: two identical const values
    // are one instance, which would only ever test `identical`.
    AuthUser user({String uid = 'uid-1', String? email, String? name}) =>
        AuthUser(
          uid: uid,
          email: email ?? 'ada@example.com',
          displayName: name ?? 'Ada',
        );

    expect(user(), user());
    expect(user().hashCode, user().hashCode);
    expect(user(), isNot(user(uid: 'uid-2')));
    expect(user(), isNot(user(email: 'other@example.com')));
    expect(user(), isNot(user(name: 'Grace')));
  });

  test('a user prints as its uid, without email or name', () {
    const AuthUser user = AuthUser(
      uid: 'uid-1',
      email: 'ada@example.com',
      displayName: 'Ada',
    );
    expect(user.toString(), 'AuthUser(uid-1)');
  });
}
