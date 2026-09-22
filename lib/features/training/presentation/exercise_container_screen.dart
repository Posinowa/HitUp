import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/async_state_views.dart';
import '../../../shared/providers/auth_providers.dart';
import '../../auth/domain/models/auth_user.dart';
import '../../progress/domain/models/calendar_day.dart';
import '../application/finished_day_recorder.dart';
import '../application/training_day_recorder.dart';
import '../application/training_session_controller.dart';
import '../data/pending_day_store.dart';
import '../domain/models/models.dart';
import '../domain/training_session.dart';
import 'exercise_clock.dart';
import 'renderers/exercise_renderer.dart';
import 'renderers/exercise_renderers.dart';

/// Turkish text the exercise screen shows.
///
/// Gathered here rather than written inline, like `FailureLabelsTr`, so every
/// string is findable when the app is translated.
abstract final class ExerciseContainerLabelsTr {
  const ExerciseContainerLabelsTr._();

  /// The button that records the exercise and moves on.
  static const String complete = 'Tamamla';

  /// The button that moves on without recording.
  static const String skip = 'Atla';

  /// The button that puts the session down.
  static const String pause = 'Duraklat';

  /// The button that picks it up again.
  static const String resume = 'Devam et';

  /// Shown while the session is paused.
  static const String paused = 'Duraklatıldı';

  /// The close button's tooltip, and what a screen reader calls it.
  static const String finishTooltip = 'Antrenmanı bitir';

  /// The question before ending a session early.
  static const String finishQuestion = 'Antrenmanı bitirmek istiyor musunuz?';

  /// What ending early keeps, when something was done.
  static const String finishKeeps = 'Tamamladığınız egzersizler kaydedilir.';

  /// What ending early keeps, when nothing was done.
  static const String finishKeepsNothing =
      'Henüz tamamladığınız bir egzersiz yok, bu gün kaydedilmez.';

  /// Confirms ending early.
  static const String finishConfirm = 'Bitir';

  /// Shown once an exercise's own time has run out.
  static const String timeUp = 'Süre doldu';

  /// Shown while the finished day is being recorded.
  static const String saving = 'Kaydediliyor';

  /// The heading once every exercise of the day was completed.
  static const String dayDone = 'Bugünkü antrenman tamam';

  /// The heading once the day was ended early.
  static const String dayEnded = 'Antrenman bitti';

  /// Shown when today had already been recorded before this session.
  static const String alreadySaved = 'Bugünkü antrenmanınız zaten kayıtlıydı.';

  /// Shown when the session ended with nothing completed.
  static const String nothingToSave =
      'Tamamlanan egzersiz olmadığı için bu gün kaydedilmedi.';

  /// Shown when nobody is signed in to record the day for.
  static const String signedOut =
      'Günü kaydetmek için giriş yapmanız gerekiyor.';

  /// Shown when there is nothing to run today.
  static const String emptyDay = 'Bugün çalışılacak egzersiz yok.';

  /// Leaves the finished screen.
  static const String close = 'Kapat';

  /// Where the user is in the day, read aloud.
  static String position(int current, int total) =>
      'Egzersiz $current / $total';

  /// How many exercises were done.
  static String completedCount(int count) => '$count egzersiz tamamlandı';

  /// The streak after today.
  static String streak(int days) => '$days günlük seri';

  /// Time left, read aloud.
  static String secondsLeft(int seconds) => '$seconds saniye kaldı';
}

/// Runs a training day, one exercise at a time (HIT-028).
///
/// The same screen for every kind of exercise. It draws what they share (the
/// title, the instructions, the time, the controls) and hands the rest to the
/// renderer registered for the exercise's presentation type
/// (`exerciseRendererRegistryProvider`). Nothing here looks at an exercise id.
///
/// The session is `TrainingSessionController`'s; this screen asks it for each
/// transition and never changes a session itself. When the session is over,
/// the screen records the day with `FinishedDayRecorder` and shows what was
/// recorded.
class ExerciseContainerScreen extends ConsumerStatefulWidget {
  /// Creates the screen for [today].
  ///
  /// A session already in hand for the same day, one restored from the
  /// device, is carried on with; anything else is replaced by a new session.
  const ExerciseContainerScreen({
    required this.today,
    this.now = DateTime.now,
    super.key,
  });

  /// The day to run.
  final TodayTraining today;

  /// The wall clock, for the date the day is recorded under.
  final DateTime Function() now;

  @override
  ConsumerState<ExerciseContainerScreen> createState() =>
      _ExerciseContainerScreenState();
}

/// Where recording the finished day is.
enum _Outcome { saving, saved, failed, nothingToSave, signedOut }

