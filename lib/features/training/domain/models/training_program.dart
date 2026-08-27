import 'package:flutter/foundation.dart';

import 'content_envelope.dart';
import 'exercise.dart';
import 'exercise_library.dart';
import 'json_reader.dart';

/// One exercise's place in a day.
///
/// A day stores ids, not exercises, so the two files stay independently
/// loadable. This pairs the id with where it sits in the day, so a screen
/// showing "3 / 5" reads the position rather than recomputing it from a list
/// index and getting the off by one wrong.
@immutable
class DayExerciseRef {
  /// Creates a reference.
  const DayExerciseRef({required this.exerciseId, required this.position});

  /// Id of the exercise in `exercises.json`.
  final String exerciseId;

  /// Where this sits in the day, counting from one, as a person would say it.
  final int position;

  /// The same position counting from zero, for indexing a list.
  int get index => position - 1;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DayExerciseRef &&
          other.exerciseId == exerciseId &&
          other.position == position;

  @override
  int get hashCode => Object.hash(exerciseId, position);

  @override
  String toString() => 'DayExerciseRef($exerciseId @$position)';
}

/// What a day's exercise ids resolved to, and what did not resolve.
///
/// Missing ids are reported rather than thrown, for the same reason
/// [ExerciseLibrary] reports skipped ones: a day that lost one exercise to a
/// newer content file should still run the rest. A day that resolved to nothing
/// is the case a caller has to handle, and [isEmpty] says so directly.
@immutable
class ResolvedDay {
  /// Creates a resolution result.
  const ResolvedDay({required this.exercises, required this.missingIds});

  /// The exercises this build could resolve, in the order the day lists them.
  final List<Exercise> exercises;

  /// Ids the day names that the library does not have.
  ///
  /// Either the id is absent from `exercises.json`, which the schema test would
  /// have caught, or the exercise was skipped for naming a presentation type
  /// this build does not know. A caller can do nothing different about the two.
  final List<String> missingIds;

  /// Whether nothing at all could be resolved.
  bool get isEmpty => exercises.isEmpty;

  /// Whether every id the day names resolved.
  bool get isComplete => missingIds.isEmpty;

  /// How long the resolved exercises actually take, added up.
  Duration get actualDuration => exercises.fold(
        Duration.zero,
        (Duration total, Exercise exercise) => total + exercise.duration,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResolvedDay &&
          listEquals(other.exercises, exercises) &&
          listEquals(other.missingIds, missingIds);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(exercises), Object.hashAll(missingIds));

  @override
  String toString() => 'ResolvedDay(${exercises.length} exercises, '
      '${missingIds.length} missing)';
}

/// One day of the training program.
@immutable
class ProgramDay {
  /// Creates a day.
  const ProgramDay({
    required this.day,
    required this.title,
    required this.estimatedMinutes,
    required this.exerciseRefs,
  });

  /// Reads a day from its JSON object.
  factory ProgramDay.fromJson(Map<String, dynamic> json) {
    final int day = json.requireIntAtLeast('day', 1, ownerId: '<program day>');
    final String ownerId = 'day $day';

    final List<String> ids = json.requireStringList(
      'exerciseIds',
      ownerId: ownerId,
    );

    // The same exercise twice in one day is almost certainly a copy paste in
    // the content file, and it would show as "2 / 5" and "4 / 5" being the
    // same drill. Cheaper to reject than to explain later.
    final Set<String> seen = <String>{};
    for (final String id in ids) {
      if (!seen.add(id)) {
        throw FormatException('Exercise "$id" appears twice in $ownerId');
      }
    }

    return ProgramDay(
      day: day,
      title: json.requireString('title', ownerId: ownerId),
      estimatedMinutes: json.requireIntAtLeast(
        'estimatedMinutes',
        1,
        ownerId: ownerId,
      ),
      exerciseRefs: List<DayExerciseRef>.unmodifiable(<DayExerciseRef>[
        for (int i = 0; i < ids.length; i++)
          DayExerciseRef(exerciseId: ids[i], position: i + 1),
      ]),
    );
  }

  /// Which day of the program this is, counting from one.
  ///
  /// The same number as `currentProgramDay` on the user's profile
  /// (`FIRESTORE_MODEL.md`), which is what makes progression a comparison
  /// rather than a lookup.
  final int day;

  /// Title shown to the user.
  final String title;

  /// How long the content author expects this day to take.
  final int estimatedMinutes;

  /// The exercises, in order.
  final List<DayExerciseRef> exerciseRefs;

  /// The ids this day names, in order.
  List<String> get exerciseIds => List<String>.unmodifiable(
        exerciseRefs.map((DayExerciseRef ref) => ref.exerciseId),
      );

  /// How many exercises the day has.
  int get exerciseCount => exerciseRefs.length;

  /// [estimatedMinutes] as a [Duration].
  Duration get estimatedDuration => Duration(minutes: estimatedMinutes);

