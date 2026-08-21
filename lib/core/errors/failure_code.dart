/// Stable identifiers for everything that can go wrong.
///
/// A code is the contract between the layer that detects a problem and the
/// layer that tells the user about it. Codes are never shown to users and
/// never change once shipped, because logs, analytics and the message table
/// all key off them.
///
/// User facing copy lives in `failure_messages.dart`. Nothing in this file or
/// anywhere else under `errors/` holds a sentence a user will read.
abstract final class FailureCode {
  const FailureCode._();

  // Authentication
  static const authInvalidCredentials = 'auth.invalid_credentials';
  static const authUserDisabled = 'auth.user_disabled';
  static const authEmailInUse = 'auth.email_in_use';
  static const authInvalidEmail = 'auth.invalid_email';
  static const authWeakPassword = 'auth.weak_password';
  static const authTooManyRequests = 'auth.too_many_requests';
  static const authRequiresRecentLogin = 'auth.requires_recent_login';
  static const authUnknown = 'auth.unknown';

  // Connectivity
  static const networkOffline = 'network.offline';
  static const networkTimeout = 'network.timeout';
  static const networkUnavailable = 'network.unavailable';

  // Authorisation
  static const permissionDenied = 'permission.denied';

  // Local content and media
  static const contentAssetMissing = 'content.asset_missing';
  static const contentMalformed = 'content.malformed';
  static const contentMediaUnavailable = 'content.media_unavailable';

  // Stored data
  static const dataNotFound = 'data.not_found';
  static const dataConflict = 'data.conflict';
  static const dataUnknown = 'data.unknown';

  // Anything unrecognised
  static const unknown = 'unknown';

  /// Every code above. The message table test uses this to prove no code can
  /// ship without copy behind it.
  static const all = <String>[
    authInvalidCredentials,
    authUserDisabled,
    authEmailInUse,
    authInvalidEmail,
    authWeakPassword,
    authTooManyRequests,
    authRequiresRecentLogin,
    authUnknown,
    networkOffline,
    networkTimeout,
    networkUnavailable,
    permissionDenied,
    contentAssetMissing,
    contentMalformed,
    contentMediaUnavailable,
    dataNotFound,
    dataConflict,
    dataUnknown,
    unknown,
  ];
}
