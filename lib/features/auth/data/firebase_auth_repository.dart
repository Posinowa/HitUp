import 'package:flutter/foundation.dart';

import '../domain/models/auth_user.dart';
import '../domain/repositories/auth_repository.dart';
import 'auth_gateway.dart';
import 'user_profile_store.dart';

/// [AuthRepository] over an [AuthGateway] and a [UserProfileStore].
///
/// Named for Firebase because that is what production wires in, but it holds
/// no Firebase type itself. Every decision this feature makes lives here and is
/// tested against fakes; the two collaborators only make the calls.
class FirebaseAuthRepository implements AuthRepository {
  /// Creates the repository.
  FirebaseAuthRepository({
    required AuthGateway gateway,
    required UserProfileStore profiles,
  })  : _gateway = gateway,
        _profiles = profiles;

  final AuthGateway _gateway;
  final UserProfileStore _profiles;

  @override
  Stream<AuthUser?> authStateChanges() => _gateway.authStateChanges();

  @override
  AuthUser? get currentUser => _gateway.currentUser;

  @override
  Future<AuthUser> register({
    required String email,
    required String password,
    String displayName = '',
  }) async {
    // Checked before the account exists. Past this length the rules refuse the
    // profile, so letting it through would create an account only to delete it
    // again, and hand the user a permission error for a typing mistake. The
    // registration screen is where the length is validated for the user; this
    // is the caller bug that slipped past it.
    if (displayName.length > maxDisplayNameLength) {
      throw ArgumentError.value(
        displayName.length,
        'displayName',
        'Longer than $maxDisplayNameLength characters',
      );
    }

    final String address = email.trim();
    final AuthUser account =
        await _gateway.createUser(email: address, password: password);

    try {
      if (displayName.isNotEmpty) {
        await _gateway.updateDisplayName(displayName);
      }
      await _profiles.createProfile(
        uid: account.uid,
        email: address,
        displayName: displayName,
      );
    } on Object catch (error, stackTrace) {
      await _rollBack(account);
      Error.throwWithStackTrace(error, stackTrace);
    }

    return AuthUser(
      uid: account.uid,
      email: address,
      displayName: displayName.isEmpty ? null : displayName,
    );
  }

  /// Deletes an account whose profile could not be written.
  ///
  /// Without this, a failed profile write leaves an account that can sign in
  /// but has no `users/{uid}`, and every screen after sign in would meet a user
  /// the data model says cannot exist.
  ///
  /// If the delete fails too, the original error is still the one thrown,
  /// because it is the reason registration failed. The delete failure is
  /// printed rather than dropped, so it is visible while debugging; it carries
  /// no password and names the account only by uid.
  Future<void> _rollBack(AuthUser account) async {
    try {
      await _gateway.deleteCurrentUser();
    } on Object catch (error) {
      debugPrint(
        'HIT-016: could not delete $account after its profile failed. '
        'Cause: $error',
      );
    }
  }

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) =>
      _gateway.signIn(email: email.trim(), password: password);

  @override
  Future<void> signOut() => _gateway.signOut();

  @override
  Future<void> sendPasswordResetEmail({required String email}) =>
      _gateway.sendPasswordResetEmail(email.trim());
}
