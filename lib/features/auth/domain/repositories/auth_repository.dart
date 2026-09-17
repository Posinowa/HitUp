import '../models/auth_user.dart';

/// Account access for the app: registration, sign in and out, password reset,
/// and the signed-in state (HIT-016).
///
/// Widgets never reach Firebase Auth; they reach this. The implementation in
/// `data/` is the only place that knows which provider sits behind it, which is
/// what leaves room for Google or Apple sign in later: a new method here, a new
/// branch there, and no caller of the existing methods changes.
///
/// **Errors are thrown, not returned.** A method that fails throws what the
/// provider threw, or an `AppException` when this layer already knows what went
/// wrong. The controller calling it maps that once with `mapErrorToFailure`, as
/// `ERROR_HANDLING.md` describes, so no raw Firebase message reaches a screen
/// and no screen has to know one.
///
/// **Email is trimmed, passwords are not touched.** A trailing space from a
/// keyboard suggestion is not part of an address, and leaving it in turns a
/// correct email into `auth.invalid_email`. A password is used exactly as
/// given, and never logged.
abstract interface class AuthRepository {
  /// Emits the signed-in user whenever it changes, and null when signed out.
  ///
  /// Emits the current state as soon as it is listened to, so a listener does
  /// not wait for the next change to learn whether anyone is signed in.
  ///
  /// During [register] it emits the new user before that user's documents are
  /// written, and null again if the registration rolls back. `AUTH.md`
  /// describes what that means for an auth guard.
  Stream<AuthUser?> authStateChanges();

  /// The user signed in right now, or null.
  AuthUser? get currentUser;

  /// Creates an account and the user's documents, as one step.
  ///
  /// Writes `users/{uid}` and `users/{uid}/preferences/settings` with the
  /// defaults `FIRESTORE_MODEL.md` defines. If those documents cannot be
  /// written, the account just created is deleted again, so a registration
  /// either leaves an account with its profile or leaves nothing.
  ///
  /// [displayName] may be empty, and must be at most
  /// [maxDisplayNameLength] characters, the limit the security rules enforce.
  Future<AuthUser> register({
    required String email,
    required String password,
    String displayName = '',
  });

  /// Signs in with email and password.
  Future<AuthUser> signIn({required String email, required String password});

  /// Signs the current user out. Does nothing when nobody is signed in.
  Future<void> signOut();

  /// Sends a password reset email to [email].
  Future<void> sendPasswordResetEmail({required String email});
}

/// The longest display name `firestore.rules` accepts on `users/{uid}`.
const int maxDisplayNameLength = 100;
