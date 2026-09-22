import '../router/route_names.dart';

/// Where the app opens, once it knows enough to decide (HIT-014).
///
/// Three inputs, one answer, and no waiting: the decision itself is a pure
/// function so it can be read and tested without a device, a network or a
/// frame. Deciding what to wait for is [StartupInputs]; deciding where to go
/// is [startupDestination].
enum StartupDestination {
  /// The device has not been through onboarding.
  onboarding(RouteNames.onboarding),

  /// Onboarding is done, but nobody is signed in.
  auth(RouteNames.login),

  /// Signed in: the app proper.
  home(RouteNames.home);

  const StartupDestination(this.route);

  /// The route this destination opens.
  final String route;
}

/// What startup has to know before it can route.
///
/// Both are answers, not questions: a null here would mean "not known yet",
/// and the splash is what handles that, not this decision.
class StartupInputs {
  /// Creates the inputs.
  const StartupInputs({
    required this.onboardingComplete,
    required this.signedIn,
  });

  /// Whether onboarding has been completed on this device.
  final bool onboardingComplete;

  /// Whether an account is signed in.
  final bool signedIn;
}

/// Where the app opens for [inputs].
///
/// The order matters and is the product's, not an accident of the code:
/// onboarding explains the app to someone who has never seen it, so it comes
/// before asking them to sign in. A signed-in user who has somehow not seen
/// onboarding still sees it; it is the shorter of the two paths and it cannot
/// leave them stuck.
StartupDestination startupDestination(StartupInputs inputs) {
  if (!inputs.onboardingComplete) {
    return StartupDestination.onboarding;
  }
  return inputs.signedIn ? StartupDestination.home : StartupDestination.auth;
}
