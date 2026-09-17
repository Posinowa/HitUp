import 'package:cloud_firestore/cloud_firestore.dart';

/// Writes the documents a new account starts with.
abstract interface class UserProfileStore {
  /// Creates `users/{uid}` and `users/{uid}/preferences/settings` together.
  ///
  /// Both succeed or neither is written.
  Future<void> createProfile({
    required String uid,
    required String email,
    required String displayName,
  });
}

/// The fields `users/{uid}` starts with, as `FIRESTORE_MODEL.md` defines them.
///
/// `createdAt` is not here: it has to be the server's clock, which only the
/// store can ask for. `lastTrainingDate` is not here either, and that is the
/// point of it: absent means "never trained", which an empty string or a null
/// would blur, and which the security rules would refuse.
Map<String, Object> newUserProfileFields({
  required String email,
  required String displayName,
}) =>
    <String, Object>{
      'displayName': displayName,
      'email': email,
      'currentProgramDay': 1,
      'totalTrainingMinutes': 0,
      'currentStreak': 0,
      'longestStreak': 0,
    };

/// The preferences a new account starts with.
///
/// Reminders start off, because notification permission is asked for only
/// when the user turns them on (`NOTIFICATIONS.md`). There is no
/// `reminderTime`: no default hour has been decided, and inventing one would
/// put a reminder where nobody chose it.
Map<String, Object> newUserPreferences() => <String, Object>{
      'reminderEnabled': false,
      'soundEnabled': true,
      'hapticEnabled': true,
    };

/// [UserProfileStore] backed by Cloud Firestore.
class FirestoreUserProfileStore implements UserProfileStore {
  /// Creates a store over [firestore].
  FirestoreUserProfileStore(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<void> createProfile({
    required String uid,
    required String email,
    required String displayName,
  }) async {
    final WriteBatch batch = _firestore.batch();
    batch.set(_firestore.doc('users/$uid'), <String, Object>{
      ...newUserProfileFields(email: email, displayName: displayName),
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      _firestore.doc('users/$uid/preferences/settings'),
      newUserPreferences(),
    );
    await batch.commit();
  }
}