  /// Looks the day's ids up in [library].
  ///
  /// Does not throw on an id the library does not have. A day that lost one
  /// exercise should still run the rest, and the caller decides what to do
  /// about the gap from [ResolvedDay.missingIds].
  ResolvedDay resolve(ExerciseLibrary library) {
    final List<Exercise> found = <Exercise>[];
    final List<String> missing = <String>[];
    for (final DayExerciseRef ref in exerciseRefs) {
      final Exercise? exercise = library.byId(ref.exerciseId);
      if (exercise == null) {
        missing.add(ref.exerciseId);
      } else {
        found.add(exercise);
      }
    }
    return ResolvedDay(
      exercises: List<Exercise>.unmodifiable(found),
      missingIds: List<String>.unmodifiable(missing),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProgramDay &&
          other.day == day &&
          other.title == title &&
          other.estimatedMinutes == estimatedMinutes &&
          listEquals(other.exerciseRefs, exerciseRefs);

  @override
  int get hashCode => Object.hash(
        day,
        title,
        estimatedMinutes,
        Object.hashAll(exerciseRefs),
      );

  @override
  String toString() => 'ProgramDay($day, $exerciseCount exercises)';
}

/// `assets/content/program.json`, parsed.
///
/// Like [ExerciseLibrary], this takes an already decoded map. Reading the bytes
/// off the asset bundle is the repository's job (HIT-024), which keeps this
/// usable unchanged from a test, an asset, or a later remote source.
@immutable
class TrainingProgram {
  /// Creates a program.
  const TrainingProgram({
    required this.envelope,
    required this.programId,
    required this.title,
    required this.days,
  });

  /// Parses the whole file.
  factory TrainingProgram.fromJson(Map<String, dynamic> json) {
    const String fileName = 'program.json';

    final ContentEnvelope envelope = ContentEnvelope.fromJson(
      json,
      ownerId: fileName,
    );
    envelope.ensureSupported(fileName);

    final List<ProgramDay> days = <ProgramDay>[
      for (final Map<String, dynamic> item in json.requireObjectList(
        'days',
        ownerId: fileName,
      ))
        ProgramDay.fromJson(item),
    ];

    // Days are the spine of the whole app: the user's currentProgramDay is an
    // index into this list, and a gap or a repeat would make "tomorrow" mean
    // something different depending on where you asked from.
    final Set<int> numbers = <int>{};
    for (final ProgramDay day in days) {
      if (!numbers.add(day.day)) {
        throw FormatException('Day ${day.day} appears twice in $fileName');
      }
    }
    for (int expected = 1; expected <= days.length; expected++) {
      if (!numbers.contains(expected)) {
        throw FormatException(
          'Day numbers in $fileName must run from 1 with no gaps, '
          '$expected is missing',
        );
      }
    }

    return TrainingProgram(
      envelope: envelope,
      programId: json.requireString('programId', ownerId: fileName),
      title: json.requireString('title', ownerId: fileName),
      // Sorted rather than trusting file order, so `days.first` is day one no
      // matter how the file was edited.
      days: List<ProgramDay>.unmodifiable(
        days..sort((ProgramDay a, ProgramDay b) => a.day.compareTo(b.day)),
      ),
    );
  }

  /// The file's header.
  final ContentEnvelope envelope;

  /// Stable id of this program.
  final String programId;

  /// Title shown to the user.
  final String title;

  /// Every day, ordered from day one.
  final List<ProgramDay> days;

  /// How many days the program runs for.
  int get dayCount => days.length;

  /// The last day number in the program.
  int get lastDay => days.isEmpty ? 0 : days.last.day;

  /// How long the whole program is expected to take, as authored.
  Duration get totalEstimatedDuration => days.fold(
        Duration.zero,
        (Duration total, ProgramDay day) => total + day.estimatedDuration,
      );

  /// The day numbered [day], or null when the program has no such day.
  ProgramDay? dayFor(int day) {
    for (final ProgramDay candidate in days) {
      if (candidate.day == day) {
        return candidate;
      }
    }
    return null;
  }

  /// Whether [day] is open to a user whose profile says
  /// [currentProgramDay].
  ///
  /// The rule here is only "you can revisit what you have reached, and not what
  /// you have not". Anything more elaborate, streak effects, catch up days, or
  /// what happens after the last day, belongs to the training engine (HIT-025);
  /// this stays a comparison so that engine has one obvious thing to build on.
  bool isDayUnlocked(int day, {required int currentProgramDay}) =>
      dayFor(day) != null && day <= currentProgramDay;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrainingProgram &&
          other.envelope == envelope &&
          other.programId == programId &&
          other.title == title &&
          listEquals(other.days, days);

  @override
  int get hashCode =>
      Object.hash(envelope, programId, title, Object.hashAll(days));

  @override
  String toString() => 'TrainingProgram($programId, $dayCount days)';
}
