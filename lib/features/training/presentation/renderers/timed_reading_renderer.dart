import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/failure_code.dart';
import '../../../../core/errors/failure_messages.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/models/models.dart';
import '../../domain/words_per_minute.dart';
import 'exercise_renderer.dart';
import 'pinned_action_layout.dart';

/// The wall clock the reading is timed with.
///
/// Overridable, so a test can move time by hand instead of waiting for it.
final Provider<DateTime Function()> readingClockProvider =
    Provider<DateTime Function()>((Ref ref) => DateTime.now);

/// Turkish text the timed reading shows.
abstract final class TimedReadingLabelsTr {
  const TimedReadingLabelsTr._();

  /// Starts timing.
  static const String start = 'Okumaya başla';

  /// Stops timing.
  static const String done = 'Bitirdim';

  /// Starts again from the top.
  static const String again = 'Tekrar oku';

  /// Shown while the session is paused mid-reading.
  static const String paused = 'Duraklatıldı';

  /// Shown when no time passed between start and stop.
  static const String notMeasured = 'Süre ölçülemedi, bir daha dene.';

  /// The target and the length of the passage.
  static String target(int wordsPerMinute, int words) =>
      'Hedef: dakikada $wordsPerMinute kelime · Metin $words kelime';

  /// The pace measured.
  static String pace(int wordsPerMinute) => 'Dakikada $wordsPerMinute kelime';

  /// How long the reading took, read out.
  static String took(int seconds) => '$seconds saniye';

  /// The pace against the target.
  static String verdict(PaceVerdict verdict) => switch (verdict) {
        PaceVerdict.slow => 'Hedeften yavaş',
        PaceVerdict.onTarget => 'Hedefte',
        PaceVerdict.fast => 'Hedeften hızlı',
      };
}

/// The timed reading exercise (HIT-046).
///
/// Shows the passage, times one reading of it between "start" and "done",
/// and shows the pace in words per minute against the exercise's target
/// (`wordsPerMinute`, `comparePace`). The exercise screen's own controls
/// still complete or skip it.
class TimedReadingRenderer implements ExerciseRenderer {
  /// Creates the renderer.
  const TimedReadingRenderer();

  @override
  Widget build(BuildContext buildContext, ExerciseRenderContext context) =>
      TimedReadingView(
        config: context.exercise.configAs<TimedReadingConfig>(),
        running: context.isRunning,
      );
}

/// Where a reading is.
enum _Phase { ready, reading, finished }

/// One timed reading of a passage.
class TimedReadingView extends ConsumerStatefulWidget {
  /// Creates the view for [config].
  const TimedReadingView({
    required this.config,
    required this.running,
    super.key,
  });

  /// The passage and its target. Null is a content mistake, shown as one.
  final TimedReadingConfig? config;

  /// Whether the session is running. A reading does not count time while
  /// the session is paused.
  final bool running;

  @override
  ConsumerState<TimedReadingView> createState() => _TimedReadingViewState();
}

class _TimedReadingViewState extends ConsumerState<TimedReadingView> {
  _Phase _phase = _Phase.ready;

  /// Time read before the current stretch; a pause ends a stretch.
  Duration _counted = Duration.zero;

  /// When the current stretch began, or null while not counting.
  DateTime? _since;

  /// Redraws the time shown while reading. Measuring does not depend on it.
  Timer? _ticker;

  int? _pace;

  DateTime _now() => ref.read(readingClockProvider)();

  bool get _counting => _since != null;

  Duration get _read =>
      _counted + (_since == null ? Duration.zero : _now().difference(_since!));

  @override
  void didUpdateWidget(TimedReadingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Another passage starts from its start button, with nothing read.
    if (oldWidget.config != widget.config) {
      _stopCounting();
      _phase = _Phase.ready;
      _counted = Duration.zero;
      _pace = null;
      return;
    }
    if (_phase != _Phase.reading || oldWidget.running == widget.running) {
      return;
    }
    if (widget.running) {
      _resumeCounting();
    } else {
      _stopCounting();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() {
      _phase = _Phase.reading;
      _counted = Duration.zero;
      _pace = null;
    });
    if (widget.running) {
      _resumeCounting();
    }
  }

  void _finish() {
    _stopCounting();
    setState(() {
      _phase = _Phase.finished;
      _pace = wordsPerMinute(
        wordCount: widget.config!.wordCount,
        elapsed: _counted,
      );
    });
  }

  void _resumeCounting() {
    if (_counting) {
      return;
    }
    _since = _now();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _stopCounting() {
    final DateTime? since = _since;
    if (since == null) {
      return;
    }
    _counted += _now().difference(since);
    _since = null;
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  Widget build(BuildContext context) {
    final TimedReadingConfig? config = widget.config;
    final TextTheme text = Theme.of(context).textTheme;
    if (config == null) {
      return Text(
        failureMessage(
          const ContentFailure(code: FailureCode.contentMalformed),
        ),
        textAlign: TextAlign.center,
        style: text.bodyMedium,
      );
    }

    final Widget status = switch (_phase) {
      // Its own width, not the room's: on a small phone it sits just above
      // the screen's own full-width Tamamla, and the two must not look alike.
      _Phase.ready => Center(
          child: ElevatedButton(
            onPressed: _start,
            child: const Text(TimedReadingLabelsTr.start),
          ),
        ),
      // Wraps, so at the largest text sizes the button goes under the time
      // rather than past the edge.
      _Phase.reading => Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            Semantics(
              label: TimedReadingLabelsTr.took(_read.inSeconds),
              excludeSemantics: true,
              child: Text(
                _counting || widget.running
                    ? _clock(_read)
                    : TimedReadingLabelsTr.paused,
                style: text.titleLarge,
              ),
            ),
            ElevatedButton(
              onPressed: _finish,
              child: const Text(TimedReadingLabelsTr.done),
            ),
          ],
        ),
      _Phase.finished => Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              _pace == null
                  ? TimedReadingLabelsTr.notMeasured
                  : TimedReadingLabelsTr.pace(_pace!),
              textAlign: TextAlign.center,
              style: text.titleLarge,
            ),
            if (_pace != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(
                TimedReadingLabelsTr.verdict(
                  comparePace(
                    actualWordsPerMinute: _pace,
                    targetWordsPerMinute: config.targetWordsPerMinute,
                  )!,
                ),
                textAlign: TextAlign.center,
                style: text.bodyLarge,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: _start,
              child: const Text(TimedReadingLabelsTr.again),
            ),
          ],
        ),
    };

    final Widget passage = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          TimedReadingLabelsTr.target(
            config.targetWordsPerMinute,
            config.wordCount,
          ),
          textAlign: TextAlign.center,
          style: text.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(config.text, style: text.titleMedium),
      ],
    );

    if (_phase == _Phase.finished) {
      // Read, the result is what counts. It and the passage scroll
      // together, from the bottom, so the result is what is in view first
      // and the passage is above it. Kept in view under a scrolling passage
      // instead, the result and its button are taller than the room on the
      // smallest phone with large text.
      return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints room) =>
            SingleChildScrollView(
          reverse: true,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: room.hasBoundedHeight ? room.maxHeight : 0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                passage,
                const SizedBox(height: AppSpacing.md),
                status,
              ],
            ),
          ),
        ),
      );
    }
    // The passage scrolls; what the reading is timed with stays in view
    // under it, so on a small phone with large text it is never a scroll
    // away while reading.
    return PinnedActionLayout(content: passage, action: status);
  }

  static String _clock(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}
