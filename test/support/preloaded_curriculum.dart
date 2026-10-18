import 'package:hitup/features/training/data/asset_curriculum_repository.dart';
import 'package:hitup/features/training/domain/models/models.dart';
import 'package:hitup/features/training/domain/repositories/curriculum_repository.dart';

/// The bundled curriculum, read once before the tests run.
///
/// A widget test runs on a clock of its own, and reading an asset from inside
/// it waits on input that clock never lets through. Read in `setUpAll`, the
/// content is in hand, and the screens get it at once.
class PreloadedCurriculum implements CurriculumRepository {
  PreloadedCurriculum._(
    this._program,
    this._exercises,
    this._letters,
    this._twisters,
    this._challenges,
  );

  /// Reads everything the app bundles. Call from `setUpAll`.
  static Future<PreloadedCurriculum> load() async {
    final AssetCurriculumRepository assets = AssetCurriculumRepository();
    return PreloadedCurriculum._(
      await assets.loadProgram(),
      await assets.loadExercises(),
      await assets.loadLetters(),
      await assets.loadTongueTwisters(),
      await assets.loadSpeakingChallenges(),
    );
  }

  final TrainingProgram _program;
  final ExerciseLibrary _exercises;
  final LetterLadderLibrary _letters;
  final TongueTwisterLibrary _twisters;
  final SpeakingChallengeLibrary _challenges;

  /// The programme, for a test to compare with.
  TrainingProgram get program => _program;

  /// The exercises, for a test to compare with.
  ExerciseLibrary get exercises => _exercises;

  @override
  Future<TrainingProgram> loadProgram() async => _program;

  @override
  Future<ExerciseLibrary> loadExercises() async => _exercises;

  @override
  Future<LetterLadderLibrary> loadLetters() async => _letters;

  @override
  Future<TongueTwisterLibrary> loadTongueTwisters() async => _twisters;

  @override
  Future<SpeakingChallengeLibrary> loadSpeakingChallenges() async =>
      _challenges;
}
