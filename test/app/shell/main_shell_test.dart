import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hitup/app/app.dart';
import 'package:hitup/app/router/route_names.dart';
import 'package:hitup/app/shell/main_shell.dart';
import 'package:hitup/features/auth/domain/models/auth_user.dart';
import 'package:hitup/features/onboarding/data/onboarding_store.dart';
import 'package:hitup/features/training/application/finished_day_recorder.dart';
import 'package:hitup/features/training/data/pending_day_store.dart';
import 'package:hitup/shared/providers/auth_providers.dart';
import 'package:hitup/shared/providers/startup_providers.dart';

class _Onboarded implements OnboardingStore {
  @override
  Future<bool> isComplete() async => true;

  @override
  Future<void> markComplete() async {}
}

class _NothingPending implements PendingDayStore {
  @override
  Future<List<PendingDay>> load() async => const <PendingDay>[];

  @override
  Future<void> add(PendingDay day) async {}

  @override
  Future<void> remove(PendingDay day) async {}
}

void main() {
  /// The app, signed in, on a 390 by 844 phone: it opens on home.
  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          onboardingStoreProvider.overrideWithValue(_Onboarded()),
          authStateChangesProvider.overrideWith(
            (Ref ref) => Stream<AuthUser?>.value(const AuthUser(uid: 'uid-1')),
          ),
          pendingDayStoreProvider.overrideWithValue(_NothingPending()),
        ],
        child: const HitUpApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  int selected(WidgetTester tester) =>
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

  Future<void> choose(WidgetTester tester, String tab) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(tab),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a signed-in start opens home, under five tabs',
      (WidgetTester tester) async {
    await open(tester);

    expect(find.byType(MainShell), findsOneWidget);
    expect(find.text('Bugünün antrenmanı'), findsOneWidget);
    expect(selected(tester), 0);
    for (final String tab in <String>[
      'Ana Sayfa',
      'Eğitim',
      'Pratik',
      'İlerleme',
      'Profil',
    ]) {
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(tab),
        ),
        findsOneWidget,
        reason: tab,
      );
    }
  });

  testWidgets('each tab opens its own page', (WidgetTester tester) async {
    await open(tester);

    for (final (String tab, int index, String detail)
        in <(String, int, String)>[
      ('Eğitim', 1, 'HIT-027 bu ekranı yazacak.'),
      ('Pratik', 2, 'HIT-021C bu ekranı yazacak.'),
      ('İlerleme', 3, 'HIT-055 bu ekranı yazacak.'),
      ('Profil', 4, 'HIT-060 bu ekranı yazacak.'),
      ('Ana Sayfa', 0, 'HIT-021B bu ekranı yazacak.'),
    ]) {
      await choose(tester, tab);

      expect(selected(tester), index, reason: tab);
      expect(find.text(detail), findsOneWidget, reason: tab);
    }
  });

  testWidgets('each tab is at its own route', (WidgetTester tester) async {
    await open(tester);
    final GoRouter router = GoRouter.of(tester.element(find.byType(MainShell)));

    for (final (String route, int index) in <(String, int)>[
      (RouteNames.training, 1),
      (RouteNames.practice, 2),
      (RouteNames.progress, 3),
      (RouteNames.profile, 4),
      (RouteNames.home, 0),
    ]) {
      router.go(route);
      await tester.pumpAndSettle();

      expect(selected(tester), index, reason: route);
    }
  });

  testWidgets('a tab left comes back as it was, not built again',
      (WidgetTester tester) async {
    await open(tester);
    final Element home = tester.element(find.text('Bugünün antrenmanı'));

    await choose(tester, 'İlerleme');
    // Out of sight, not gone.
    expect(find.text('Bugünün antrenmanı'), findsNothing);
    expect(
      find.text('Bugünün antrenmanı', skipOffstage: false),
      findsOneWidget,
    );

    await choose(tester, 'Ana Sayfa');
    expect(tester.element(find.text('Bugünün antrenmanı')), same(home));
  });

  testWidgets('choosing the tab already showing keeps it showing',
      (WidgetTester tester) async {
    await open(tester);

    await choose(tester, 'Ana Sayfa');

    expect(selected(tester), 0);
    expect(find.text('Bugünün antrenmanı'), findsOneWidget);
  });

  testWidgets(
      'a tab left on its second page comes back on it, and choosing it '
      'again goes back to its first', (WidgetTester tester) async {
    // No tab has a second page yet, so these five have one each.
    final GoRouter router = GoRouter(
      initialLocation: '/tab0/second',
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
                        Text('first $i'),
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'second',
                        builder: (BuildContext context, GoRouterState state) =>
                            Text('second $i'),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('second 0'), findsOneWidget);

    await choose(tester, 'Eğitim');
    await choose(tester, 'Ana Sayfa');
    expect(find.text('second 0'), findsOneWidget);

    await choose(tester, 'Ana Sayfa');
    expect(find.text('first 0'), findsOneWidget);
    expect(find.text('second 0'), findsNothing);
  });

  testWidgets('the tabs are read out by their names',
      (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await open(tester);

    for (final String tab in <String>['Ana Sayfa', 'Eğitim', 'Profil']) {
      expect(find.bySemanticsLabel(RegExp(tab)), findsWidgets, reason: tab);
    }
    semantics.dispose();
  });
}
