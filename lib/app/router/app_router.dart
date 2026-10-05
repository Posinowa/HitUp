import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/registration_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../shared/providers/startup_providers.dart';
import '../shell/main_shell.dart';
import '../startup/startup_destination.dart';
import 'route_guard.dart';
import 'route_names.dart';

/// The app's routes, and the one redirect that opens it (HIT-014) and keeps
/// the user where the account allows (HIT-020).
///
/// Every cold start lands on the splash. The redirect sends it on as soon as
/// `startupProvider` knows where to go, and leaves it there while it does not,
/// so the destination is decided once, in one place, from answers rather than
/// from guesses. Startup's answer is worked out again whenever the account or
/// the onboarding flag changes, and the router asks again with it, so a
/// sign-out anywhere in the app leads to login and a sign-in on the account
/// screens leads home (`guardedRoute`).
///
/// Onboarding is HIT-015. The account screens are HIT-017 to HIT-019: login,
/// and the registration and forgot-password screens it leads to. Home is the
/// first of the main app's five tabs (HIT-021, `MainShell`), whose screens
/// are still placeholders.
final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  return GoRouter(
    initialLocation: RouteNames.splash,
    refreshListenable: ref.watch(startupListenableProvider),
    redirect: (BuildContext context, GoRouterState state) {
      final AsyncValue<StartupDestination> startup = ref.read(startupProvider);
      final bool onSplash = state.matchedLocation == RouteNames.splash;

      return startup.when(
        // Still asking. Stay on, or return to, the splash.
        loading: () => onSplash ? null : RouteNames.splash,
        // Failed. The splash is also where the message and the retry live.
        error: (Object _, StackTrace __) => onSplash ? null : RouteNames.splash,
        // Known. Leave the splash for the destination; anywhere else, follow
        // the account and the onboarding flag as they change (HIT-020).
        data: (StartupDestination destination) => onSplash
            ? destination.route
            : guardedRoute(destination, state.matchedLocation),
      );
    },
    routes: <RouteBase>[
      GoRoute(
        path: RouteNames.splash,
        name: 'splash',
        builder: (BuildContext context, GoRouterState state) =>
            const _SplashRoute(),
      ),
      GoRoute(
        path: RouteNames.onboarding,
        name: 'onboarding',
        builder: (BuildContext context, GoRouterState state) =>
            const OnboardingScreen(),
      ),
      GoRoute(
        path: RouteNames.login,
        name: 'login',
        builder: (BuildContext context, GoRouterState state) =>
            const LoginScreen(),
        // Gone to, not pushed: login stays under each for the back button,
        // and the location the guard reads is the screen showing. A pushed
        // route is left out of it.
        routes: <RouteBase>[
          GoRoute(
            path: 'register',
            name: 'register',
            builder: (BuildContext context, GoRouterState state) =>
                const RegistrationScreen(),
          ),
          GoRoute(
            path: 'forgot-password',
            name: 'forgotPassword',
            // The address the login screen had, so it is not typed twice.
            builder: (BuildContext context, GoRouterState state) =>
                ForgotPasswordScreen(
              initialEmail: state.extra is String ? state.extra! as String : '',
            ),
          ),
        ],
      ),
      // The main app: five tabs, each a branch with a navigator of its own
      // (HIT-021). The order is the tab bar's.
      StatefulShellRoute.indexedStack(
        builder: (
          BuildContext context,
          GoRouterState state,
          StatefulNavigationShell navigationShell,
        ) =>
            MainShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          _tab(
            RouteNames.home,
            'home',
            'Bugünün antrenmanı',
            'HIT-021B bu ekranı yazacak.',
          ),
          _tab(
            RouteNames.training,
            'training',
            MainShellLabelsTr.training,
            'HIT-027 bu ekranı yazacak.',
          ),
          _tab(
            RouteNames.practice,
            'practice',
            MainShellLabelsTr.practice,
            'HIT-021C bu ekranı yazacak.',
          ),
          _tab(
            RouteNames.progress,
            'progress',
            MainShellLabelsTr.progress,
            'HIT-055 bu ekranı yazacak.',
          ),
          _tab(
            RouteNames.profile,
            'profile',
            MainShellLabelsTr.profile,
            'HIT-060 bu ekranı yazacak.',
          ),
        ],
      ),
    ],
  );
});

/// A tab whose screen is still to be built: its route, and a placeholder that
/// names the issue that builds it.
StatefulShellBranch _tab(
  String path,
  String name,
  String title,
  String detail,
) =>
    StatefulShellBranch(
      routes: <RouteBase>[
        GoRoute(
          path: path,
          name: name,
          builder: (BuildContext context, GoRouterState state) =>
              _PlaceholderScreen(title: title, detail: detail),
        ),
      ],
    );

/// The splash, told what startup is doing.
class _SplashRoute extends ConsumerWidget {
  const _SplashRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<StartupDestination> startup = ref.watch(startupProvider);

    return startup.when(
      loading: () => const SplashScreen(),
      data: (StartupDestination _) => const SplashScreen(),
      // What the user can act on, without the technical detail: the failure
      // itself belongs in the crash report, not on the screen.
      error: (Object _, StackTrace __) => SplashScreen(
        message: 'Uygulama açılırken bir sorun oldu.\n'
            'Bağlantını kontrol edip tekrar deneyebilirsin.',
        onRetry: () => retryStartup(ref),
      ),
    );
  }
}

/// A named, empty screen, so a redirect can be seen to arrive somewhere.
class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  title,
                  style: text.headlineSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
