import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/models/models.dart';
import '../domain/repositories/curriculum_repository.dart';

/// Reads the curriculum out of the app bundle.
///
/// This is the only place in the training feature that touches an
/// [AssetBundle]. Everything above it works on parsed models, which is what
/// lets a later remote source replace this class without any caller noticing.
///
/// Nothing here reaches the network. The curriculum ships inside the app, so a
/// user on a train with no signal gets the same catalogue as one at a desk.
class AssetCurriculumRepository implements CurriculumRepository {
  /// Creates a repository reading from [bundle].
  ///
  /// [bundle] exists so tests can hand over their own content; production code
  /// should use the default, which is the bundle the app was built with.
  ///
  /// Flutter suggests reaching the bundle through `DefaultAssetBundle.of` so an
  /// ancestor can substitute one. That needs a `BuildContext`, and a data layer
  /// class has none by design. This parameter is the same substitution point,
  /// reached from the composition root instead of from the widget tree.
  AssetCurriculumRepository({AssetBundle? bundle})
      : _bundle = bundle ?? rootBundle;

  /// Where the curriculum files live, as declared in `pubspec.yaml`.
  static const String directory = 'assets/content/';

  final AssetBundle _bundle;

  /// One entry per file, holding the in-flight or finished read.
  ///
  /// Keyed by file name, and each name always parses to the same type, which is
  /// what makes the cast on the way out safe.
  final Map<String, Future<Object>> _cache = <String, Future<Object>>{};

  @override
  Future<TrainingProgram> loadProgram() =>
      _cached('program.json', TrainingProgram.fromJson);

  @override
  Future<ExerciseLibrary> loadExercises() =>
      _cached('exercises.json', ExerciseLibrary.fromJson);

  @override
  Future<LetterLadderLibrary> loadLetters() =>
      _cached('letters.json', LetterLadderLibrary.fromJson);

  @override
  Future<TongueTwisterLibrary> loadTongueTwisters() =>
      _cached('tongue_twisters.json', TongueTwisterLibrary.fromJson);

  @override
  Future<SpeakingChallengeLibrary> loadSpeakingChallenges() =>
      _cached('speaking_challenges.json', SpeakingChallengeLibrary.fromJson);

  /// Forgets everything read so far.
  ///
  /// Nothing in the MVP calls this: the bundle cannot change while the app is
  /// running. It exists for the moment a remote source replaces this class,
  /// when "read it again" becomes a real request.
  void clearCache() => _cache.clear();

  /// Reads [fileName] once and remembers the result.
  ///
  /// A second call gets the first call's future, so two screens asking at the
  /// same moment cause one read rather than two.
  ///
  /// A **failed** read is deliberately not remembered. The error surface offers
  /// the user a retry, and a cached failure would make that button do nothing
  /// for the rest of the session: the same broken future would be handed back
  /// every time, and the user would be told to try again by a screen that had
  /// already decided not to.
  Future<T> _cached<T extends Object>(
    String fileName,
    T Function(Map<String, dynamic>) parse,
  ) async {
    final Future<Object>? existing = _cache[fileName];
    if (existing != null) {
      return await existing as T;
    }

    final Future<T> pending = _read(fileName, parse);
    _cache[fileName] = pending;
    try {
      return await pending;
    } on Object {
      _forget(fileName);
      rethrow;
    }
  }

  /// Drops [fileName] from the cache.
  ///
  /// Its own method because `Map.remove` hands back the value it dropped, and
  /// here that value is a `Future`. Calling it inline inside an `async` method
  /// discards a future silently, which is the shape a real mistake takes, so
  /// the analyzer is right to object even though nothing is lost here: the
  /// dropped future is the one already failing its way out through `rethrow`.
  void _forget(String fileName) {
    _cache.remove(fileName);
  }

  /// Loads and parses one file.
  ///
  /// Three failures can happen here and each keeps its own shape, because the
  /// failure mapper turns them into different codes:
  ///
  /// - the asset is missing, which the bundle reports as a `FlutterError` and
  ///   the mapper turns into `content.asset_missing`;
  /// - the bytes are not JSON, or the top level is not an object;
  /// - the JSON is well formed but the content is wrong, which the model layer
  ///   rejects with its own message naming the field and the record.
  ///
  /// The middle case is the one worth handling here. `jsonDecode` reports a
  /// syntax error with an offset and no file name, and an offset alone does not
  /// say which of five files to open.
  Future<T> _read<T>(
    String fileName,
    T Function(Map<String, dynamic>) parse,
  ) async {
    final String raw = await _bundle.loadString('$directory$fileName');

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (error) {
      throw FormatException('$fileName is not valid JSON: ${error.message}');
    }

    if (decoded is! Map<String, dynamic>) {
      throw FormatException(
        'Expected $fileName to hold an object, '
        'got ${decoded == null ? 'nothing' : decoded.runtimeType}',
      );
    }

    return parse(decoded);
  }
}
