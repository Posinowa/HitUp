import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/bootstrap/app_bootstrap.dart';

Future<void> main() async {
  final List<Override> overrides = await AppBootstrap.init();
  runApp(ProviderScope(overrides: overrides, child: const HitUpApp()));
}
