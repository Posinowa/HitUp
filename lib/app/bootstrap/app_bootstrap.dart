import 'package:flutter/widgets.dart';

import '../../core/config/environment.dart';

/// Application bootstrap for foundation initialization.
///
/// Firebase client initialization belongs to HIT-009 once owner-provided
/// config (`firebase_options.dart` / platform files) exists.
/// Do NOT invent Firebase config files in this repository.
class AppBootstrap {
  const AppBootstrap._();

  static Future<void> init() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Environment is local/dev until a formal env strategy is wired (HIT-009+).
    assert(() {
      // ignore: avoid_print
      print('HitUp bootstrap — environment: ${Environment.current.name}');
      return true;
    }());

    // TODO(HIT-009): Initialize Firebase when firebase_options.dart is available.
    // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
}
