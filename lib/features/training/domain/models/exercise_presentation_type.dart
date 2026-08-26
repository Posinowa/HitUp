/// How an exercise is presented to the user.
///
/// Stored in the content files as a string, not an integer, so an unknown value
/// stays readable in a log or a diff. See `docs/architecture/CONTENT_SCHEMA.md`.
///
/// Screens select their renderer from this, never from an exercise id. An id is
/// content; a presentation type is a contract. Branching on ids is how a screen
/// ends up with a special case per exercise, which is the thing HIT-022 exists
/// to prevent.
enum ExercisePresentationType {
  /// Plain instructional card. No type specific config.
  text('text'),

  /// Countdown only. No type specific config.
  timer('timer'),

  /// Audio playback, configured by the exercise's media reference.
  audio('audio'),

  /// Guided breathing, configured by [BreathingConfig].
  breathing('breathing'),

  /// Rive animation, configured by the exercise's media reference.
  rive('rive'),

  /// Mouth, lip, tongue or jaw drill driven by a Rive animation.
  articulation('articulation'),

  /// Turkish letter ladder, configured by [LetterConfig].
  letter('letter'),

  /// Tongue twister drill, configured by [TongueTwisterConfig].
  tongueTwister('tongueTwister'),

  /// Stress placement drill, configured by [EmphasisConfig].
  emphasis('emphasis'),

  /// Pitch contour drill, configured by [IntonationConfig].
  intonation('intonation'),

  /// Pause placement drill, configured by [PauseConfig].
  pause('pause'),

  /// Reading against a words-per-minute target, configured by
  /// [TimedReadingConfig].
  timedReading('timedReading'),

  /// Open speaking task, configured by [SpeakingChallengeConfig].
  speakingChallenge('speakingChallenge'),

  /// A type this build of the app does not recognise.
  ///
  /// Never present in a content file. It is what parsing produces when a newer
  /// content file names a type this client has never heard of, so an old build
  /// can skip one exercise instead of failing to open the day. Callers are
  /// expected to filter these out; see `CONTENT_SCHEMA.md`, "Extensibility
  /// rule".
  unknown('unknown');

  const ExercisePresentationType(this.wireName);

  /// The exact string used in the content files.
  ///
  /// Kept separate from the Dart name because the two are allowed to diverge:
  /// the wire name is content and can never change once it ships, while the
  /// Dart name is ours to rename.
  final String wireName;

  /// Resolves [value] to a type, falling back to [unknown].
  ///
  /// Deliberately total. Throwing here would turn one unrecognised exercise in
  /// a future content file into a crash on every older client that reads it.
  static ExercisePresentationType fromWireName(String? value) {
    for (final ExercisePresentationType type in values) {
      if (type.wireName == value) {
        return type;
      }
    }
    return unknown;
  }

  /// Whether this type is one this build can actually render.
  bool get isRenderable => this != unknown;
}
