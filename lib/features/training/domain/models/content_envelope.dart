import 'package:flutter/foundation.dart';

import 'json_reader.dart';

/// Whether the content in a file has been approved for release.
enum ContentStatus {
  /// Structure is final, wording is not. Development builds only.
  placeholder('placeholder'),

  /// Signed off by the content owner (HIT-080).
  approved('approved'),

  /// A status this build does not recognise.
  unknown('unknown');

  const ContentStatus(this.wireName);

  /// The exact string used in the content files.
  final String wireName;

  /// Resolves [value] to a status, falling back to [unknown].
  static ContentStatus fromWireName(String? value) {
    for (final ContentStatus status in values) {
      if (status.wireName == value) {
        return status;
      }
    }
    return unknown;
  }
}

/// The header every curriculum file carries.
///
/// Two version fields, on purpose. [schemaVersion] describes the *structure*
/// and [contentVersion] the *wording*, and wording changes far more often. Kept
/// as one field, a typo fix would look like a breaking format change.
@immutable
class ContentEnvelope {
  /// Creates an envelope.
  const ContentEnvelope({
    required this.schemaVersion,
    required this.contentVersion,
    required this.status,
    required this.locale,
  });

  /// Reads the envelope from the root of a content file.
  ///
  /// [ownerId] names the file, so a failure says which one is malformed.
  factory ContentEnvelope.fromJson(
    Map<String, dynamic> json, {
    required String ownerId,
  }) =>
      ContentEnvelope(
        schemaVersion: json.requireString('schemaVersion', ownerId: ownerId),
        contentVersion: json.requireString('contentVersion', ownerId: ownerId),
        // Through the reader like its siblings, not a bare cast. The three
        // outcomes have to stay distinct: absent is allowed and means unknown,
        // an unrecognised string is forward compatibility and also means
        // unknown, and a wrong *type* is a content bug that should name the
        // field. A cast collapses the third into a Dart type error that names
        // nothing, and it does so while reading the header, before
        // ensureSupported can produce a message anyone can act on.
        status: ContentStatus.fromWireName(
          json.optionalString('status', ownerId: ownerId),
        ),
        locale: json.requireString('locale', ownerId: ownerId),
      );

  /// The structural schema major version this build understands.
  static const int supportedSchemaMajor = 1;

  /// Semver for the structure of the file.
  final String schemaVersion;

  /// Semver for the wording inside the file.
  final String contentVersion;

  /// Whether the wording is approved or still a placeholder.
  final ContentStatus status;

  /// BCP 47 locale tag. MVP is `tr-TR`.
  final String locale;

  /// The leading number of [schemaVersion], or null when it is not semver.
  int? get schemaMajor {
    final String head = schemaVersion.split('.').first;
    return int.tryParse(head);
  }

  /// Whether this build can parse a file carrying this envelope.
  ///
  /// A major bump means fields were renamed or removed, so an older parser
  /// reading it would produce quietly wrong models rather than fail. A minor or
  /// patch bump is additive and safe to ignore.
  bool get isSupported => schemaMajor == supportedSchemaMajor;

  /// Throws when this build cannot parse the file.
  ///
  /// Called before any records are read, so an unsupported file fails on its
  /// header instead of halfway through with a confusing field error.
  void ensureSupported(String fileName) {
    if (isSupported) {
      return;
    }
    throw FormatException(
      'Unsupported schemaVersion "$schemaVersion" in $fileName. '
      'This build understands major version $supportedSchemaMajor.',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContentEnvelope &&
          other.schemaVersion == schemaVersion &&
          other.contentVersion == contentVersion &&
          other.status == status &&
          other.locale == locale;

  @override
  int get hashCode =>
      Object.hash(schemaVersion, contentVersion, status, locale);

  @override
  String toString() =>
      'ContentEnvelope(schema $schemaVersion, content $contentVersion, '
      '${status.wireName}, $locale)';
}
