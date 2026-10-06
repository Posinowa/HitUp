import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/app/router/route_guard.dart';
import 'package:hitup/app/router/route_names.dart';
import 'package:hitup/app/startup/startup_destination.dart';

void main() {
  const List<String> appRoutes = <String>[
    RouteNames.home,
    RouteNames.training,
    RouteNames.practice,
    RouteNames.progress,
    RouteNames.profile,
  ];
  const List<String> accountScreens = <String>[
    RouteNames.login,
    RouteNames.register,
    RouteNames.forgotPassword,
  ];

  group('onboarding not finished', () {
    test('everything leads to onboarding, which stays', () {
      for (final String at in <String>[
        ...appRoutes,
        ...accountScreens,
        RouteNames.settings,
      ]) {
        expect(
          guardedRoute(StartupDestination.onboarding, at),
          RouteNames.onboarding,
          reason: at,
        );
      }
      expect(
        guardedRoute(StartupDestination.onboarding, RouteNames.onboarding),
        isNull,
      );
    });
  });

  group('signed out', () {
    test('the main app and the settings lead to login', () {
      for (final String at in <String>[...appRoutes, RouteNames.settings]) {
        expect(
          guardedRoute(StartupDestination.auth, at),
          RouteNames.login,
          reason: at,
        );
      }
    });

    test('a finished onboarding leads to login', () {
      expect(
        guardedRoute(StartupDestination.auth, RouteNames.onboarding),
        RouteNames.login,
      );
    });

    test('the account screens stay where they are', () {
      for (final String at in accountScreens) {
        expect(guardedRoute(StartupDestination.auth, at), isNull, reason: at);
      }
    });
  });

  group('signed in', () {
    test('login and the forgot-password screen lead home', () {
      for (final String at in <String>[
        RouteNames.login,
        RouteNames.forgotPassword,
      ]) {
        expect(
          guardedRoute(StartupDestination.home, at),
          RouteNames.home,
          reason: at,
        );
      }
    });

    test('registration is left to finish by itself', () {
      expect(
        guardedRoute(StartupDestination.home, RouteNames.register),
        isNull,
      );
    });

    test('a finished onboarding leads home', () {
      expect(
        guardedRoute(StartupDestination.home, RouteNames.onboarding),
        RouteNames.home,
      );
    });

    test('the main app stays where it is', () {
      for (final String at in <String>[...appRoutes, RouteNames.settings]) {
        expect(guardedRoute(StartupDestination.home, at), isNull, reason: at);
      }
    });
  });

  test('a route only named like the main app is not taken for it', () {
    // '/application' is not under '/app/'.
    expect(guardedRoute(StartupDestination.auth, '/application'), isNull);
    expect(guardedRoute(StartupDestination.home, '/authors'), isNull);
  });
}
