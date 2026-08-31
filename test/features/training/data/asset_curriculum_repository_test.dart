import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/core/errors/failure.dart';
import 'package:hitup/core/errors/failure_code.dart';
import 'package:hitup/core/errors/failure_mapper.dart';
import 'package:hitup/features/training/data/asset_curriculum_repository.dart';
import 'package:hitup/features/training/domain/models/models.dart';
import 'package:hitup/features/training/domain/repositories/curriculum_repository.dart';

/// A bundle that serves what the test hands it, and counts the reads.
///
/// Extends [AssetBundle] rather than one of the caching subclasses on purpose:
/// a bundle that caches would hide whether the repository caches, which is half
/// of what these tests are for.
class _FakeBundle extends AssetBundle {
  _FakeBundle(this.files);

  /// Asset key to file contents. A key that is absent behaves like a missing
  /// asset.
  final Map<String, String> files;

  /// How many times each key was actually read off the bundle.
  final Map<String, int> reads = <String, int>{};

  /// Keys that should fail once before starting to work.
  final Set<String> failOnce = <String>{};

  @override
  Future<ByteData> load(String key) async {
    reads[key] = (reads[key] ?? 0) + 1;

    if (failOnce.remove(key)) {
      throw FlutterError('Unable to load asset: $key');
    }

    final String? content = files[key];
    if (content == null) {
      // The message the real bundle uses. The failure mapper keys off it.
      throw FlutterError('Unable to load asset: $key');
    }
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(content)));
  }
}

