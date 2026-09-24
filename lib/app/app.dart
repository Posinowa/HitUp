import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../features/training/application/finished_day_recorder.dart';
import 'router/app_router.dart';

/// Root HitUp application widget.
class HitUpApp extends ConsumerWidget {
  const HitUpApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    // Days an earlier run finished but could not record are recorded as soon
    // as someone is signed in. Listened to rather than watched: the app has
    // nothing to redraw when it completes.
    ref.listen(pendingDaysProvider, (_, __) {});

    return MaterialApp.router(
      title: 'HitUp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
    );
  }
}