class _ExerciseContainerScreenState
    extends ConsumerState<ExerciseContainerScreen> {
  final ExerciseClock _clock = ExerciseClock();
  late final Map<String, Exercise> _exercises = <String, Exercise>{
    for (final Exercise exercise in widget.today.exercises)
      exercise.id: exercise,
  };

  /// The day's ids in order. A list, not [_exercises]' keys: a day that runs
  /// the same exercise twice has it twice here and once there.
  late final List<String> _ids = <String>[
    for (final Exercise exercise in widget.today.exercises) exercise.id,
  ];
  late final AppLifecycleListener _lifecycle;

  /// The session as it ended, once it has. From then on the screen shows the
  /// end of the day, whatever the controller holds.
  TrainingSession? _finished;

  /// The date the day ended on. Taken when it ended, not when the recording
  /// is retried, so a day finished before midnight is not recorded as the
  /// next one.
  CalendarDay? _finishedOn;

  /// The time the session was worked, as it stood when it ended.
  Duration _worked = Duration.zero;

  _Outcome? _outcome;
  TrainingDayRecord? _record;
  Failure? _failure;

  @override
  void initState() {
    super.initState();
    // Leaving the app pauses the session, so the time away is not counted
    // as training and the exercise is still there on return.
    _lifecycle = AppLifecycleListener(onHide: _pauseIfRunning);
    if (!widget.today.isEmpty) {
      // After the first frame: starting a session changes a provider, which
      // is not allowed while the tree is building.
      WidgetsBinding.instance.addPostFrameCallback((_) => _open());
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _clock.dispose();
    super.dispose();
  }

  TrainingSessionController get _controller =>
      ref.read(trainingSessionControllerProvider.notifier);

  /// Whether [session] is a run of [TodayTraining] this screen was given.
  bool _isToday(TrainingSession? session) =>
      session != null &&
      session.programDay == widget.today.programDay &&
      listEquals(session.exerciseIds, _ids);

  void _open() {
    if (!mounted) {
      return;
    }
    final TrainingSession? inHand = ref.read(
      trainingSessionControllerProvider,
    );
    _sync(_isToday(inHand) ? inHand! : _controller.begin(widget.today));
  }

  /// Brings the clock, and the end of the day, in line with [session].
  void _sync(TrainingSession? session) {
    if (session == null || _finished != null || !_isToday(session)) {
      return;
    }
    if (session.status == SessionStatus.completed) {
      _clock.stop();
      setState(() {
        _finished = session;
        _finishedOn = CalendarDay.fromDateTime(widget.now());
        _worked = _clock.elapsed;
      });
      // Not now: this runs while the controller is still inside the
      // transition, before it has saved the finished session. Clearing the
      // session from here would race that save and could lose to it.
      scheduleMicrotask(() => unawaited(_recordDay()));
      return;
    }
    _clock.showExercise(
      session.currentIndex,
      _exercises[session.currentExerciseId]!.duration,
    );
    if (session.status == SessionStatus.inProgress) {
      _clock.run();
    } else {
      _clock.stop();
    }
  }

  Future<void> _recordDay() async {
    if (!mounted) {
      return;
    }
    final TrainingSession session = _finished!;
    // Everything from `ref` is read before the first await: the screen may be
    // gone by the time the recording ends, and the recording, and clearing
    // the session after it, go on regardless.
    final TrainingSessionController controller = _controller;
    final FinishedDayRecorder recorder = ref.read(finishedDayRecorderProvider);

    if (session.completedExerciseIds.isEmpty) {
      // Not a training day, and the recorder refuses one. Nothing to keep.
      setState(() => _outcome = _Outcome.nothingToSave);
      await _discard(controller);
      return;
    }
    // The account as it is now, waited for rather than read: a value still
    // loading is not a signed-out user. Taken only on the path that awaits
    // it, so a failing auth stream cannot leave an error nobody handles.
    final Future<AuthUser?> account = ref.read(authStateChangesProvider.future);
    setState(() {
      _outcome = _Outcome.saving;
      _failure = null;
    });
    try {
      final String? uid = (await account)?.uid;
      if (uid == null) {
        // The session stays on the device; nothing is written under a
        // guessed account.
        if (mounted) {
          setState(() => _outcome = _Outcome.signedOut);
        }
        return;
      }
      // Kept on the device until it is recorded, so closing the app before
      // then does not lose the day (`FinishedDayRecorder`).
      final TrainingDayRecord record = await recorder.record(
        PendingDay(
          uid: uid,
          session: session,
          date: _finishedOn!,
          elapsed: _worked,
        ),
      );
      // Cleared only once recorded: until then the saved copy is the safety
      // net (`TRAINING.md`).
      await _discard(controller);
      if (mounted) {
        setState(() {
          _outcome = _Outcome.saved;
          _record = record;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _outcome = _Outcome.failed;
          _failure = mapErrorToFailure(error);
        });
      }
    }
  }

  /// Clears the finished session. A failure costs a stale copy on the
  /// device, which is never offered for resume, so it is logged and dropped.
  Future<void> _discard(TrainingSessionController controller) async {
    try {
      await controller.discard();
    } catch (error) {
      debugPrint('HIT-028: could not clear the finished session. $error');
    }
  }

  // Each action asks the session first. Two taps in one frame arrive before
  // the buttons rebuild, and a transition the session no longer allows would
  // throw.

  void _complete() {
    if (ref.read(trainingSessionControllerProvider)?.canAdvance ?? false) {
      _controller.completeCurrentExercise();
    }
  }

  void _skip() {
    if (ref.read(trainingSessionControllerProvider)?.canAdvance ?? false) {
      _controller.skipCurrentExercise();
    }
  }

  void _pauseIfRunning() {
    if (ref.read(trainingSessionControllerProvider)?.canPause ?? false) {
      _controller.pause();
    }
  }

  void _resume() {
    if (ref.read(trainingSessionControllerProvider)?.canResume ?? false) {
      _controller.resume();
    }
  }

  /// Asks before ending the session early. The clock stands still while the
  /// question is open.
  Future<void> _confirmFinish() async {
    final TrainingSession? session = ref.read(
      trainingSessionControllerProvider,
    );
    if (session == null || !session.canFinish || _finished != null) {
      return;
    }
    _clock.stop();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text(ExerciseContainerLabelsTr.finishQuestion),
        content: Text(
          session.completedExerciseIds.isEmpty
              ? ExerciseContainerLabelsTr.finishKeepsNothing
              : ExerciseContainerLabelsTr.finishKeeps,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(ExerciseContainerLabelsTr.resume),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(ExerciseContainerLabelsTr.finishConfirm),
          ),
        ],
      ),
    );
    if (!mounted) {
      return;
    }
    final TrainingSession? now = ref.read(trainingSessionControllerProvider);
    if (confirmed ?? false) {
      if (now != null && now.canFinish) {
        _controller.finish();
      }
    } else if (now?.status == SessionStatus.inProgress) {
      _clock.run();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Kept loaded while the day runs. The controller reads the account off
    // it to count each completion (HIT-052), and a provider nobody listens
    // to is still loading when first read.
    ref.watch(authStateChangesProvider);
    ref.listen<TrainingSession?>(
      trainingSessionControllerProvider,
      (TrainingSession? previous, TrainingSession? next) => _sync(next),
    );

    if (widget.today.isEmpty) {
      return const Scaffold(
        body: EmptyView(message: ExerciseContainerLabelsTr.emptyDay),
      );
    }
    final TrainingSession? finished = _finished;
    if (finished != null) {
      return _DayEnd(
        session: finished,
        outcome: _outcome,
        record: _record,
        failure: _failure,
        onRetry: () => unawaited(_recordDay()),
      );
    }
    final TrainingSession? session = ref.watch(
      trainingSessionControllerProvider,
    );
    if (!_isToday(session) || session!.status == SessionStatus.completed) {
      return const Scaffold(body: LoadingView());
    }
    final Exercise exercise = _exercises[session.currentExerciseId]!;

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          unawaited(_confirmFinish());
        }
      },
      child: _ExerciseView(
        session: session,
        exercise: exercise,
        renderer: ref
            .watch(exerciseRendererRegistryProvider)
            .rendererFor(exercise.presentationType),
        clock: _clock,
        onComplete: _complete,
        onSkip: _skip,
        onPause: _pauseIfRunning,
        onResume: _resume,
        onClose: () => unawaited(_confirmFinish()),
      ),
    );
  }
}

