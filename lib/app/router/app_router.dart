import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../shared/providers/startup_providers.dart';
import '../startup/startup_destination.dart';
import 'route_names.dart';

/// The app's routes, and the one redirect that opens it (HIT-014).
///
/// Every cold start lands on the splash. The redirect sends it on as soon as
/// `startupProvider` knows where to go, and leaves it there while it does not,
/// so the destination is decided once, in one place, from answers rather than
/// from guesses.
///
/// The screens behind the three destinations are placeholders. Onboarding is
/// HIT-015, the auth screens are HIT-017 to HIT-019, and the shell behind home
/// is HIT-021. What this issue owns is that a cold start reaches the right one.
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
        // Known. Leave the splash for the destination, and leave every other
        // route alone, so this redirect cannot fight later navigation
        // (HIT-020 owns the guard that does).
        data: (StartupDestination destination) =>
            onSplash ? destination.route : null,
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
            const _PlaceholderScreen(
          title: 'Onboarding',
          detail: 'HIT-015 bu ekranı yazacak.',
        ),
      ),
      GoRoute(
        path: RouteNames.login,
        name: 'login',
        builder: (BuildContext context, GoRouterState state) =>
            const _PlaceholderScreen(
          title: 'Giriş',
          detail: 'HIT-018 bu ekranı yazacak.',
        ),
      ),
      GoRoute(
        path: RouteNames.home,
        name: 'home',
        builder: (BuildContext context, GoRouterState state) =>
            const _PlaceholderScreen(
          title: 'Bugünün antrenmanı',
          detail: 'HIT-021B bu ekranı yazacak.',
        ),
      ),
    ],
  );
});

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
