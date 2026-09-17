import 'package:flutter/foundation.dart';

/// The signed-in account, as the rest of the app sees it.
///
/// A plain value with no reference to Firebase, so nothing above the data
/// layer ever holds a Firebase `User`. That keeps a later provider, Google or
/// Apple, from changing a single caller: it produces the same three fields.
@immutable
class AuthUser {
  /// Creates a user.
  const AuthUser({required this.uid, this.email, this.displayName});

  /// Stable account id. Also the document id under `users/`.
  final String uid;

  /// Email on the account. Null only for providers that do not supply one.
  final String? email;

  /// Name on the account, or null when none was given.
  final String? displayName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthUser &&
          other.uid == uid &&
          other.email == email &&
          other.displayName == displayName;

  @override
  int get hashCode => Object.hash(uid, email, displayName);

  /// Names the account by uid only.
  ///
  /// A user object ends up in logs and crash reports through string
  /// interpolation more easily than anyone intends, and the uid is enough to
  /// find the account. The email and the name are personal data and stay out.
  @override
  String toString() => 'AuthUser($uid)';
}
