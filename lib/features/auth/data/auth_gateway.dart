import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/failure_code.dart';
import '../domain/models/auth_user.dart';

/// The part of an authentication provider this feature uses.
///
/// Narrow on purpose. The repository's decisions, what registration means,
/// when to roll back, what to trim, live above this line and are tested against
/// a fake. Below it sits only the call into the provider, with no logic of its
/// own to get wrong.
abstract interface class AuthGateway {
  /// The provider's signed-in state, as [AuthUser].
  Stream<AuthUser?> authStateChanges();

  /// The user signed in right now, or null.
  AuthUser? get currentUser;

  /// Creates an account and signs it in.
  Future<AuthUser> createUser({
    required String email,
    required String password,
  });

  /// Signs in an existing account.
  Future<AuthUser> signIn({required String email, required String password});

  /// Sets the display name on the signed-in account.
  Future<void> updateDisplayName(String displayName);

  /// Deletes the signed-in account.
  Future<void> deleteCurrentUser();

  /// Signs out.
  Future<void> signOut();

  /// Sends a password reset email.
  Future<void> sendPasswordResetEmail(String email);
}

/// [AuthGateway] backed by Firebase Auth.
class FirebaseAuthGateway implements AuthGateway {
  /// Creates a gateway over [auth].
  FirebaseAuthGateway(this._auth);

  final FirebaseAuth _auth;

  static AuthUser? _toAuthUser(User? user) => user == null
      ? null
      : AuthUser(
          uid: user.uid,
          email: user.email,
          displayName: user.displayName,
        );

  /// Converts the user a credential carries.
  ///
  /// Firebase types `UserCredential.user` as nullable. For email and password
  /// it is never null once the call returned, but a null here would otherwise
  /// surface much later as a confusing crash, so it is named now.
  static AuthUser _fromCredential(UserCredential credential, String operation) {
    final AuthUser? user = _toAuthUser(credential.user);
    if (user == null) {
      throw AppException(
        '$operation returned no user',
        code: FailureCode.authUnknown,
      );
    }
    return user;
  }

  @override
  Stream<AuthUser?> authStateChanges() =>
      _auth.authStateChanges().map(_toAuthUser);

  @override
  AuthUser? get currentUser => _toAuthUser(_auth.currentUser);

  @override
  Future<AuthUser> createUser({
    required String email,
    required String password,
  }) async =>
      _fromCredential(
        await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        ),
        'createUserWithEmailAndPassword',
      );

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async =>
      _fromCredential(
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        ),
        'signInWithEmailAndPassword',
      );

  @override
  Future<void> updateDisplayName(String displayName) =>
      _requireCurrentUser('updateDisplayName').updateDisplayName(displayName);

  @override
  Future<void> deleteCurrentUser() =>
      _requireCurrentUser('deleteCurrentUser').delete();

  /// The signed-in user, or an error saying there is none.
  ///
  /// Registration names the new account and, if its profile fails, deletes it
  /// again, and both act on the signed-in user. That holds because Firebase
  /// signs a user in when `createUserWithEmailAndPassword` succeeds. If it ever
  /// stopped holding, a `?.` here would skip the call without a word, and a
  /// rollback would leave the account in place while reporting nothing.
  User _requireCurrentUser(String operation) {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw AppException(
        '$operation needs a signed-in user and there is none',
        code: FailureCode.authUnknown,
      );
    }
    return user;
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> sendPasswordResetEmail(String email) =>
      _auth.sendPasswordResetEmail(email: email);
}
