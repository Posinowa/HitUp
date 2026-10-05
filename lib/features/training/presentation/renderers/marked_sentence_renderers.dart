import 'package:flutter/material.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/failure_code.dart';
import '../../../../core/errors/failure_messages.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/models/models.dart';
import 'exercise_renderer.dart';
import 'pinned_action_layout.dart';

/// Turkish text the emphasis, intonation and pause drills show.
abstract final class MarkedSentenceLabelsTr {
  const MarkedSentenceLabelsTr._();

  /// The pause marker, as it is drawn.
  static const String pauseMark = '/';

  /// The pause marker, read aloud.
  static const String pauseSpoken = 'duraklama';

  /// What the pause marker asks for, with the pause in seconds.
  static String pauseHint(Duration pause) =>
      'Her $pauseMark işaretinde yaklaşık ${_seconds(pause)} saniye dur.';

  /// Moves the emphasis on to the next marked word.
  static const String nextReading = 'Sonraki okuyuş';

  /// Which reading this is, and the word it stresses.
  static String reading(int current, int total, String word) =>
      'Okuyuş $current / $total: "$word" öne çıksın';

  /// A stressed word, read aloud.
  static String stressedSpoken(String word) => '$word, vurgulu';

  /// Each direction, read aloud and in the key.
  static String direction(ContourDirection direction) => switch (direction) {
        ContourDirection.rise => 'yükselen',
        ContourDirection.flat => 'düz',
        ContourDirection.fall => 'düşen',
        ContourDirection.unknown => '',
      };

  /// A word with the direction the voice takes on it, read aloud.
  static String withDirection(String word, ContourDirection direction) =>
      '$word, ${MarkedSentenceLabelsTr.direction(direction)}';

  static String _seconds(Duration pause) {
    final double seconds = pause.inMilliseconds / 1000;
    // Turkish writes a decimal comma: 0,4, not 0.4.
    final String text = seconds == seconds.roundToDouble()
        ? seconds.toInt().toString()
        : seconds.toStringAsFixed(1);
    return text.replaceAll('.', ',');
  }
}

/// A sentence laid out word by word, each word able to carry a mark
/// (HIT-043, HIT-044, HIT-045).
///
/// The three drills that mark a sentence share this, so a stressed word, a
/// pitch arrow and a pause sit in the same layout and wrap the same way on a
/// narrow phone. Every index the content gives is into `TextMarkupConfig.words`,
/// the sentence split on whitespace.
class MarkedSentence extends StatelessWidget {
  /// Creates the sentence from one widget per word, in order.
  const MarkedSentence({required this.words, super.key});

  /// The words, each already marked as its drill needs.
  final List<Widget> words;

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.md,
        children: words,
      );
}

TextStyle? _wordStyle(BuildContext context) =>
    Theme.of(context).textTheme.titleLarge;

Widget _malformed(BuildContext context) => Text(
      failureMessage(const ContentFailure(code: FailureCode.contentMalformed)),
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyMedium,
    );

Widget _scrolling(List<Widget> children) => SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );

/// The pause drill (HIT-045): a mark after each word a pause follows.
class PauseRenderer implements ExerciseRenderer {
  /// Creates the renderer.
  const PauseRenderer();

