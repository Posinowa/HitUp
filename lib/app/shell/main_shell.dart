import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';

/// The five tabs' names.
abstract final class MainShellLabelsTr {
  /// Today's training.
  static const String home = 'Ana Sayfa';

  /// The programme.
  static const String training = 'Eğitim';

  /// Exercises to practise on their own.
  static const String practice = 'Pratik';

  /// The streak and the history.
  static const String progress = 'İlerleme';

  /// The account and the settings.
  static const String profile = 'Profil';
}

/// The main app's frame (HIT-021): five tabs along the bottom, Ana Sayfa,
/// Eğitim, Pratik, İlerleme and Profil.
///
/// Each tab is a branch of the router with a navigator of its own, kept alive
/// while another tab is shown, so a tab comes back as it was left: scrolled
/// where it was, with what was opened in it still open. Choosing the tab that
/// is already showing takes it back to its first page, as the platforms'
/// own tab bars do.
///
/// The tabs' bodies are the screens their issues build; until then each
/// shows which one.
class MainShell extends StatelessWidget {
  /// Frames [navigationShell], the router's branches.
  const MainShell({required this.navigationShell, super.key});

  /// The branches, and which one is showing.
  final StatefulNavigationShell navigationShell;

  /// The tabs, in the order of the router's branches.
  static const List<NavigationDestination> destinations =
      <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: MainShellLabelsTr.home,
    ),
    NavigationDestination(
      icon: Icon(Icons.school_outlined),
      selectedIcon: Icon(Icons.school),
      label: MainShellLabelsTr.training,
    ),
    NavigationDestination(
      icon: Icon(Icons.record_voice_over_outlined),
      selectedIcon: Icon(Icons.record_voice_over),
      label: MainShellLabelsTr.practice,
    ),
    NavigationDestination(
      icon: Icon(Icons.insights_outlined),
      selectedIcon: Icon(Icons.insights),
      label: MainShellLabelsTr.progress,
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: MainShellLabelsTr.profile,
    ),
  ];

  void _select(int index) => navigationShell.goBranch(
        index,
        // The tab already showing goes back to its first page.
        initialLocation: index == navigationShell.currentIndex,
      );

  /// Room kept clear either side of a tab's name, so it never meets the next.
  static const double _labelInset = 4;

  /// The largest text scale at which every tab's name fits on one line in a
  /// slot [slotWidth] wide.
  ///
  /// The bar grows its names with the user's text, up to 1.3 times, and a
  /// name longer than its slot then breaks, inside a word where it has no
  /// space ("İlerlem" over "e"). Held to this, the names grow as far as they
  /// fit and no further; where even the user's own size does not fit, as on
  /// a narrow phone, they come out a little smaller rather than broken.
  static double labelScaleFor(BuildContext context, double slotWidth) {
    final TextStyle style = Theme.of(context).textTheme.labelMedium ??
        const TextStyle(fontSize: 12);
    double widest = 0;
    for (final NavigationDestination tab in destinations) {
      final TextPainter painter = TextPainter(
        text: TextSpan(text: tab.label, style: style),
        textDirection: Directionality.of(context),
        maxLines: 1,
      )..layout();
      widest = max(widest, painter.width);
      painter.dispose();
    }
    return (slotWidth - 2 * _labelInset) / widest;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: navigationShell,
        bottomNavigationBar: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) =>
              MediaQuery.withClampedTextScaling(
            maxScaleFactor: labelScaleFor(
              context,
              constraints.maxWidth / destinations.length,
            ),
            child: NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _select,
              destinations: destinations,
            ),
          ),
        ),
      );
}