/// The chrome every exercise shares, around its renderer.
class _ExerciseView extends StatelessWidget {
  const _ExerciseView({
    required this.session,
    required this.exercise,
    required this.renderer,
    required this.clock,
    required this.onComplete,
    required this.onSkip,
    required this.onPause,
    required this.onResume,
    required this.onClose,
  });

  final TrainingSession session;
  final Exercise exercise;
  final ExerciseRenderer renderer;
  final ExerciseClock clock;
  final VoidCallback onComplete;
  final VoidCallback onSkip;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final int position = session.currentIndex + 1;
    final bool running = session.status == SessionStatus.inProgress;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: ExerciseContainerLabelsTr.finishTooltip,
          onPressed: onClose,
        ),
        title: Semantics(
          label: ExerciseContainerLabelsTr.position(
            position,
            session.exerciseCount,
          ),
          excludeSemantics: true,
          child: Text('$position / ${session.exerciseCount}'),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: session.currentIndex / session.exerciseCount,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(exercise.title, style: text.headlineMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(exercise.instructions, style: text.bodyLarge),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: ListenableBuilder(
                  listenable: clock,
                  builder: (BuildContext context, Widget? _) => Center(
                    // Keyed by position, so a renderer with state of its own
                    // starts fresh on the next exercise, even one of the
                    // same type.
                    child: KeyedSubtree(
                      key: ValueKey<int>(session.currentIndex),
                      child: renderer.build(
                        context,
                        ExerciseRenderContext(
                          exercise: exercise,
                          remaining: clock.remaining,
                          isRunning: running,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _TimeLine(clock: clock, paused: !running),
              const SizedBox(height: AppSpacing.md),
              if (running)
                Row(
                  children: <Widget>[
                    TextButton(
                      onPressed: onSkip,
                      child: const Text(ExerciseContainerLabelsTr.skip),
                    ),
                    const Spacer(),
                    OutlinedButton(
                      onPressed: onPause,
                      child: const Text(ExerciseContainerLabelsTr.pause),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ElevatedButton(
                      onPressed: onComplete,
                      child: const Text(ExerciseContainerLabelsTr.complete),
                    ),
                  ],
                )
              else
                ElevatedButton(
                  onPressed: onResume,
                  child: const Text(ExerciseContainerLabelsTr.resume),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The time left on the exercise, or that it is paused or over.
class _TimeLine extends StatelessWidget {
  const _TimeLine({required this.clock, required this.paused});

  final ExerciseClock clock;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: clock,
      builder: (BuildContext context, Widget? _) {
        final int seconds = clock.remaining.inSeconds;
        final String shown = paused
            ? ExerciseContainerLabelsTr.paused
            : clock.isTimeUp
                ? ExerciseContainerLabelsTr.timeUp
                : '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
        return Semantics(
          label: paused || clock.isTimeUp
              ? shown
              : ExerciseContainerLabelsTr.secondsLeft(seconds),
          excludeSemantics: true,
          child: Text(
            shown,
            textAlign: TextAlign.center,
            style: text.titleLarge,
          ),
        );
      },
    );
  }
}

/// The end of the day: what was done, and recording it.
///
/// What was done is shown at once, because the device already knows it. The
/// recording is not waited for: offline, its first write does not complete
/// until the device is back online (`USER_PROGRESS.md`), and a summary held
/// behind a spinner until then would tell the user their training was lost.
/// Only what the account decides, the streak, waits for it.
class _DayEnd extends StatelessWidget {
  const _DayEnd({
    required this.session,
    required this.outcome,
    required this.record,
    required this.failure,
    required this.onRetry,
  });

  final TrainingSession session;
  final _Outcome? outcome;
  final TrainingDayRecord? record;
  final Failure? failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final TrainingDayRecord? done = record;

    Widget line(String value, TextStyle? style) =>
        Text(value, textAlign: TextAlign.center, style: style);

    final List<Widget> status = switch (outcome) {
      null || _Outcome.saving => <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: AppSpacing.sm),
              line(ExerciseContainerLabelsTr.saving, text.bodyMedium),
            ],
          ),
        ],
      _Outcome.saved => <Widget>[
          if (done?.streak != null)
            line(
              ExerciseContainerLabelsTr.streak(done!.streak!.currentStreak),
              text.bodyLarge,
            ),
          if (done != null && !done.wasRecorded) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            line(ExerciseContainerLabelsTr.alreadySaved, text.bodyMedium),
          ],
        ],
      _Outcome.failed => <Widget>[
          ErrorView(failure: failure!, onRetry: onRetry),
        ],
      _Outcome.nothingToSave => <Widget>[
          line(ExerciseContainerLabelsTr.nothingToSave, text.bodyLarge),
        ],
      _Outcome.signedOut => <Widget>[
          line(ExerciseContainerLabelsTr.signedOut, text.bodyLarge),
        ],
    };

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    line(
                      session.isFullyCompleted
                          ? ExerciseContainerLabelsTr.dayDone
                          : ExerciseContainerLabelsTr.dayEnded,
                      text.headlineMedium,
                    ),
                    if (session.completedExerciseIds.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      line(
                        ExerciseContainerLabelsTr.completedCount(
                          session.completedExerciseIds.length,
                        ),
                        text.bodyLarge,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    ...status,
                  ],
                ),
              ),
              // Always there: leaving does not stop a recording in flight.
              ElevatedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text(ExerciseContainerLabelsTr.close),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