  @override
  Widget build(BuildContext buildContext, ExerciseRenderContext context) {
    final PauseConfig? config = context.exercise.configAs<PauseConfig>();
    if (config == null) {
      return _malformed(buildContext);
    }
    final ColorScheme colors = Theme.of(buildContext).colorScheme;
    final TextStyle? style = _wordStyle(buildContext);
    final Set<int> pauses = config.pauseAfterWordIndexes.toSet();
    final List<String> words = config.words;

    return _scrolling(<Widget>[
      MarkedSentence(
        words: <Widget>[
          for (int i = 0; i < words.length; i++)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(words[i], style: style),
                if (pauses.contains(i)) ...<Widget>[
                  const SizedBox(width: AppSpacing.sm),
                  Semantics(
                    label: MarkedSentenceLabelsTr.pauseSpoken,
                    excludeSemantics: true,
                    child: Text(
                      MarkedSentenceLabelsTr.pauseMark,
                      style: style?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.lg),
      Text(
        MarkedSentenceLabelsTr.pauseHint(config.pauseDuration),
        textAlign: TextAlign.center,
        style: Theme.of(buildContext).textTheme.bodyMedium,
      ),
    ]);
  }
}

/// The intonation drill (HIT-044): which way the voice moves on each marked
/// word, as an arrow above it.
class IntonationRenderer implements ExerciseRenderer {
  /// Creates the renderer.
  const IntonationRenderer();

  static IconData? _arrow(ContourDirection direction) => switch (direction) {
        ContourDirection.rise => Icons.north_east,
        ContourDirection.flat => Icons.east,
        ContourDirection.fall => Icons.south_east,
        // A direction a newer content file names and this build does not
        // know: the word is shown unmarked rather than with a wrong arrow.
        ContourDirection.unknown => null,
      };

  @override
  Widget build(BuildContext buildContext, ExerciseRenderContext context) {
    final IntonationConfig? config =
        context.exercise.configAs<IntonationConfig>();
    if (config == null) {
      return _malformed(buildContext);
    }
    final ColorScheme colors = Theme.of(buildContext).colorScheme;
    final TextStyle? style = _wordStyle(buildContext);
    final Map<int, ContourDirection> contour = <int, ContourDirection>{
      for (final IntonationPoint point in config.contour)
        if (_arrow(point.direction) != null) point.wordIndex: point.direction,
    };
    final List<String> words = config.words;

    Widget arrow(ContourDirection direction) =>
        Icon(_arrow(direction), color: colors.primary, size: 28);

    return _scrolling(<Widget>[
      MarkedSentence(
        words: <Widget>[
          for (int i = 0; i < words.length; i++)
            Semantics(
              label: contour[i] == null
                  ? words[i]
                  : MarkedSentenceLabelsTr.withDirection(words[i], contour[i]!),
              excludeSemantics: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // Every word keeps the arrow's height, so the line of
                  // words stays level whether a word is marked or not.
                  SizedBox(
                    height: 28,
                    child: contour[i] == null ? null : arrow(contour[i]!),
                  ),
                  Text(words[i], style: style),
                ],
              ),
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.lg),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xs,
        children: <Widget>[
          for (final ContourDirection direction in const <ContourDirection>[
            ContourDirection.rise,
            ContourDirection.flat,
            ContourDirection.fall,
          ])
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ExcludeSemantics(child: arrow(direction)),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  MarkedSentenceLabelsTr.direction(direction),
                  style: Theme.of(buildContext).textTheme.bodyMedium,
                ),
              ],
            ),
        ],
      ),
    ]);
  }
}

/// The emphasis drill (HIT-043): the sentence read once per marked word,
/// each reading stressing the next one.
class EmphasisRenderer implements ExerciseRenderer {
  /// Creates the renderer.
  const EmphasisRenderer();

  @override
  Widget build(BuildContext buildContext, ExerciseRenderContext context) =>
      EmphasisView(config: context.exercise.configAs<EmphasisConfig>());
}

/// One emphasis drill, stepping through its readings.
class EmphasisView extends StatefulWidget {
  /// Creates the view for [config].
  const EmphasisView({required this.config, super.key});

  /// The sentence and the words to stress. Null is a content mistake.
  final EmphasisConfig? config;

  @override
  State<EmphasisView> createState() => _EmphasisViewState();
}

class _EmphasisViewState extends State<EmphasisView> {
  /// Which of the marked words this reading stresses.
  int _reading = 0;

  @override
  void didUpdateWidget(EmphasisView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Another sentence starts at its first reading.
    if (oldWidget.config != widget.config) {
      _reading = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final EmphasisConfig? config = widget.config;
    if (config == null) {
      return _malformed(context);
    }
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextStyle? style = _wordStyle(context);
    final List<String> words = config.words;
    final List<int> marked = config.wordIndexes;
    final int stressed = marked[_reading];

    final List<Widget> sentence = <Widget>[
      Text(
        MarkedSentenceLabelsTr.reading(
          _reading + 1,
          marked.length,
          words[stressed],
        ),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: AppSpacing.md),
      MarkedSentence(
        words: <Widget>[
          for (int i = 0; i < words.length; i++)
            i == stressed
                ? Semantics(
                    label: MarkedSentenceLabelsTr.stressedSpoken(words[i]),
                    excludeSemantics: true,
                    child: Text(
                      words[i],
                      style: style?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.underline,
                        decorationColor: colors.primary,
                        decorationThickness: 2,
                      ),
                    ),
                  )
                : Text(words[i], style: style),
        ],
      ),
    ];
    if (marked.length < 2) {
      return _scrolling(sentence);
    }
    // The sentence scrolls; the next reading stays in view under it.
    return PinnedActionLayout(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: sentence,
      ),
      action: Center(
        child: OutlinedButton(
          onPressed: () =>
              setState(() => _reading = (_reading + 1) % marked.length),
          child: const Text(MarkedSentenceLabelsTr.nextReading),
        ),
      ),
    );
  }
}
