import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/failure_code.dart';
import '../../../../core/errors/failure_messages.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/breathing/breathing.dart';
import '../../domain/models/models.dart';
import 'exercise_renderer.dart';

/// Turkish text the breathing exercise shows.
abstract final class BreathingLabelsTr {
  const BreathingLabelsTr._();

  /// Shown once every cycle is done.
  static const String allDone = 'Nefes çalışması tamam';

  /// Starts the cycles again.
  static const String again = 'Tekrar';

  /// Shown while the session is paused.
  static const String paused = 'Duraklatıldı';

  /// What to do in each phase.
  static String phase(BreathingPhase phase) => switch (phase) {
        BreathingPhase.inhale => 'Al',
        BreathingPhase.hold => 'Tut',
        BreathingPhase.exhale => 'Ver',
      };

  /// Which cycle this is.
  static String cycle(int current, int total) => 'Tur $current / $total';

  /// What the circle shows now, the phase or that it is paused, and the
  /// seconds left in the phase, read aloud together.
  static String spoken(String now, int seconds) => '$now, $seconds saniye';
}

/// The breathing exercise (HIT-030).
///
/// A circle that grows on the in-breath, holds, and shrinks on the
/// out-breath, driven by `BreathingEngine` (HIT-029): the pattern comes from
/// the content and the timing from the engine, so what is drawn here is only
/// what the engine says is true now.
///
/// **Where the device asks for less motion** the circle stays still and the
/// phase and its count carry the exercise, since a breathing animation is
/// exactly the kind of steady pulsing that a person with vestibular trouble
/// has that setting on for.
///
/// **The words stay in view.** The phase, its seconds and the cycle are what
/// the exercise is followed by, so on a small phone it is the circle that
/// gives way: smaller, or beside the words.
class BreathingRenderer implements ExerciseRenderer {
  /// Creates the renderer.
  const BreathingRenderer();

  @override
  Widget build(BuildContext buildContext, ExerciseRenderContext context) =>
      BreathingView(
        config: context.exercise.configAs<BreathingConfig>(),
        running: context.isRunning,
      );
}

/// One breathing exercise.
class BreathingView extends StatefulWidget {
  /// Creates the view for [config].
  const BreathingView({
    required this.config,
    required this.running,
    super.key,
  });

  /// The pattern to breathe. Null is a content mistake, shown as one.
  final BreathingConfig? config;

  /// Whether the session is running. The breathing stops with it.
  final bool running;

  @override
  State<BreathingView> createState() => _BreathingViewState();
}

class _BreathingViewState extends State<BreathingView> {
  /// How often the engine is advanced. Short enough that the circle moves
  /// smoothly, long enough not to rebuild for nothing.
  static const Duration _step = Duration(milliseconds: 100);

