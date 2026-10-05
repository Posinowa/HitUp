import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/analytics_event.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/errors/failure_code.dart';
import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/errors/failure_messages.dart';
import '../../../../core/media/speaking_recorder.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/preparation_countdown.dart';
import '../../../../shared/providers/analytics_providers.dart';
import '../../../../shared/providers/training_providers.dart';
import '../../domain/models/models.dart';
import 'exercise_renderer.dart';
import 'pinned_action_layout.dart';

/// The speaking challenges the content ships, loaded once.
final FutureProvider<SpeakingChallengeLibrary> speakingChallengesProvider =
    FutureProvider<SpeakingChallengeLibrary>(
  (Ref ref) => ref.watch(curriculumRepositoryProvider).loadSpeakingChallenges(),
);

/// Turkish text the speaking challenge shows.
abstract final class SpeakingChallengeLabelsTr {
  const SpeakingChallengeLabelsTr._();

  /// Starts the preparation.
  static const String prepare = 'Hazırlan';

  /// Shown over the preparation countdown.
  static const String preparing = 'Ne anlatacağını düşün';

  /// Ends the speaking early.
  static const String done = 'Bitirdim';

  /// Starts the challenge again.
  static const String again = 'Tekrar';

  /// Shown once the speaking is over.
  static const String finished = 'Konuşma bitti';

  /// Shown while the session is paused mid-speech.
  static const String paused = 'Duraklatıldı';

  /// Read out while the challenges load.
  static const String loading = 'Görev yükleniyor';

  /// The two phases and their lengths.
  static String timing(int preparation, int speaking) =>
      'Hazırlık $preparation sn · Konuşma $speaking sn';

  /// Time left to speak, read aloud.
  static String secondsLeft(int seconds) => 'Konuşma: $seconds saniye kaldı';
}

/// The speaking challenge (HIT-048).
///
/// The prompt, then the shared preparation countdown, then a timed speaking
/// phase, which the user can end early. The content names a challenge by id
/// (`speakingChallenge.challengeId`); its prompt and both lengths come from
/// `speaking_challenges.json`.
///
/// The speaking phase tells the [SpeakingRecorder] when it starts, pauses,
/// resumes and ends, which is where recording (HIT-050) will hang from.
/// Nothing is recorded yet.
///
/// It is reported as `speaking_challenge_started` when the speaking begins,
/// and as `speaking_challenge_completed` when it ends, by its time or by the
/// user, with the seconds the clock ran (`ANALYTICS.md`). A speaking left
/// before its end, for another challenge or another screen, is not counted
/// as completed.
class SpeakingChallengeRenderer implements ExerciseRenderer {
  /// Creates the renderer.
  const SpeakingChallengeRenderer();

  @override
  Widget build(BuildContext buildContext, ExerciseRenderContext context) =>
      SpeakingChallengeView(
        config: context.exercise.configAs<SpeakingChallengeConfig>(),
        running: context.isRunning,
      );
}

/// Where a challenge is.
enum _Phase { ready, preparing, speaking, finished }

/// One speaking challenge.
class SpeakingChallengeView extends ConsumerStatefulWidget {
  /// Creates the view for [config].
  const SpeakingChallengeView({
    required this.config,
    required this.running,
    super.key,
  });

  /// Which challenge. Null, or an id the challenges do not have, is a
  /// content mistake.
  final SpeakingChallengeConfig? config;

  /// Whether the session is running.
  final bool running;

  @override
  ConsumerState<SpeakingChallengeView> createState() =>
      _SpeakingChallengeViewState();
}

class _SpeakingChallengeViewState extends ConsumerState<SpeakingChallengeView> {
  _Phase _phase = _Phase.ready;
  int _left = 0;
  Timer? _ticker;

  /// The challenge being spoken, for the report when it ends.
  SpeakingChallenge? _speaking;

  /// Read once: the speaking may have to be cancelled from [dispose], where
  /// `ref` can no longer be used.
  late final SpeakingRecorder _recorder;

  @override
  void initState() {
    super.initState();
    _recorder = ref.read(speakingRecorderProvider);
  }

  @override
  void didUpdateWidget(SpeakingChallengeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Another challenge starts again from its prompt.
    if (oldWidget.config != widget.config) {
      if (_phase == _Phase.speaking) {
        _recorder.cancel();
      }
      _stopTicking();
      _phase = _Phase.ready;
      return;
    }
    if (oldWidget.running == widget.running) {
      return;
    }
    if (!widget.running && _phase == _Phase.preparing) {
      // The shared countdown does not pause, by design: a preparation
      // broken off is not half done. It starts again from the prompt.
      _phase = _Phase.ready;
    } else if (_phase == _Phase.speaking) {
      if (widget.running) {
        _tick();
        _recorder.resume();
      } else {
        _stopTicking();
        _recorder.pause();
      }
    }
  }

  @override
  void dispose() {
    if (_phase == _Phase.speaking) {
      _recorder.cancel();
    }
    _stopTicking();
    super.dispose();
  }

