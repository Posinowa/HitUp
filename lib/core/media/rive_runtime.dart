import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rive/rive.dart';

/// Whether Rive can run on this device (HIT-032).
///
/// The one door to the Rive runtime. Nothing decodes or shows a `.riv` file
/// until [ensureReady] has answered true (`docs/architecture/RIVE.md`).
abstract interface class RiveRuntime {
  /// Starts the runtime if it has not been started, and says whether it runs.
  ///
  /// Never throws. False means Rive cannot run here, and a screen shows its
  /// fallback instead of an animation.
  Future<bool> ensureReady();
}

/// [RiveRuntime] over `RiveNative.init`, asked once.
///
/// **Once, and never again after a failure.** `RiveNative.init` keeps its own
/// completer: when loading the native library throws, that completer is never
/// completed, and every later call, including the one inside `File.decode`,
/// waits on it forever (checked against `rive_native` 0.1.11). So the first
/// answer is kept here, a throw is kept as false, and nothing asks again.
///
/// **On first use, not at start-up.** Most launches show no animation, and
/// they should not pay for loading a native library they do not use.
class NativeRiveRuntime implements RiveRuntime {
  /// Creates a runtime over [init], which is `RiveNative.init` outside tests.
  NativeRiveRuntime({Future<bool> Function()? init})
      : _init = init ?? RiveNative.init;

  final Future<bool> Function() _init;
  Future<bool>? _ready;

  @override
  Future<bool> ensureReady() => _ready ??= _start();

  Future<bool> _start() async {
    try {
      return await _init();
    } catch (error) {
      // An error, not only an exception: a native library that cannot be
      // loaded surfaces as an ArgumentError.
      debugPrint('HIT-032: the Rive runtime could not start. Cause: $error');
      return false;
    }
  }
}

/// The app's Rive runtime.
///
/// One for the whole app: the native runtime is process-wide, and a second
/// instance would ask `RiveNative.init` again.
final Provider<RiveRuntime> riveRuntimeProvider =
    Provider<RiveRuntime>((Ref ref) => NativeRiveRuntime());
