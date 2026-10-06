import 'package:flutter/foundation.dart';

/// What someone can say they want from the app, in onboarding (HIT-015).
///
/// Each has a key that is what is stored, so a later rename of the Dart name
/// does not change what devices already hold.
enum SpeakingGoal {
  /// Speaking more clearly.
  clarity('clarity'),

  /// Speaking with more confidence.
  confidence('confidence'),

  /// Speaking in front of others.
  publicSpeaking('public_speaking'),

  /// Pronouncing sounds and words better.
  pronunciation('pronunciation');

  const SpeakingGoal(this.key);

  /// What is stored.
  final String key;

  /// The goal stored as [key], or null for a key this build does not know.
  static SpeakingGoal? fromKey(String key) {
    for (final SpeakingGoal goal in values) {
      if (goal.key == key) {
        return goal;
      }
    }
    return null;
  }
}

/// The minutes a day onboarding offers to choose from.
const List<int> dailyMinuteChoices = <int>[5, 10, 15, 20];

/// The answers to onboarding's two optional questions (HIT-015).
///
/// Both may be left unanswered: no goals, and no minutes. They are kept on the
/// device for now, as the issue asks; syncing them to the account's
/// preferences is for when something reads them there.
@immutable
class OnboardingAnswers {
  /// Creates answers.
  const OnboardingAnswers({
    this.goals = const <SpeakingGoal>{},
    this.dailyMinutes,
  });

  /// The goals chosen, if any.
  final Set<SpeakingGoal> goals;

  /// The minutes a day chosen, or null when the question was left.
  final int? dailyMinutes;

  /// Whether nothing was answered.
  bool get isEmpty => goals.isEmpty && dailyMinutes == null;

  /// These answers with [goal] chosen or, if it was, no longer.
  OnboardingAnswers toggling(SpeakingGoal goal) => OnboardingAnswers(
        goals: goals.contains(goal)
            ? (Set<SpeakingGoal>.of(goals)..remove(goal))
            : (Set<SpeakingGoal>.of(goals)..add(goal)),
        dailyMinutes: dailyMinutes,
      );

  /// These answers with [minutes] chosen, or none when [minutes] is the
  /// choice already made.
  OnboardingAnswers choosing(int minutes) => OnboardingAnswers(
        goals: goals,
        dailyMinutes: dailyMinutes == minutes ? null : minutes,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnboardingAnswers &&
          setEquals(other.goals, goals) &&
          other.dailyMinutes == dailyMinutes;

  @override
  int get hashCode => Object.hash(
        Object.hashAllUnordered(goals),
        dailyMinutes,
      );

  @override
  String toString() =>
      'OnboardingAnswers(${goals.map((SpeakingGoal g) => g.key).join(', ')}; '
      '${dailyMinutes ?? '-'} min)';
}
