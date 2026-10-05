import 'dart:async';

import 'package:hitup/features/auth/domain/models/auth_user.dart';
import 'package:hitup/features/auth/domain/repositories/auth_repository.dart';

/// An [AuthRepository] that records every call and answers as told: with
/// [error] when one is set, and not until [hold] completes while it is set.
class FakeAuthRepository implements AuthRepository {
  /// The calls made, oldest first, with what they were given.
  final List<String> calls = <String>[];

  /// What the next calls throw, if anything.
  Object? error;

  /// While set, calls wait for it before answering.
  Completer<void>? hold;

  Future<void> _answer() async {
    if (hold != null) {
      await hold!.future;
    }
    if (error != null) {
      throw error!;
    }
  }

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    calls.add('signIn $email $password');
    await _answer();
    return const AuthUser(uid: 'uid-1');
  }

  @override
  Future<AuthUser> register({
    required String email,
    required String password,
    String displayName = '',
  }) async {
    calls.add('register [$displayName] $email $password');
    await _answer();
    return const AuthUser(uid: 'uid-1');
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    calls.add('reset $email');
    await _answer();
  }

  @override
  Stream<AuthUser?> authStateChanges() => const Stream<AuthUser?>.empty();

  @override
  AuthUser? get currentUser => null;

  @override
  Future<void> signOut() async {}
}