  void _prepare() => setState(() => _phase = _Phase.preparing);

  void _speak(SpeakingChallenge challenge) {
    if (!mounted || _phase != _Phase.preparing) {
      return;
    }
    setState(() {
      _phase = _Phase.speaking;
      _speaking = challenge;
      _left = challenge.durationSeconds;
    });
    _recorder.start();
    _log(
      AnalyticsEvent.speakingChallengeStarted(
        speakingChallengeId: challenge.id,
      ),
    );
    if (widget.running) {
      _tick();
    }
  }

  /// Sends [event] without waiting for it (`ANALYTICS.md`).
  void _log(AnalyticsEvent event) =>
      unawaited(ref.read(analyticsServiceProvider).log(event));

  void _tick() {
    if (_ticker != null) {
      return;
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() => _left--);
      if (_left <= 0) {
        _finish();
      }
    });
  }

  void _stopTicking() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _finish() {
    _stopTicking();
    _recorder.stop();
    final SpeakingChallenge? challenge = _speaking;
    if (challenge != null) {
      // The seconds the clock ran: time paused is not time spoken.
      _log(
        AnalyticsEvent.speakingChallengeCompleted(
          speakingChallengeId: challenge.id,
          durationSeconds: challenge.durationSeconds - _left,
        ),
      );
    }
    setState(() {
      _phase = _Phase.finished;
      _left = 0;
    });
  }

  void _again() => setState(() => _phase = _Phase.ready);

  @override
  Widget build(BuildContext context) {
    final SpeakingChallengeConfig? config = widget.config;
    if (config == null) {
      return _message(
        context,
        const ContentFailure(code: FailureCode.contentMalformed),
      );
    }
    return ref.watch(speakingChallengesProvider).when(
          loading: () => Semantics(
            label: SpeakingChallengeLabelsTr.loading,
            child: const SizedBox.square(
              dimension: 32,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ),
          error: (Object error, StackTrace _) =>
              _message(context, mapErrorToFailure(error)),
          data: (SpeakingChallengeLibrary library) {
            final SpeakingChallenge? challenge =
                library.byId(config.challengeId);
            if (challenge == null) {
              return _message(
                context,
                ContentFailure(
                  code: FailureCode.contentMalformed,
                  technicalDetail: 'No challenge "${config.challengeId}"',
                ),
              );
            }
            return _challenge(context, challenge);
          },
        );
  }

  Widget _challenge(BuildContext context, SpeakingChallenge challenge) {
    final TextTheme text = Theme.of(context).textTheme;
    final Widget action = switch (_phase) {
      _Phase.ready => Center(
          child: ElevatedButton(
            onPressed: _prepare,
            child: const Text(SpeakingChallengeLabelsTr.prepare),
          ),
        ),
      _Phase.preparing => PreparationCountdown(
          seconds: challenge.preparationSeconds,
          label: SpeakingChallengeLabelsTr.preparing,
          onCompleted: () => _speak(challenge),
          onCancelled: _again,
        ),
      // The time beside its button, a line lower where they do not fit
      // side by side: every line kept here is room left for the prompt.
      _Phase.speaking => Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            Semantics(
              label: SpeakingChallengeLabelsTr.secondsLeft(_left),
              excludeSemantics: true,
              child: Text(
                widget.running
                    ? _clock(_left)
                    : SpeakingChallengeLabelsTr.paused,
                style: text.displaySmall,
              ),
            ),
            ElevatedButton(
              onPressed: _finish,
              child: const Text(SpeakingChallengeLabelsTr.done),
            ),
          ],
        ),
      _Phase.finished => Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              SpeakingChallengeLabelsTr.finished,
              textAlign: TextAlign.center,
              style: text.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: _again,
              child: const Text(SpeakingChallengeLabelsTr.again),
            ),
          ],
        ),
    };

    // Preparing, the countdown runs by itself and the prompt is what the
    // time is for, so the two scroll together, the prompt first. The shared
    // countdown, with its Vazgeç, is too tall to keep in view under the
    // prompt on a small phone.
    if (_phase == _Phase.preparing) {
      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              challenge.prompt,
              textAlign: TextAlign.center,
              style: text.titleMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            action,
          ],
        ),
      );
    }
    // Otherwise the prompt scrolls, and what the phase is worked with stays
    // in view under it, on a small phone with large text too.
    return PinnedActionLayout(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            challenge.prompt,
            textAlign: TextAlign.center,
            style: text.titleMedium,
          ),
          if (_phase == _Phase.ready) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              SpeakingChallengeLabelsTr.timing(
                challenge.preparationSeconds,
                challenge.durationSeconds,
              ),
              textAlign: TextAlign.center,
              style: text.bodyMedium,
            ),
          ],
        ],
      ),
      action: action,
    );
  }

  static Widget _message(BuildContext context, Failure failure) => Text(
        failureMessage(failure),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      );

  static String _clock(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}
