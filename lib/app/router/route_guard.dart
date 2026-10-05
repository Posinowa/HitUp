import '../startup/startup_destination.dart';
import 'route_names.dart';

/// Where the user should be taken from [location], now that startup knows
/// [destination], or null to stay (HIT-020).
///
/// [destination] is what startup would open with the answers it has now:
/// whether onboarding was finished, and whether anyone is signed in. It is
/// worked out again whenever either changes, so this is asked again too, and
/// the app follows a sign-in or a sign-out from wherever the user is.
///
/// - **Onboarding not finished:** onboarding, from anywhere.
/// - **Signed out:** the main app, and onboarding once it is finished, lead
///   to login. This is what signing out does, and what an account that
///   Firebase ends does. The account screens stay where they are.
/// - **Signed in:** the account screens and onboarding lead home, except the
///   registration screen. An account exists, and signs in, before its
///   documents are written, and a failed write signs it out again
///   (`AUTH.md`), so registration leaves by itself once it has finished.
///
/// A pure function of two values, so every case is testable without a
/// router, a device or Firebase.
String? guardedRoute(StartupDestination destination, String location) {
  final bool onOnboarding = location == RouteNames.onboarding;
  final bool onAccountScreens = location.startsWith('${RouteNames.auth}/');
  final bool needsAccount = location.startsWith('${RouteNames.app}/') ||
      location == RouteNames.settings;

  return switch (destination) {
    StartupDestination.onboarding =>
      onOnboarding ? null : RouteNames.onboarding,
    StartupDestination.auth =>
      needsAccount || onOnboarding ? RouteNames.login : null,
    StartupDestination.home => location == RouteNames.register
        ? null
        : onAccountScreens || onOnboarding
            ? RouteNames.home
            : null,
  };
}
