import 'json_reader.dart';

/// What kind of asset a [MediaReference] points at.
enum MediaKind {
  /// A Rive animation.
  rive('rive'),

  /// An audio clip.
  audio('audio'),

  /// A still image.
  image('image'),

  /// A kind this build does not recognise.
  ///
  /// Same reasoning as [ExercisePresentationType.unknown]: a newer content file
  /// naming a kind this client has never heard of should cost one exercise, not
  /// the whole day.
  unknown('unknown');

  const MediaKind(this.wireName);

  /// The exact string used in the content files.
  final String wireName;

  /// Resolves [value] to a kind, falling back to [unknown].
  static MediaKind fromWireName(String? value) {
    for (final MediaKind kind in values) {
      if (kind.wireName == value) {
        return kind;
      }
    }
    return unknown;
  }
}

/// A pointer to a media asset, by key rather than by path.
///
/// Content files never carry a path or a file extension. They carry a [kind]
/// and a bare [key], and one resolver turns that into a real location. For MVP
/// that is a bundled asset; HIT-013 may later add a remote template for the same
/// key. That indirection is the point: changing how media is delivered must not
/// touch a single curriculum file or screen.
class MediaReference {
  /// Creates a media reference.
  const MediaReference({
    required this.kind,
    required this.key,
    this.stateMachine,
  });

  /// Reads a reference from its JSON object.
  ///
  /// Throws a [FormatException] naming [ownerId] when the object is malformed,
  /// so a content mistake points at the exercise that carries it rather than at
  /// a line number in a parser.
  factory MediaReference.fromJson(
    Map<String, dynamic> json, {
    required String ownerId,
  }) {
    final String key = json.requireString('key', ownerId: ownerId);

    // A path or an extension here means the content file has started deciding
    // where assets live, which is exactly what the key indirection exists to
    // prevent. Better to reject it at parse time than to discover it when the
    // remote template lands and half the keys no longer resolve.
    if (key.contains('/') || key.contains('.')) {
      throw FormatException(
        'media.key must be a bare asset key with no folder and no extension, '
        'got "$key" in "$ownerId"',
      );
    }

    return MediaReference(
      // Through the reader, so a wrong type names the field and the owner
      // instead of surfacing a Dart cast error that names neither.
      kind: MediaKind.fromWireName(
        json.optionalString('kind', ownerId: ownerId),
      ),
      key: key,
      stateMachine: json.optionalString('stateMachine', ownerId: ownerId),
    );
  }

  /// The kind of asset.
  final MediaKind kind;

  /// The bare asset key, with no folder and no extension.
  final String key;

  /// For [MediaKind.rive] only, the state machine to drive.
  final String? stateMachine;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaReference &&
          other.kind == kind &&
          other.key == key &&
          other.stateMachine == stateMachine;

  @override
  int get hashCode => Object.hash(kind, key, stateMachine);

  @override
  String toString() => 'MediaReference(${kind.wireName}, $key'
      '${stateMachine == null ? '' : ', $stateMachine'})';
}
