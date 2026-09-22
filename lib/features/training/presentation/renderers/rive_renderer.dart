import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rive/rive.dart' as rive;

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/failure_code.dart';
import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/errors/failure_messages.dart';
import '../../../../core/media/rive_runtime.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/models/models.dart';
import 'exercise_renderer.dart';

/// Reads the bytes of a bundled file.
typedef RiveBytesLoader = Future<Uint8List> Function(String assetPath);

/// Where the Rive renderer reads a `.riv` file from: the app bundle.
///
/// Overridable, so a test can hand it bytes without an asset bundle.
final Provider<RiveBytesLoader> riveBytesLoaderProvider =
    Provider<RiveBytesLoader>(
  (Ref ref) => (String assetPath) async =>
      (await rootBundle.load(assetPath)).buffer.asUint8List(),
);

/// The factory the Rive renderer draws with.
///
/// A function, not a factory: reading either of Rive's factories already
/// loads the native library, so it is called only once the runtime has said
/// it runs (`RIVE.md`). `Factory.rive` is the one Rive recommends.
final Provider<rive.Factory Function()> riveFactoryProvider =
    Provider<rive.Factory Function()>((Ref ref) => () => rive.Factory.rive);

/// Where a Rive media key lives in the bundle (`R2_MEDIA.md`).
String riveAssetPath(String key) => 'assets/rive/$key.riv';

/// Shows an exercise's Rive animation (HIT-033).
///
/// One renderer for every exercise whose media is a Rive file, whatever it
/// animates. The content says which file (`media.key`) and which state
/// machine (`media.stateMachine`); nothing here knows an exercise id.
class RiveExerciseRenderer implements ExerciseRenderer {
  /// Creates the renderer.
  const RiveExerciseRenderer();

  @override
  Widget build(BuildContext buildContext, ExerciseRenderContext context) =>
      RiveExerciseView(
        media: context.exercise.media,
        running: context.isRunning,
      );
}

/// Turkish text the Rive renderer shows.
abstract final class RiveRendererLabelsTr {
  const RiveRendererLabelsTr._();

  /// Read out while the animation loads.
  static const String loading = 'Animasyon yükleniyor';
}

/// The animation for one exercise, with its loading and its failure.
class RiveExerciseView extends ConsumerStatefulWidget {
  /// Creates the view for [media], moving while [running].
  const RiveExerciseView({
    required this.media,
    required this.running,
    super.key,
  });

  /// The exercise's media. Not a Rive file, or none at all, is a content
  /// mistake, and shown as one.
  final MediaReference? media;

  /// Whether the session is running. A paused session holds the animation
  /// still, so it does not carry on without the user.
  final bool running;

  @override
  ConsumerState<RiveExerciseView> createState() => _RiveExerciseViewState();
}

class _RiveExerciseViewState extends ConsumerState<RiveExerciseView> {
  rive.File? _file;
  rive.RiveWidgetController? _controller;
  Failure? _failure;

  /// Which load is current. A load that finishes after the media changed
  /// is a load of the old file, and is dropped.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(RiveExerciseView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media != widget.media) {
      _releaseAfterFrame();
      _start();
      return;
    }
    _controller?.active = widget.running;
  }

  /// Starts showing [RiveExerciseView.media]. Called while building, so it
  /// sets state directly; the build that follows shows it.
  void _start() {
    _generation++;
    _failure = null;
    final MediaReference? media = widget.media;
    if (media == null || media.kind != MediaKind.rive) {
      _failure = const ContentFailure(
        code: FailureCode.contentMalformed,
        technicalDetail: 'A Rive exercise without a Rive media reference',
      );
      debugPrint('HIT-033: animation not shown. $_failure');
      return;
    }
    unawaited(_load(media, _generation));
  }

  /// Whether a load started as [generation] should still carry on.
  bool _current(int generation) => mounted && generation == _generation;

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  void _release() {
    _controller?.dispose();
    _controller = null;
    _file?.dispose();
    _file = null;
  }

  /// Lets go of the animation on screen once the next frame has replaced
  /// it, not while the `RiveWidget` showing it is still in the tree.
  ///
  /// A precaution: with `rive` 0.14.11 the widget's own dispose releases
  /// only its texture painter and does not touch the controller, and the
  /// tests, which draw with the Flutter factory, pass either way. The app
  /// draws with the Rive factory and a shared texture, which no test here
  /// can run, so nothing is released while it may still be drawn from.
  void _releaseAfterFrame() {
    final rive.RiveWidgetController? controller = _controller;
    final rive.File? file = _file;
    _controller = null;
    _file = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller?.dispose();
      file?.dispose();
    });
  }

  Future<void> _load(MediaReference media, int generation) async {
    // Everything from `ref` before the first await: the view may be gone by
    // the time the file is read.
    final RiveRuntime runtime = ref.read(riveRuntimeProvider);
    final RiveBytesLoader load = ref.read(riveBytesLoaderProvider);
    final rive.Factory Function() factory = ref.read(riveFactoryProvider);

    try {
      final bool ready = await runtime.ensureReady();
      // Left, or moved to other media, before it was ready: nothing to read,
      // nothing to decode.
      if (!_current(generation)) {
        return;
      }
      if (!ready) {
        _fail(
          generation,
          const ContentFailure(
            code: FailureCode.contentMediaUnavailable,
            technicalDetail: 'The Rive runtime does not run on this device',
          ),
        );
        return;
      }
      // Read before decoding: a missing file is refused by the bundle, with
      // its own failure, before anything reaches the runtime.
      final Uint8List bytes = await load(riveAssetPath(media.key));
      if (!_current(generation)) {
        return;
      }
      final rive.File? file = await rive.File.decode(
        bytes,
        riveFactory: factory(),
      );
      if (file == null) {
        throw rive.RiveFileLoaderException(
          'Failed to decode Rive file ${riveAssetPath(media.key)}',
        );
      }
      if (!_current(generation)) {
        file.dispose();
        return;
      }
      _file = file;
      final String? stateMachine = media.stateMachine;
      // Throws for a state machine the file does not have: a content
      // mistake the user sees as media that cannot be shown.
      final rive.RiveWidgetController controller = rive.RiveWidgetController(
        file,
        stateMachineSelector: stateMachine == null
            ? rive.StateMachineSelector.byDefault()
            : rive.StateMachineSelector.byName(stateMachine),
      )..active = widget.running;
      setState(() => _controller = controller);
    } catch (error) {
      _fail(generation, mapErrorToFailure(error));
    }
  }

  void _fail(int generation, Failure failure) {
    // A failure of an old load says nothing about the media shown now.
    if (!_current(generation)) {
      return;
    }
    debugPrint('HIT-033: animation not shown. $failure');
    _release();
    setState(() => _failure = failure);
  }

  @override
  Widget build(BuildContext context) {
    final Failure? failure = _failure;
    if (failure != null) {
      final ColorScheme colors = Theme.of(context).colorScheme;
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.motion_photos_off_outlined, color: colors.outline),
            const SizedBox(height: AppSpacing.sm),
            Text(
              failureMessage(failure),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }
    final rive.RiveWidgetController? controller = _controller;
    if (controller == null) {
      return Semantics(
        label: RiveRendererLabelsTr.loading,
        child: const SizedBox.square(
          dimension: 32,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      );
    }
    return AspectRatio(
      aspectRatio: 1,
      child: rive.RiveWidget(controller: controller),
    );
  }
}
