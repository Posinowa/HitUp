import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/app/router/route_names.dart';
import 'package:hitup/app/startup/startup_destination.dart';

void main() {
  StartupDestination where({
    required bool onboardingComplete,
    required bool signedIn,
  }) =>
      startupDestination(
        StartupInputs(
          onboardingComplete: onboardingComplete,
          signedIn: signedIn,
        ),
      );

  group('where a cold start opens', () {
    test('a device that has not seen onboarding sees onboarding', () {
      expect(
        where(onboardingComplete: false, signedIn: false),
        StartupDestination.onboarding,
      );
    });

    test('onboarding comes before signing in, even for a signed-in user', () {
      // The shorter path, and the one that cannot leave anyone stuck: an
      // account restored on a fresh install would otherwise land in an app
      // nobody has explained.
      expect(
        where(onboardingComplete: false, signedIn: true),
        StartupDestination.onboarding,
      );
    });

    test('onboarding done and nobody signed in leads to auth', () {
      expect(
        where(onboardingComplete: true, signedIn: false),
        StartupDestination.auth,
      );
    });

    test('onboarding done and signed in leads home', () {
      expect(
        where(onboardingComplete: true, signedIn: true),
        StartupDestination.home,
      );
    });

    test('the same inputs always give the same answer', () {
      for (final bool onboarding in <bool>[true, false]) {
        for (final bool signedIn in <bool>[true, false]) {
          expect(
            where(onboardingComplete: onboarding, signedIn: signedIn),
            where(onboardingComplete: onboarding, signedIn: signedIn),
          );
        }
      }
    });
  });

  group('each destination names a route the app has', () {
    test('and they are the routes the names file defines', () {
      expect(StartupDestination.onboarding.route, RouteNames.onboarding);
      expect(StartupDestination.auth.route, RouteNames.login);
      expect(StartupDestination.home.route, RouteNames.home);
    });

    test('no two destinations share a route', () {
      final Set<String> routes = StartupDestination.values
          .map((StartupDestination d) => d.route)
          .toSet();
      expect(routes, hasLength(StartupDestination.values.length));
    });
  });
}
