import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/failure_code.dart';
import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/errors/failure_messages.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/providers/training_providers.dart';
import '../../domain/models/models.dart';
import 'exercise_renderer.dart';
import 'pinned_action_layout.dart';

/// The tongue twisters the content ships, loaded once.
final FutureProvider<TongueTwisterLibrary> tongueTwistersProvider =
    FutureProvider<TongueTwisterLibrary>(
  (Ref ref) => ref.watch(curriculumRepositoryProvider).loadTongueTwisters(),
);

/// Turkish text the tongue twister drill shows.
abstract final class TongueTwisterLabelsTr {
  const TongueTwisterLabelsTr._();

  /// Counts one saying of the twister.
  static const String said = 'Söyledim';

  /// Shown once every twister has had its repetitions.
  static const String allDone = 'Hepsi tamam';

  /// Starts the set again from the first twister.
  static const String again = 'Baştan';

  /// Read out while the twisters load.
  static const String loading = 'Tekerlemeler yükleniyor';

  /// Which twister of the set this is.
  static String position(int current, int total) =>
      'Tekerleme $current / $total';

  /// How many times it has been said.
  static String repetition(int done, int total) => 'Tekrar $done / $total';

  /// The difficulty, as the chip shows it.
  static String difficulty(TongueTwisterDifficulty difficulty) =>
      switch (difficulty) {
        TongueTwisterDifficulty.easy => 'Kolay',
        TongueTwisterDifficulty.medium => 'Orta',
        TongueTwisterDifficulty.hard => 'Zor',
        TongueTwisterDifficulty.unknown => '',
      };
}

/// The tongue twister drill (HIT-042).
///
/// The twisters the content names, one at a time, in large text with their
/// difficulty. The user counts each saying; once a twister has its
/// repetitions, the next one follows. There is no scoring: saying it right
/// is the user's call. The count and its button stay in view under the
/// twister however long it is ([PinnedActionLayout]).
class TongueTwisterRenderer implements ExerciseRenderer {
  /// Creates the renderer.
  const TongueTwisterRenderer();

  @override
  Widget build(BuildContext buildContext, ExerciseRenderContext context) =>
      TongueTwisterView(
        config: context.exercise.configAs<TongueTwisterConfig>(),
        running: context.isRunning,
      );
}

/// One tongue twister drill.
class TongueTwisterView extends ConsumerStatefulWidget {
  /// Creates the view for [config].
  const TongueTwisterView({
    required this.config,
    required this.running,
    super.key,
  });

  /// The twisters and how often each is said. Null is a content mistake.
  final TongueTwisterConfig? config;

  /// Whether the session is running. Sayings are not counted while it is
  /// paused.
  final bool running;

  @override
  ConsumerState<TongueTwisterView> createState() => _TongueTwisterViewState();
}

class _TongueTwisterViewState extends ConsumerState<TongueTwisterView> {
  /// Which twister of the set, and how often it has been said.
  int _twister = 0;
  int _said = 0;

  @override
  void didUpdateWidget(TongueTwisterView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) {
      _twister = 0;
      _said = 0;
    }
  }

  void _count(int twisters, int repetitions) {
    setState(() {
      _said++;
      if (_said >= repetitions && _twister < twisters - 1) {
        _twister++;
        _said = 0;
      }
    });
  }

  void _again() => setState(() {
        _twister = 0;
        _said = 0;
      });

  @override
  Widget build(BuildContext context) {
    final TongueTwisterConfig? config = widget.config;
    if (config == null) {
      return _message(
        context,
        const ContentFailure(code: FailureCode.contentMalformed),
      );
    }
    return ref.watch(tongueTwistersProvider).when(
          loading: () => Semantics(
            label: TongueTwisterLabelsTr.loading,
            child: const SizedBox.square(
              dimension: 32,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ),
          error: (Object error, StackTrace _) =>
              _message(context, mapErrorToFailure(error)),
          data: (TongueTwisterLibrary library) {
            final List<TongueTwister> twisters = <TongueTwister>[
              for (final String id in config.tongueTwisterIds)
                if (library.byId(id) case final TongueTwister twister) twister,
            ];
            // Every id must resolve: a set that silently loses a twister
            // looks like a shorter exercise, not the content mistake it is.
            if (twisters.length != config.tongueTwisterIds.length) {
              return _message(
                context,
                ContentFailure(
                  code: FailureCode.contentMalformed,
                  technicalDetail:
                      'Unknown twister in ${config.tongueTwisterIds}',
                ),
              );
            }
            return _drill(context, twisters, config.repetitions);
          },
        );
  }

  Widget _drill(
    BuildContext context,
    List<TongueTwister> twisters,
    int repetitions,
  ) {
    final ThemeData theme = Theme.of(context);
    final TongueTwister twister = twisters[_twister];
    final bool allDone =
        _twister == twisters.length - 1 && _said >= repetitions;
    final String level = TongueTwisterLabelsTr.difficulty(twister.difficulty);

    return PinnedActionLayout(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Wraps, so at the largest text sizes the chip goes under the
          // place rather than past the edge.
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              Text(
                TongueTwisterLabelsTr.position(_twister + 1, twisters.length),
                style: theme.textTheme.bodyMedium,
              ),
              if (level.isNotEmpty)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    child: Text(
                      level,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            twister.text,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium,
          ),
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
                  TongueTwisterLabelsTr.allDone,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
                TextButton(
                  onPressed: _again,
                  child: const Text(TongueTwisterLabelsTr.again),
                ),
              ]
            : <Widget>[
                Text(
                  TongueTwisterLabelsTr.repetition(_said, repetitions),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                ElevatedButton(
                  onPressed: widget.running
                      ? () => _count(twisters.length, repetitions)
                      : null,
                  child: const Text(TongueTwisterLabelsTr.said),
                ),
              ],
      ),
    );
  }

  static Widget _message(BuildContext context, Failure failure) => Text(
        failureMessage(failure),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      );
}
