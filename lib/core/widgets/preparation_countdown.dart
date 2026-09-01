import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Turkish text the countdown shows.
///
/// Gathered here rather than written inline, matching `FailureLabelsTr`: when
/// this app is ever translated, the strings have to be findable, and a string
/// buried in a widget's default argument is not. It also makes the screen
/// reader announcement editable, which it was not while it lived inside the
/// build method.
abstract final class PreparationCountdownLabelsTr {
  const PreparationCountdownLabelsTr._();

  /// Text on the button that stops the countdown early.
  static const String cancel = 'Vazgeç';

  /// What a screen reader announces on each tick.
  static String secondsRemaining(int seconds) => '$seconds saniye';
}

/// Where a countdown is in its life.
enum PreparationCountdownStatus {
  /// Created but not started.
  idle,

  /// Counting down.
  running,

  /// Reached zero on its own.
  completed,

  /// Stopped by the user before reaching zero.
  ///
  /// Terminal, not a pause. A speaker who backed out of a task is not halfway
  /// through preparing for it, and offering to resume a preparation countdown
  /// would be offering to resume something that no longer means anything.
  cancelled,
}

/// The clock behind a preparation countdown, with no widget attached.
///
/// Split from the widget so the exercise flows that need this (the speaking
/// challenge system, HIT-048, and whatever else needs a lead in) can drive and
/// observe it without a build context, and so its behaviour is testable without
/// rendering anything.
///
/// A [Timer] rather than an [AnimationController]: the countdown is a sequence
/// of whole seconds, not a continuous value, and an animation controller would
/// tie this to a [TickerProvider] and a vsync that a plain controller has no
/// reason to need.
class PreparationCountdownController extends ChangeNotifier {
  /// Creates a countdown of [seconds].
  ///
  /// [seconds] must be at least one. A zero second preparation is not a short
  /// countdown, it is the absence of one, and the caller should skip this
  /// component entirely rather than render something that finishes instantly.
  PreparationCountdownController({required this.seconds})
      : assert(
          seconds > 0,
          'A preparation countdown needs at least one second',
        ),
        _secondsRemaining = seconds;

  /// How long the countdown runs for.
  final int seconds;

  Timer? _timer;
  int _secondsRemaining;
  PreparationCountdownStatus _status = PreparationCountdownStatus.idle;

  /// Seconds still to go. Reaches zero exactly when the countdown completes.
  int get secondsRemaining => _secondsRemaining;

  /// Where the countdown is in its life.
  PreparationCountdownStatus get status => _status;

  /// Whether the countdown is currently ticking.
  bool get isRunning => _status == PreparationCountdownStatus.running;

  /// Whether the countdown has stopped, either way.
  bool get isFinished =>
      _status == PreparationCountdownStatus.completed ||
      _status == PreparationCountdownStatus.cancelled;

  /// How far through the countdown is, from 0.0 to 1.0.
  ///
  /// Useful for a ring or a bar. Derived rather than tracked separately, so it
  /// cannot drift out of step with [secondsRemaining].
  double get progress => (seconds - _secondsRemaining) / seconds;

  /// Starts counting down.
  ///
  /// Does nothing when already running or already finished. Restarting a
  /// finished countdown is not supported on purpose: the caller creates a new
  /// controller, which makes it obvious in the calling code that a second
  /// preparation happened.
  void start() {
    if (_status != PreparationCountdownStatus.idle) {
      return;
    }
    _status = PreparationCountdownStatus.running;
    notifyListeners();

    _timer = Timer.periodic(const Duration(seconds: 1), (Timer _) {
      _secondsRemaining--;
      if (_secondsRemaining <= 0) {
        _secondsRemaining = 0;
        _stopTimer();
        _status = PreparationCountdownStatus.completed;
      }
      notifyListeners();
    });
  }

  /// Stops the countdown before it finishes.
  ///
  /// Does nothing once the countdown has already finished, so a cancel arriving
  /// in the same frame as the final tick cannot turn a completed preparation
  /// into a cancelled one.
  void cancel() {
    if (_status != PreparationCountdownStatus.running) {
      return;
    }
    _stopTimer();
    _status = PreparationCountdownStatus.cancelled;
    notifyListeners();
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    // A periodic timer outlives the widget that started it unless something
    // stops it, and it would go on calling notifyListeners on a disposed
    // controller.
    _stopTimer();
    super.dispose();
  }
}

/// A "3, 2, 1" lead in shown before a speaking or timed task.
///
/// Reads its colours and type from the theme, never from literals, so it
/// follows the design tokens (HIT-008) wherever it is placed.
class PreparationCountdown extends StatefulWidget {
  /// Creates a countdown.
  const PreparationCountdown({
    required this.seconds,
    this.onCompleted,
    this.onCancelled,
    this.autoStart = true,
    this.label,
    this.cancelLabel = PreparationCountdownLabelsTr.cancel,
    super.key,
  });

  /// How long to count down for.
  final int seconds;

  /// Called once the countdown reaches zero.
  final VoidCallback? onCompleted;

  /// Called if the user stops the countdown early.
  final VoidCallback? onCancelled;

  /// Whether to begin as soon as the widget is shown.
  final bool autoStart;

  /// Optional line above the number, saying what is about to start.
  final String? label;

  /// Text on the cancel button. Set to null to leave the countdown
  /// uncancellable, which should be rare and deliberate.
  final String? cancelLabel;

  @override
  State<PreparationCountdown> createState() => _PreparationCountdownState();
}

class _PreparationCountdownState extends State<PreparationCountdown> {
  late final PreparationCountdownController _controller;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    _controller = PreparationCountdownController(seconds: widget.seconds)
      ..addListener(_onControllerChanged);
    if (widget.autoStart) {
      _controller.start();
    }
  }

  void _onControllerChanged() {
    setState(() {});

    // Guarded so a callback fires once even if the controller notifies again,
    // and deferred to the end of the frame because a caller will usually
    // navigate from here, and navigating during a build is an error.
    if (_reported || !_controller.isFinished) {
      return;
    }
    _reported = true;
    final VoidCallback? callback =
        _controller.status == PreparationCountdownStatus.completed
            ? widget.onCompleted
            : widget.onCancelled;
    if (callback == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        callback();
      }
    });
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onControllerChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final int remaining = _controller.secondsRemaining;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (widget.label != null) ...<Widget>[
              Text(
                widget.label!,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            // liveRegion so a screen reader announces each number as it
            // changes. Without it the countdown is silent to anyone who cannot
            // see it, and they get no warning before the task starts.
            Semantics(
              liveRegion: true,
              label: PreparationCountdownLabelsTr.secondsRemaining(remaining),
              excludeSemantics: true,
              child: SizedBox(
                width: 96,
                height: 96,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    CircularProgressIndicator(
                      value: _controller.progress,
                      strokeWidth: 6,
                      backgroundColor: colors.outline,
                      valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                    ),
                    Text(
                      '$remaining',
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.cancelLabel != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: _controller.isRunning ? _controller.cancel : null,
                child: Text(widget.cancelLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
