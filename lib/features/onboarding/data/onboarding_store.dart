import 'package:shared_preferences/shared_preferences.dart';

/// Whether this device has been through onboarding.
///
/// A device flag, not an account one: onboarding explains the app, and a user
/// who has seen it does not need it again after signing out. It lives on the
/// device for the same reason, so it is readable before anyone signs in, which
/// is what startup needs (HIT-014).
abstract interface class OnboardingStore {
  /// True once onboarding has been completed on this device.
  Future<bool> isComplete();

  /// Records that onboarding is done.
  Future<void> markComplete();
}

/// [OnboardingStore] over the device's preferences.
class PreferencesOnboardingStore implements OnboardingStore {
  /// Creates a store.
  const PreferencesOnboardingStore();

  /// The key the flag is stored under.
  ///
  /// Named for what it is rather than for the screen that sets it, so a later
  /// rewrite of onboarding (HIT-015) does not orphan it and show onboarding
  /// again to everyone who already finished it.
  static const String key = 'onboarding_complete';

  @override
  Future<bool> isComplete() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    return preferences.getBool(key) ?? false;
  }

  @override
  Future<void> markComplete() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setBool(key, true);
  }
}
