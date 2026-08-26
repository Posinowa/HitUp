/// Typed readers for the curriculum JSON.
///
/// These exist so a malformed content file fails with a sentence someone can
/// act on. A bare `json['durationSeconds'] as int` throws
/// "type 'String' is not a subtype of type 'int'", which says nothing about
/// which of the thirteen exercises is wrong. Every reader here names the field
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

  /// Reads a non empty [String] at [field].
  String requireString(String field, {required String ownerId}) {
    final Object? value = this[field];
    if (value is! String || value.isEmpty) {
      _fail(field, ownerId, 'a non empty string', value);
    }
    return value;
  }

  /// Reads a [String] at [field], or null when absent.
  ///
  /// A present but wrong-typed value still throws: absent and malformed are
  /// different problems and should not be silently merged.
  String? optionalString(String field, {required String ownerId}) {
    final Object? value = this[field];
    if (value == null) {
      return null;
    }
    if (value is! String) {
      _fail(field, ownerId, 'a string or nothing', value);
    }
    return value;
  }

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
  }) {
    final Object? value = this[field];
    if (value == null) {
      return null;
    }
    if (value is! Map<String, dynamic>) {
      _fail(field, ownerId, 'an object or nothing', value);
    }
    return value;
  }

  /// Reads a list of [String] at [field].
  ///
  /// [allowEmpty] defaults to false: a config that carries a list of ids needs
  /// at least one, and an empty list is a content mistake that would otherwise
  /// render as an exercise that does nothing.
  List<String> requireStringList(
    String field, {
    required String ownerId,
    bool allowEmpty = false,
  }) {
    final Object? value = this[field];
    if (value is! List) {
      _fail(field, ownerId, 'a list of strings', value);
    }
    final List<String> items = <String>[];
    for (final Object? item in value) {
      if (item is! String || item.isEmpty) {
        _fail(field, ownerId, 'a list of non empty strings', item);
      }
      items.add(item);
    }
    if (items.isEmpty && !allowEmpty) {
      throw FormatException('Expected "$field" to be non empty in "$ownerId"');
    }
    return List<String>.unmodifiable(items);
  }

  /// Reads a list of [int] at [field].
  List<int> requireIntList(
    String field, {
    required String ownerId,
    bool allowEmpty = false,
  }) {
    final Object? value = this[field];
    if (value is! List) {
      _fail(field, ownerId, 'a list of integers', value);
    }
    final List<int> items = <int>[];
    for (final Object? item in value) {
      if (item is! int) {
        _fail(field, ownerId, 'a list of integers', item);
      }
      items.add(item);
    }
    if (items.isEmpty && !allowEmpty) {
      throw FormatException('Expected "$field" to be non empty in "$ownerId"');
    }
    return List<int>.unmodifiable(items);
  }

  /// Reads a list of nested objects at [field].
  List<Map<String, dynamic>> requireObjectList(
    String field, {
    required String ownerId,
    bool allowEmpty = false,
  }) {
    final Object? value = this[field];
    if (value is! List) {
      _fail(field, ownerId, 'a list of objects', value);
    }
    final List<Map<String, dynamic>> items = <Map<String, dynamic>>[];
    for (final Object? item in value) {
      if (item is! Map<String, dynamic>) {
        _fail(field, ownerId, 'a list of objects', item);
      }
      items.add(item);
    }
    if (items.isEmpty && !allowEmpty) {
      throw FormatException('Expected "$field" to be non empty in "$ownerId"');
    }
    return items;
  }
}
