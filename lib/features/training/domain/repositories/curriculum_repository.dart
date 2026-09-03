import '../models/models.dart';

/// Reads the bundled curriculum.
///
/// The model layer parses a decoded map and never touches an asset bundle; this
/// is the seam where bytes become models. Keeping the interface here and the
/// bundle reader in `data/` means a later remote or cached source can be
/// swapped in without any caller changing, which is the migration path HIT-024
/// asks to plan for.
///
/// Every method returns the library type rather than a bare list. The library
/// carries two things a list cannot:
///
/// - the file's [ContentEnvelope], so a caller can tell which content version
///   it is looking at;
/// - for exercises, `skippedIds`, the exercises this build could not render.
///   Losing those would hide the reason a day is running short, which is the
///   one thing the forward-compatibility rule exists to make visible.
///
/// `ProgramDay.resolve` takes an [ExerciseLibrary] for the same reason, so a
/// list here would only force every caller to rebuild what was thrown away.
///
/// Lookups are not repeated on this interface. `byId`, `byKey` and `byCategory`
/// live on the library types, next to the data they search, and an
/// implementation is free to cache so asking twice costs one read.
abstract interface class CurriculumRepository {
  /// The day by day plan.
  Future<TrainingProgram> loadProgram();

  /// Every exercise this build can present, plus the ids it had to skip.
  Future<ExerciseLibrary> loadExercises();

  /// The Turkish letter ladders.
  Future<LetterLadderLibrary> loadLetters();

  /// The tongue twister library.
  Future<TongueTwisterLibrary> loadTongueTwisters();

  /// The open speaking tasks.
  Future<SpeakingChallengeLibrary> loadSpeakingChallenges();
}
