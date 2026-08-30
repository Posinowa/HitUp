/// Typed readers for the curriculum JSON.
///
/// These exist so a malformed content file fails with a sentence someone can
/// act on. A bare `json['durationSeconds'] as int` throws
/// "type 'String' is not a subtype of type 'int'", which says nothing about
/// which of thirteen exercises is wrong. Every reader here names the field
/// and the owning id instead.
///
/// The distinction they enforce: a **missing or wrong-typed required field** is
/// a content bug and throws, while an **unrecognised enum value** is a
/// forward-compatibility case and falls back to `unknown`. The first cannot be
/// rendered at all; the second costs one exercise on an older client.
library;

/// Reading helpers for a decoded JSON object.
extension JsonObjectReader on Map<String, dynamic> {
  Never _fail(String field, String ownerId, String expected, Object? actual) {
    throw FormatException(
      'Expected "$field" to be $expected in "$ownerId", '
      'got ${actual == null ? 'nothing' : '${actual.runtimeType} ($actual)'}',
    );
  }

  /// Reads a value at [field] that may be absent but not malformed.
  ///
  /// Absent is a field the schema allows to be missing; malformed is a content
  /// mistake. Returning null for both would hide the second.
  T? _optional<T>(String field, String ownerId, String expected) {
    final Object? value = this[field];
    if (value == null) {
      return null;
    }
    if (value is! T) {
      _fail(field, ownerId, expected, value);
    }
    // Dart does not promote Object? to a type parameter, so the cast is
    // written out. The line above is what makes it safe.
    return value as T;
  }

  /// Reads a list at [field] whose every item satisfies [accepts].
  ///
  /// Shared by the three list readers below rather than written out three
  /// times. Written out, one of them had already stopped returning an
  /// unmodifiable list while the other two still did.
  ///
  /// [allowEmpty] is false at every call site: a config carrying a list of ids
  /// needs at least one, and an empty list renders as an exercise that does
  /// nothing.
  List<T> _list<T>(
    String field,
    String ownerId,
    String expected, {
    required bool Function(Object? item) accepts,
    required bool allowEmpty,
    String? rejectedItemExpected,
  }) {
    final Object? value = this[field];
    if (value is! List) {
      _fail(field, ownerId, expected, value);
    }

    final List<T> items = <T>[];
    for (final Object? item in value) {
      if (!accepts(item)) {
        // A rejected item can deserve a narrower description than the list as
        // a whole. "not a list of strings" is right when the field is a
        // number; an empty string inside an otherwise valid list is a
        // different mistake and says so.
        _fail(field, ownerId, rejectedItemExpected ?? expected, item);
      }
      items.add(item as T);
    }

    if (items.isEmpty && !allowEmpty) {
      throw FormatException('Expected "$field" to be non empty in "$ownerId"');
    }
    // Content is read once and shared. A caller able to mutate this would be
    // changing what every other caller sees.
    return List<T>.unmodifiable(items);
  }

  /// Reads a non empty [String] at [field].
  ///
  /// Empty counts as missing: an exercise with an empty title renders as a
  /// blank card, which reads as a rendering bug rather than the content
  /// mistake it is.
  String requireString(String field, {required String ownerId}) {
    final Object? value = this[field];
    if (value is! String || value.isEmpty) {
      _fail(field, ownerId, 'a non empty string', value);
    }
    return value;
  }

  /// Reads a [String] at [field], or null when absent.
  String? optionalString(String field, {required String ownerId}) =>
      _optional<String>(field, ownerId, 'a string or nothing');

  /// Reads an [int] at [field].
  ///
  /// Rejects a double even when it has no fractional part. Durations and
  /// repetition counts are counts; accepting 4.0 invites 4.5 later.
  int requireInt(String field, {required String ownerId}) {
    final Object? value = this[field];
    if (value is! int) {
      _fail(field, ownerId, 'an integer', value);
    }
    return value;
  }

  /// Reads an [int] at [field] and rejects anything below [min].
  int requireIntAtLeast(String field, int min, {required String ownerId}) {
    final int value = requireInt(field, ownerId: ownerId);
    if (value < min) {
      throw FormatException(
        'Expected "$field" to be at least $min in "$ownerId", got $value',
      );
    }
    return value;
  }

  /// Reads a nested object at [field].
  Map<String, dynamic> requireObject(String field, {required String ownerId}) {
    final Object? value = this[field];
    if (value is! Map<String, dynamic>) {
      _fail(field, ownerId, 'an object', value);
    }
    return value;
  }

  /// Reads a nested object at [field], or null when absent.
  Map<String, dynamic>? optionalObject(
    String field, {
    required String ownerId,
  }) =>
      _optional<Map<String, dynamic>>(field, ownerId, 'an object or nothing');

  /// Reads a list of non empty [String] at [field].
  List<String> requireStringList(
    String field, {
    required String ownerId,
    bool allowEmpty = false,
  }) =>
      _list<String>(
        field,
        ownerId,
        'a list of strings',
        accepts: (Object? item) => item is String && item.isNotEmpty,
        rejectedItemExpected: 'a list of non empty strings',
        allowEmpty: allowEmpty,
      );

  /// Reads a list of [int] at [field].
  List<int> requireIntList(
    String field, {
    required String ownerId,
    bool allowEmpty = false,
  }) =>
      _list<int>(
        field,
        ownerId,
        'a list of integers',
        accepts: (Object? item) => item is int,
        allowEmpty: allowEmpty,
      );

  /// Reads a list of nested objects at [field].
  List<Map<String, dynamic>> requireObjectList(
    String field, {
    required String ownerId,
    bool allowEmpty = false,
  }) =>
      _list<Map<String, dynamic>>(
        field,
        ownerId,
        'a list of objects',
        accepts: (Object? item) => item is Map<String, dynamic>,
        allowEmpty: allowEmpty,
      );
}