void main() {
  String assetKey(String name) => '${AssetCurriculumRepository.directory}$name';

  /// The five files as they actually ship, read off disk.
  ///
  /// Reading the shipped content rather than a fixture is the same choice the
  /// model tests make: a fixture drifts, and the case worth catching is the one
  /// where content changes and the code stops matching it.
  Map<String, String> shippedFiles() {
    final Map<String, String> out = <String, String>{};
    for (final String name in <String>[
      'program.json',
      'exercises.json',
      'letters.json',
      'tongue_twisters.json',
      'speaking_challenges.json',
    ]) {
      final File file = File('assets/content/$name');
      expect(file.existsSync(), isTrue, reason: '$name must ship');
      out[assetKey(name)] = file.readAsStringSync();
    }
    return out;
  }

  group('reading the shipped curriculum', () {
    late _FakeBundle bundle;
    late CurriculumRepository repository;

    setUp(() {
      bundle = _FakeBundle(shippedFiles());
      repository = AssetCurriculumRepository(bundle: bundle);
    });

    test('every file parses into its library', () async {
      final TrainingProgram program = await repository.loadProgram();
      final ExerciseLibrary exercises = await repository.loadExercises();
      final LetterLadderLibrary letters = await repository.loadLetters();
      final TongueTwisterLibrary twisters =
          await repository.loadTongueTwisters();
      final SpeakingChallengeLibrary challenges =
          await repository.loadSpeakingChallenges();

      expect(program.days, isNotEmpty);
      expect(exercises.exercises, isNotEmpty);
      expect(letters.ladders, isNotEmpty);
      expect(twisters.tongueTwisters, isNotEmpty);
      expect(challenges.challenges, isNotEmpty);
    });

    test('a day resolves against the library the repository handed back',
        () async {
      // This is the whole point of returning the library rather than a bare
      // list: `resolve` needs the library, and a caller handed a list could not
      // rebuild one.
      final TrainingProgram program = await repository.loadProgram();
      final ExerciseLibrary exercises = await repository.loadExercises();

      for (final ProgramDay day in program.days) {
        final ResolvedDay resolved = day.resolve(exercises);
        expect(
          resolved.missingIds,
          isEmpty,
          reason: 'day ${day.day} names ${resolved.missingIds} '
              'and exercises.json does not have them',
        );
        expect(resolved.exercises, hasLength(day.exerciseCount));
      }
    });

    test('the envelope survives the trip', () async {
      // A bare list would lose this. Knowing which content version is loaded is
      // what lets a diagnostic say the app is older than its content rather
      // than just that a day is short.
      final ExerciseLibrary exercises = await repository.loadExercises();

      expect(exercises.envelope.schemaVersion, isNotEmpty);
      expect(exercises.envelope.contentVersion, isNotEmpty);
      expect(exercises.envelope.isSupported, isTrue);
    });

    test('it reads only the files it was asked for', () async {
      await repository.loadLetters();

      expect(bundle.reads[assetKey('letters.json')], 1);
      expect(bundle.reads[assetKey('exercises.json')], isNull);
      expect(bundle.reads[assetKey('program.json')], isNull);
    });
  });

  group('caching', () {
    late _FakeBundle bundle;
    late AssetCurriculumRepository repository;

    setUp(() {
      bundle = _FakeBundle(shippedFiles());
      repository = AssetCurriculumRepository(bundle: bundle);
    });

    test('asking twice reads once and gives the same object', () async {
      final ExerciseLibrary first = await repository.loadExercises();
      final ExerciseLibrary second = await repository.loadExercises();

      expect(bundle.reads[assetKey('exercises.json')], 1);
      expect(identical(first, second), isTrue);
    });

    test('two callers at the same moment cause one read', () async {
      // Without a shared future, two screens opening together would each start
      // their own read of the same file.
      final List<ExerciseLibrary> both = await Future.wait<ExerciseLibrary>(
        <Future<ExerciseLibrary>>[
          repository.loadExercises(),
          repository.loadExercises(),
        ],
      );

      expect(bundle.reads[assetKey('exercises.json')], 1);
      expect(identical(both.first, both.last), isTrue);
    });

    test('clearing makes the next call read again', () async {
      await repository.loadExercises();
      repository.clearCache();
      await repository.loadExercises();

      expect(bundle.reads[assetKey('exercises.json')], 2);
    });

    test('a failed read is not remembered, so a retry can succeed', () async {
      // The error surface offers the user a retry. If the failure were cached,
      // that button would hand back the same broken future for the rest of the
      // session and do nothing.
      bundle.failOnce.add(assetKey('exercises.json'));

      await expectLater(
          repository.loadExercises(), throwsA(isA<FlutterError>()));

      final ExerciseLibrary retried = await repository.loadExercises();
      expect(retried.exercises, isNotEmpty);
      expect(bundle.reads[assetKey('exercises.json')], 2);
    });

    test('one file failing does not poison the others', () async {
      bundle.failOnce.add(assetKey('letters.json'));

      await expectLater(repository.loadLetters(), throwsA(isA<FlutterError>()));

      final ExerciseLibrary exercises = await repository.loadExercises();
      expect(exercises.exercises, isNotEmpty);
    });
  });

  group('when the content is wrong', () {
    Future<Object> errorFrom(Map<String, String> files, String name) async {
      final AssetCurriculumRepository repository = AssetCurriculumRepository(
        bundle: _FakeBundle(files),
      );
      try {
        switch (name) {
          case 'letters.json':
            await repository.loadLetters();
          case 'exercises.json':
            await repository.loadExercises();
          default:
            await repository.loadProgram();
        }
      } on Object catch (error) {
        return error;
      }
      fail('$name should not have parsed');
    }

    test('a missing file becomes a content asset failure', () async {
      final Object error = await errorFrom(<String, String>{}, 'letters.json');
      final Failure failure = mapErrorToFailure(error);

      expect(failure, isA<ContentFailure>());
      expect(failure.code, FailureCode.contentAssetMissing);
      expect(failure.isRetryable, isFalse);
    });

    test('unparseable bytes name the file, not just an offset', () async {
      // jsonDecode reports a syntax error with a character offset and nothing
      // else. An offset alone does not say which of five files to open.
      final Object error = await errorFrom(
        <String, String>{assetKey('letters.json'): '{ "letters": ['},
        'letters.json',
      );

      expect(error, isA<FormatException>());
      expect((error as FormatException).message, contains('letters.json'));

      final Failure failure = mapErrorToFailure(error);
      expect(failure.code, FailureCode.contentMalformed);
    });

    test('a top level that is not an object names the file too', () async {
      final Object error = await errorFrom(
        <String, String>{assetKey('letters.json'): '[]'},
        'letters.json',
      );

      expect(error, isA<FormatException>());
      expect(
        (error as FormatException).message,
        allOf(contains('letters.json'), contains('object')),
      );
    });

    test('valid JSON with wrong content still fails, with the model message',
        () async {
      // The repository does not re-check what the model layer already checks.
      // This proves the model's message survives the trip rather than being
      // replaced by a generic one.
      final Object error = await errorFrom(
        <String, String>{
          assetKey('letters.json'): jsonEncode(<String, Object>{
            'schemaVersion': '1.0.0',
            'contentVersion': '0.1.0',
            'status': 'placeholder',
            'locale': 'tr-TR',
            'letters': <Object>[
              <String, Object>{'key': 'r'},
            ],
          }),
        },
        'letters.json',
      );

      expect(error, isA<FormatException>());
      expect((error as FormatException).message, contains('letter'));
      expect(mapErrorToFailure(error).code, FailureCode.contentMalformed);
    });

    test('an unsupported schema version fails on the header', () async {
      final Object error = await errorFrom(
        <String, String>{
          assetKey('letters.json'): jsonEncode(<String, Object>{
            'schemaVersion': '9.0.0',
            'contentVersion': '0.1.0',
            'status': 'placeholder',
            'locale': 'tr-TR',
            'letters': <Object>[],
          }),
        },
        'letters.json',
      );

      expect(error, isA<FormatException>());
      expect((error as FormatException).message, contains('letters.json'));
    });
  });

  group('the production constructor', () {
    test('defaults to the bundle the app was built with', () {
      // Only the tests pass a bundle. If the default ever stopped resolving,
      // nothing else here would notice.
      expect(AssetCurriculumRepository(), isA<CurriculumRepository>());
    });

    test('reads the real shipped curriculum through that default', () async {
      // Every other test in this file hands over a fake bundle, so none of them
      // touches the path production actually takes. If the default bundle or
      // the asset directory stopped lining up with what ships, all of them
      // would still pass and the app would find nothing at runtime.
      TestWidgetsFlutterBinding.ensureInitialized();
      final CurriculumRepository repository = AssetCurriculumRepository();

      final TrainingProgram program = await repository.loadProgram();
      final ExerciseLibrary exercises = await repository.loadExercises();

      expect(program.days, isNotEmpty);
      expect(exercises.exercises, isNotEmpty);

      // The cross file reference, read the way the app will read it rather
      // than from two files a test opened itself.
      for (final ProgramDay day in program.days) {
        expect(
          day.resolve(exercises).missingIds,
          isEmpty,
          reason: 'day ${day.day} names an exercise the bundle does not have',
        );
      }
    });

    test('the asset directory matches what pubspec declares', () {
      // The path is written once here and once in pubspec.yaml. They have to
      // agree, and the failure if they do not is a missing asset at runtime on
      // a screen that has no idea why.
      final File pubspec = File('pubspec.yaml');
      expect(
        pubspec.readAsStringSync(),
        contains('- ${AssetCurriculumRepository.directory}'),
      );
    });
  });
}
