import 'dart:async';

import 'package:hitup/features/auth/domain/models/auth_user.dart';
import 'package:hitup/features/auth/domain/repositories/auth_repository.dart';

/// An [AuthRepository] that records every call and answers as told: with
/// [error] when one is set, and not until [hold] completes while it is set.
///
/// Like Firebase, a sign-in or a registration that works signs the account
/// in, and [authStateChanges] says so; a sign-out says nobody is.
class FakeAuthRepository implements AuthRepository {
  /// The calls made, oldest first, with what they were given.
  final List<String> calls = <String>[];

  /// What the next calls throw, if anything.
  Object? error;

  /// While set, calls wait for it before answering.
  Completer<void>? hold;

  final StreamController<AuthUser?> _changes =
      StreamController<AuthUser?>.broadcast();
  AuthUser? _current;

  Future<void> _answer() async {
    if (hold != null) {
      await hold!.future;
    }
    if (error != null) {
      throw error!;
    }
  }

  void _become(AuthUser? user) {
    _current = user;
    _changes.add(user);
  }

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    calls.add('signIn $email $password');
    await _answer();
    const AuthUser user = AuthUser(uid: 'uid-1');
    _become(user);
    return user;
  }

  @override
  Future<AuthUser> register({
    required String email,
    required String password,
    String displayName = '',
  }) async {
    calls.add('register [$displayName] $email $password');
    await _answer();
    const AuthUser user = AuthUser(uid: 'uid-1');
    _become(user);
    return user;
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    calls.add('reset $email');
    await _answer();
  }

  /// Who is signed in now, then every change.
  @override
  Stream<AuthUser?> authStateChanges() async* {
    yield _current;
    yield* _changes.stream;
  }

  @override
  AuthUser? get currentUser => _current;

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    _become(null);
  }
}
