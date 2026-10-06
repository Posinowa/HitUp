import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hitup/app/shell/main_shell.dart';
import 'package:hitup/core/theme/app_theme.dart';

/// The tab bar at the phone sizes the screens are checked at, with the app's
/// own fonts and with text enlarged: every tab's name on one line, never
/// broken inside a word.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final (String family, List<String> weights)
        in const <(String, List<String>)>[
      ('Manrope', <String>['Medium', 'Bold', 'ExtraBold']),
      ('PlusJakartaSans', <String>['Regular', 'Medium', 'SemiBold', 'Bold']),
    ]) {
      final FontLoader loader = FontLoader(family);
      for (final String weight in weights) {
        loader.addFont(
          rootBundle.load('assets/fonts/$family/$family-$weight.ttf'),
        );
      }
      await loader.load();
    }
  });

  /// The shell over five empty tabs, as the app's router builds it.
  Future<void> open(WidgetTester tester, Size phone, double scale) async {
    tester.view.physicalSize = phone * 3;
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final GoRouter router = GoRouter(
      initialLocation: '/tab0',
      routes: <RouteBase>[
        StatefulShellRoute.indexedStack(
          builder: (
            BuildContext context,
            GoRouterState state,
            StatefulNavigationShell shell,
          ) =>
              MainShell(navigationShell: shell),
          branches: <StatefulShellBranch>[
            for (int i = 0; i < 5; i++)
              StatefulShellBranch(
                routes: <RouteBase>[
                  GoRoute(
                    path: '/tab$i',
                    builder: (BuildContext context, GoRouterState state) =>
                        const SizedBox.expand(),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
    await tester.pumpAndSettle();
  }

  for (final Size phone in const <Size>[
    Size(390, 844),
    Size(360, 640),
    Size(320, 568),
  ]) {
    for (final double scale in const <double>[1, 1.3, 2]) {
      testWidgets(
          'every tab\'s name is on one line at ${phone.width.toInt()}x'
          '${phone.height.toInt()}, text x$scale', (WidgetTester tester) async {
        await open(tester, phone, scale);

        expect(tester.takeException(), isNull);
        for (final NavigationDestination tab in MainShell.destinations) {
          final Finder label = find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(tab.label),
          );
          final Text text = tester.widget<Text>(label);
          final TextStyle style = DefaultTextStyle.of(
            tester.element(label),
          ).style.merge(text.style);
          final double line = MediaQuery.textScalerOf(tester.element(label))
                  .scale(style.fontSize!) *
              (style.height ?? 1.2);
          expect(
            tester.getSize(label).height,
            lessThan(line * 1.5),
            reason: tab.label,
          );
        }
      });
    }
  }

  testWidgets('the names grow with the text as far as they fit, and no further',
      (WidgetTester tester) async {
    await open(tester, const Size(390, 844), 1.3);
    final Finder label = find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Profil'),
    );
    final double scale =
        MediaQuery.textScalerOf(tester.element(label)).scale(10) / 10;
    // Larger than the base size, but held below the 1.3 asked for, where
    // "Ana Sayfa" would no longer fit a fifth of a 390 point phone.
    expect(scale, greaterThan(1.05));
    expect(scale, lessThan(1.3));
  });
}
