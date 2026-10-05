import 'package:shared_preferences/shared_preferences.dart';

import '../domain/onboarding_answers.dart';

/// Where onboarding's answers are kept on this device (HIT-015).
///
/// Apart from `OnboardingStore`'s flag, since startup reads the flag and
/// nothing reads the answers yet: a change here cannot hold up a cold start.
abstract interface class OnboardingAnswersStore {
  /// The answers kept, or none when nothing was answered.
  Future<OnboardingAnswers> load();

  /// Keeps [answers], replacing any kept before.
  Future<void> save(OnboardingAnswers answers);
}

/// [OnboardingAnswersStore] over the device's preferences.
class PreferencesOnboardingAnswersStore implements OnboardingAnswersStore {
  /// Creates a store.
  const PreferencesOnboardingAnswersStore();

  /// The key the goals are kept under, as their stored keys.
  static const String goalsKey = 'onboarding_goals';

  /// The key the minutes a day are kept under.
  static const String minutesKey = 'onboarding_daily_minutes';

  @override
  Future<OnboardingAnswers> load() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final List<String> goals = preferences.getStringList(goalsKey) ?? const [];
    return OnboardingAnswers(
      // A goal a later build stored and this one does not know is left out
      // rather than failing the read.
      goals: <SpeakingGoal>{
        for (final String key in goals)
          if (SpeakingGoal.fromKey(key) case final SpeakingGoal goal) goal,
      },
      dailyMinutes: preferences.getInt(minutesKey),
    );
  }

  @override
  Future<void> save(OnboardingAnswers answers) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      goalsKey,
      <String>[for (final SpeakingGoal goal in answers.goals) goal.key],
    );
    final int? minutes = answers.dailyMinutes;
    if (minutes == null) {
      await preferences.remove(minutesKey);
    } else {
      await preferences.setInt(minutesKey, minutes);
    }
  }
}
