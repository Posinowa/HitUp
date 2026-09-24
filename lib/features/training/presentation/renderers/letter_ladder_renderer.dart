import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/failure_code.dart';
import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/errors/failure_messages.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/providers/training_providers.dart';
import '../../domain/models/models.dart';
import 'exercise_renderer.dart';
import 'pinned_action_layout.dart';

/// The letter ladders the content ships, loaded once.
final FutureProvider<LetterLadderLibrary> letterLaddersProvider =
    FutureProvider<LetterLadderLibrary>(
  (Ref ref) => ref.watch(curriculumRepositoryProvider).loadLetters(),
);

/// A rung of the ladder: the sound itself, then syllables, then words.
enum LetterRung {
  /// The letter on its own.
  sound,

  /// The syllables the content lists.
  syllables,

  /// The words the content lists.
  words,
}

/// Turkish text the letter ladder shows.
abstract final class LetterLadderLabelsTr {
  const LetterLadderLabelsTr._();

  /// Counts one saying of the rung.
  static const String said = 'Söyledim';

  /// Shown once every rung has had its repetitions.
  static const String allDone = 'Merdiven tamam';

  /// Starts the ladder again from the sound.
  static const String again = 'Baştan';

  /// Read out while the ladders load.
  static const String loading = 'Harf yükleniyor';

  /// What each rung is called.
  static String rung(LetterRung rung) => switch (rung) {
        LetterRung.sound => 'Ses',
        LetterRung.syllables => 'Heceler',
        LetterRung.words => 'Kelimeler',
      };

  /// Which rung of the ladder this is.
  static String step(int current, int total) => 'Basamak $current / $total';

  /// How many times it has been said.
  static String repetition(int done, int total) => 'Tekrar $done / $total';
}

/// The letter ladder drill (HIT-038).
///
/// The Turkish letter the content names, worked through in rungs: the sound,
/// then its syllables, then its words, each said as many times as the
/// content asks. The ladder and its note come from `letters.json`; nothing
/// here knows a letter. The count and its button stay in view under the
/// rung ([PinnedActionLayout]).
class LetterLadderRenderer implements ExerciseRenderer {
  /// Creates the renderer.
  const LetterLadderRenderer();

  @override
  Widget build(BuildContext buildContext, ExerciseRenderContext context) =>
      LetterLadderView(
        config: context.exercise.configAs<LetterConfig>(),
        running: context.isRunning,
      );
}

/// One letter ladder.
class LetterLadderView extends ConsumerStatefulWidget {
  /// Creates the view for [config].
  const LetterLadderView({
    required this.config,
    required this.running,
    super.key,
  });

  /// Which letter, and how often each rung is said. Null is a content
  /// mistake.
  final LetterConfig? config;

  /// Whether the session is running. Sayings are not counted while it is
  /// paused.
  final bool running;

  @override
  ConsumerState<LetterLadderView> createState() => _LetterLadderViewState();
}

class _LetterLadderViewState extends ConsumerState<LetterLadderView> {
  int _rung = 0;
  int _said = 0;

  @override
  void didUpdateWidget(LetterLadderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) {
      _rung = 0;
      _said = 0;
    }
  }

  void _count(List<LetterRung> rungs, int repetitions) {
    setState(() {
      _said++;
      if (_said >= repetitions && _rung < rungs.length - 1) {
        _rung++;
        _said = 0;
      }
    });
  }

  void _again() => setState(() {
        _rung = 0;
        _said = 0;
      });

  @override
  Widget build(BuildContext context) {
    final LetterConfig? config = widget.config;
    if (config == null) {
      return _message(
        context,
        const ContentFailure(code: FailureCode.contentMalformed),
      );
    }
    return ref.watch(letterLaddersProvider).when(
          loading: () => Semantics(
            label: LetterLadderLabelsTr.loading,
            child: const SizedBox.square(
              dimension: 32,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ),
          error: (Object error, StackTrace _) =>
              _message(context, mapErrorToFailure(error)),
          data: (LetterLadderLibrary library) {
            final LetterLadder? ladder = library.byKey(config.letterKey);
            if (ladder == null) {
              return _message(
                context,
                ContentFailure(
                  code: FailureCode.contentMalformed,
                  technicalDetail: 'No letter "${config.letterKey}"',
                ),
              );
            }
            return _ladder(context, ladder, config.repetitions);
          },
        );
  }

  Widget _ladder(
    BuildContext context,
    LetterLadder ladder,
    int repetitions,
  ) {
    final ThemeData theme = Theme.of(context);
    // A rung with nothing in it is skipped: a letter whose content carries
    // no words yet is a shorter ladder, not an empty screen.
    final List<LetterRung> rungs = <LetterRung>[
      LetterRung.sound,
      if (ladder.syllables.isNotEmpty) LetterRung.syllables,
      if (ladder.words.isNotEmpty) LetterRung.words,
    ];
    final LetterRung rung = rungs[_rung];
    final bool allDone = _rung == rungs.length - 1 && _said >= repetitions;
    final String? notes = ladder.notes;

    return PinnedActionLayout(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '${LetterLadderLabelsTr.rung(rung)} · '
            '${LetterLadderLabelsTr.step(_rung + 1, rungs.length)}',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          switch (rung) {
            LetterRung.sound => Column(
                children: <Widget>[
                  Text(
                    ladder.letter,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displaySmall,
                  ),
                  if (notes != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      notes,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            LetterRung.syllables => _row(context, ladder.syllables),
            LetterRung.words => _row(context, ladder.words),
          },
        ],
      ),
      // The count beside its button, a line lower where they do not fit
      // side by side: every line kept here is room left for the content.
      action: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        children: allDone
            ? <Widget>[
                Text(
                  LetterLadderLabelsTr.allDone,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
                TextButton(
                  onPressed: _again,
                  child: const Text(LetterLadderLabelsTr.again),
                ),
              ]
            : <Widget>[
                Text(
                  LetterLadderLabelsTr.repetition(_said, repetitions),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                ElevatedButton(
                  onPressed:
                      widget.running ? () => _count(rungs, repetitions) : null,
                  child: const Text(LetterLadderLabelsTr.said),
                ),
              ],
      ),
    );
  }

  static Widget _row(BuildContext context, List<String> items) => Wrap(
        alignment: WrapAlignment.center,
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          for (final String item in items)
            Text(item, style: Theme.of(context).textTheme.headlineMedium),
        ],
      );

  static Widget _message(BuildContext context, Failure failure) => Text(
        failureMessage(failure),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      );
}
