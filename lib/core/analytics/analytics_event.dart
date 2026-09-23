import 'package:flutter/foundation.dart';

/// One analytics event, named and parameterised the way `ANALYTICS.md` says.
///
/// Events are built through the named constructors below rather than from a
/// string and a map. Two reasons, and both are the point of this class:
///
/// - **A name is written once.** `training_completed` spelled two ways is two
///   events in the console and a number nobody trusts.
/// - **Personal data cannot get in.** Every parameter here is an id, a count
///   or a duration. There is no free text parameter to pass an email, a
///   display name, or the words of an exercise into, so the rule is enforced
///   by the type rather than by remembering it at each call site.
///
/// Firebase's limits matter here because it drops what it does not accept and
/// reports nothing: a name is at most 40 characters and a string value at most
/// 100. The names are literals in this file and the test asserts the limits
/// over all of them; the values come from callers, so they are checked here.
@immutable
class AnalyticsEvent {
  const AnalyticsEvent._(this.name, this.parameters);

  /// Builds an event, checking the values that come from a caller.
  ///
  /// Only the values are checked here. The names below are written in this
  /// file and never come from outside, so the limits they have to respect are
  /// asserted once over the whole taxonomy in the test rather than re-checked
  /// at every call: a check no input can reach is code nothing can exercise.
  ///
  /// Throws [ArgumentError] for a string value that is not an id, which is
  /// what keeps personal data out of the payload.
  factory AnalyticsEvent._event(
    String name,
    Map<String, Object> parameters,
  ) {
    for (final MapEntry<String, Object> entry in parameters.entries) {
      final Object value = entry.value;
      if (value is String) {
        _requireId(value, entry.key);
      }
    }
    return AnalyticsEvent._(name, Map<String, Object>.unmodifiable(parameters));
  }

  /// The most parameters one event may carry, as Firebase counts them.
  static const int maxParameters = 25;

  /// The longest a name may be.
  static const int maxNameLength = 40;

  /// The longest a string value may be.
  static const int maxValueLength = 100;

  /// A new account was created. Firebase's standard `sign_up`.
  factory AnalyticsEvent.signUp({required String method}) =>
      AnalyticsEvent._event('sign_up', <String, Object>{'method': method});

  /// A returning user signed in. Firebase's standard `login`.
  factory AnalyticsEvent.login({required String method}) =>
      AnalyticsEvent._event('login', <String, Object>{'method': method});

  /// Onboarding was finished.
  factory AnalyticsEvent.onboardingCompleted() =>
      AnalyticsEvent._event('onboarding_completed', const <String, Object>{});

  /// A training day was started.
  factory AnalyticsEvent.trainingStarted({
    required int programDay,
    required int exerciseCount,
  }) =>
      AnalyticsEvent._event('training_started', <String, Object>{
        'program_day': programDay,
        'exercise_count': exerciseCount,
      });

  /// A training day was finished.
  factory AnalyticsEvent.trainingCompleted({
    required int programDay,
    required int exerciseCount,
    required int durationMinutes,
  }) =>
      AnalyticsEvent._event('training_completed', <String, Object>{
        'program_day': programDay,
        'exercise_count': exerciseCount,
        'duration_minutes': durationMinutes,
      });

  /// An exercise was started.
  factory AnalyticsEvent.exerciseStarted({
    required String exerciseId,
    required String presentationType,
    required int programDay,
  }) =>
      AnalyticsEvent._event('exercise_started', <String, Object>{
        'exercise_id': exerciseId,
        'presentation_type': presentationType,
        'program_day': programDay,
      });

  /// An exercise was finished.
  factory AnalyticsEvent.exerciseCompleted({
    required String exerciseId,
    required String presentationType,
    required int programDay,
  }) =>
      AnalyticsEvent._event('exercise_completed', <String, Object>{
        'exercise_id': exerciseId,
        'presentation_type': presentationType,
        'program_day': programDay,
      });

  /// A tongue twister drill was finished.
  factory AnalyticsEvent.tongueTwisterCompleted({
    required String tongueTwisterId,
    required int repetitions,
  }) =>
      AnalyticsEvent._event('tongue_twister_completed', <String, Object>{
        'tongue_twister_id': tongueTwisterId,
        'repetitions': repetitions,
      });

  /// A speaking challenge was started.
  factory AnalyticsEvent.speakingChallengeStarted({
    required String speakingChallengeId,
  }) =>
      AnalyticsEvent._event('speaking_challenge_started', <String, Object>{
        'speaking_challenge_id': speakingChallengeId,
      });

  /// A speaking challenge was finished.
  factory AnalyticsEvent.speakingChallengeCompleted({
    required String speakingChallengeId,
    required int durationSeconds,
  }) =>
      AnalyticsEvent._event('speaking_challenge_completed', <String, Object>{
        'speaking_challenge_id': speakingChallengeId,
        'duration_seconds': durationSeconds,
      });

  /// The daily reminder was turned on, for the hour it was set to.
  ///
  /// The hour only, not the minute: what the product asks is whether people
  /// pick mornings or evenings, and an exact time is a smaller crowd in every
  /// bucket for no extra answer.
  factory AnalyticsEvent.reminderEnabled({required int hour}) {
    if (hour < 0 || hour > 23) {
      throw ArgumentError.value(hour, 'hour', 'must be 0 to 23');
    }
    return AnalyticsEvent._event('reminder_enabled', <String, Object>{
      'hour': hour,
    });
  }

  /// The daily reminder was turned off.
  factory AnalyticsEvent.reminderDisabled() =>
      AnalyticsEvent._event('reminder_disabled', const <String, Object>{});

  /// The streak grew, with the run it reached.
  factory AnalyticsEvent.streakAdvanced({
    required int currentStreak,
    required int longestStreak,
  }) =>
      AnalyticsEvent._event('streak_advanced', <String, Object>{
        'current_streak': currentStreak,
        'longest_streak': longestStreak,
      });

  /// The last day of the programme was completed.
  factory AnalyticsEvent.programFinished({required int programDay}) =>
      AnalyticsEvent._event('program_finished', <String, Object>{
        'program_day': programDay,
      });

  /// The event name, as it appears in the console.
  final String name;

  /// The parameters, ids and whole numbers only.
  final Map<String, Object> parameters;

  /// A string value has to look like an id from the content files or a known
  /// short label, which is what keeps personal data out of the payload: an
  /// email address or a person's name cannot match this.
  static void _requireId(String value, String key) {
    if (value.length > maxValueLength ||
        !RegExp(r'^[a-z][a-z0-9_.]*$').hasMatch(value)) {
      throw ArgumentError.value(
        value,
        key,
        'must be an id: lower case, starting with a letter, and at most '
        '$maxValueLength characters',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnalyticsEvent &&
          other.name == name &&
          mapEquals(other.parameters, parameters);

  @override
  int get hashCode => Object.hash(
        name,
        Object.hashAll(parameters.keys),
        Object.hashAll(parameters.values),
      );

  @override
  String toString() => parameters.isEmpty
      ? 'AnalyticsEvent($name)'
      : 'AnalyticsEvent($name, $parameters)';
}