  BreathingEngine? _engine;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _build();
  }

  @override
  void didUpdateWidget(BreathingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) {
      _build();
      return;
    }
    if (oldWidget.running != widget.running) {
      _follow();
    }
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  void _build() {
    _stop();
    final BreathingConfig? config = widget.config;
    _engine = config == null ? null : BreathingEngine(config: config);
    _follow();
  }

  /// Runs while the session runs and the cycles are not done.
  void _follow() {
    final BreathingEngine? engine = _engine;
    if (engine == null || !widget.running || engine.isComplete) {
      _stop();
      return;
    }
    engine.resume();
    _ticker ??= Timer.periodic(_step, (_) {
      if (!mounted) {
        return;
      }
      setState(() => engine.advance(_step));
      if (engine.isComplete) {
        _stop();
      }
    });
  }

  void _stop() {
    _engine?.pause();
    _ticker?.cancel();
    _ticker = null;
  }

  void _again() {
    _engine?.reset();
    _follow();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final BreathingEngine? engine = _engine;
    final ThemeData theme = Theme.of(context);
    if (engine == null) {
      return Text(
        failureMessage(
          const ContentFailure(code: FailureCode.contentMalformed),
        ),
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium,
      );
    }

    final BreathingSnapshot snapshot = engine.snapshot;
    final bool done = engine.isComplete;
    // The device's own setting, which is what someone who cannot take
    // pulsing motion has turned on.
    final bool stillness = MediaQuery.disableAnimationsOf(context);
    final int secondsLeft = snapshot.remainingInPhase.inMilliseconds <= 0
        ? 0
        : (snapshot.remainingInPhase.inMilliseconds / 1000).ceil();

    final TextTheme text = theme.textTheme;
    final String now = widget.running
        ? BreathingLabelsTr.phase(snapshot.phase)
        : BreathingLabelsTr.paused;

    // What the exercise is followed by: the phase and its seconds, or the
    // end, then the cycle. These stay in view; the circle gives way.
    final Widget words = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (done)
          Text(
            BreathingLabelsTr.allDone,
            textAlign: TextAlign.center,
            style: text.titleLarge,
          )
        else
          Semantics(
            label: BreathingLabelsTr.spoken(now, secondsLeft),
            excludeSemantics: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(now, textAlign: TextAlign.center, style: text.titleLarge),
                Text(
                  '$secondsLeft',
                  textAlign: TextAlign.center,
                  style: text.displaySmall,
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          BreathingLabelsTr.cycle(snapshot.cycle, widget.config!.cycles),
          textAlign: TextAlign.center,
          style: text.bodyLarge,
        ),
        if (done) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: _again,
            child: const Text(BreathingLabelsTr.again),
          ),
        ],
      ],
    );

    // Fills whatever square it is given; the breath scales it inside that.
    final Widget circle = ExcludeSemantics(
      child: Center(
        child: FractionallySizedBox(
          widthFactor: stillness ? 1 : _scale(snapshot),
          heightFactor: stillness ? 1 : _scale(snapshot),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primaryContainer,
            ),
          ),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints room) {
        // The circle takes the height the words leave, up to its largest.
        // Where that is too little for a circle worth drawing, it moves
        // beside the words instead, so they are never pushed out of view.
        final double above = room.maxHeight -
            _wordsHeight(context, text, done: done) -
            AppSpacing.md;
        final Widget layout;
        if (above >= _smallestAbove) {
          layout = Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox.square(
                dimension: math.min(_largest, above),
                child: circle,
              ),
              const SizedBox(height: AppSpacing.md),
              words,
            ],
          );
        } else if (done) {
          // Over, the circle has nothing left to show: the room goes to the
          // words and the button that starts the cycles again.
          layout = words;
        } else {
          layout = Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // The words take the width they need first, so a long one
              // such as "Duraklatıldı" is not broken to make room; the
              // circle has what is left, up to the room's height.
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: _besideLargest,
                    maxHeight: room.maxHeight,
                  ),
                  child: AspectRatio(aspectRatio: 1, child: circle),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              ConstrainedBox(
                // At text sizes where the words alone would be wider than
                // the room, they wrap rather than push the row past it.
                constraints: BoxConstraints(
                  maxWidth: math.max(
                    0,
                    room.maxWidth - AppSpacing.lg - _besideSmallest,
                  ),
                ),
                child: words,
              ),
            ],
          );
        }
        // Scrolls only if the words alone are taller than the room, rather
        // than overflow.
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: room.hasBoundedWidth ? room.maxWidth : 0,
              minHeight: room.hasBoundedHeight ? room.maxHeight : 0,
            ),
            child: Center(child: layout),
          ),
        );
      },
    );
  }

  /// The circle's size where there is room for it.
  static const double _largest = 200;

  /// The smallest circle drawn above the words. Below it, the circle goes
  /// beside them: a smaller circle is hard to follow, and above the words it
  /// would take height they need.
  static const double _smallestAbove = 120;

  /// The largest the circle is drawn beside the words.
  static const double _besideLargest = 140;

  /// The width kept for the circle beside the words, however wide they are.
  static const double _besideSmallest = 48;

  /// How tall the words are at the device's text size: each line is its
  /// style's size, scaled, times the line height the theme sets. It only
  /// decides where the circle goes and how big it is.
  static double _wordsHeight(
    BuildContext context,
    TextTheme text, {
    required bool done,
  }) {
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    double line(TextStyle? style) =>
        scaler.scale(style?.fontSize ?? 14) * (style?.height ?? 1.2);
    return done
        ? line(text.titleLarge) +
            AppSpacing.sm +
            line(text.bodyLarge) +
            AppSpacing.sm +
            // A button is at least as tall as its tap target.
            math.max(48, line(text.labelLarge) + 2 * AppSpacing.sm)
        : line(text.titleLarge) +
            line(text.displaySmall) +
            AppSpacing.sm +
            line(text.bodyLarge);
  }

  /// How wide the circle is, as a fraction: smallest at the end of an
  /// out-breath, largest at the top of an in-breath, still while held.
  static double _scale(BreathingSnapshot snapshot) {
    const double small = 0.55;
    const double large = 1;
    final double progress = math.min(math.max(snapshot.phaseProgress, 0), 1);
    return switch (snapshot.phase) {
      BreathingPhase.inhale => small + (large - small) * progress,
      BreathingPhase.hold => large,
      BreathingPhase.exhale => large - (large - small) * progress,
    };
  }
}
