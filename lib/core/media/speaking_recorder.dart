import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where the recording of a speaking challenge hangs from (HIT-048).
///
/// The speaking challenge tells it when the speaking starts, when the
/// session pauses and resumes it, and how it ends. Nothing is recorded yet:
/// [speakingRecorderProvider] gives a [SilentSpeakingRecorder] until local
/// recording (HIT-050) overrides it with one that records.
///
/// Every call returns at once and never throws. A recorder that cannot
/// record, for want of a microphone or a permission, deals with that
/// itself: the challenge runs the same either way.
abstract interface class SpeakingRecorder {
  /// The speaking has begun.
  void start();

  /// The session was paused mid-speech.
  void pause();

  /// The session carries on after [pause].
  void resume();

  /// The speaking is over, ended early or out of time. What was recorded is
  /// kept.
  void stop();

  /// The speaking was left before its end: another challenge took its place,
  /// or the screen went. What was recorded is not kept.
  void cancel();
}

/// A [SpeakingRecorder] that records nothing.
class SilentSpeakingRecorder implements SpeakingRecorder {
  /// Creates the recorder.
  const SilentSpeakingRecorder();

  @override
  void start() {}

  @override
  void pause() {}

  @override
  void resume() {}

  @override
  void stop() {}

  @override
  void cancel() {}
}

/// The app's speaking recorder: silent until recording lands (HIT-050).
final Provider<SpeakingRecorder> speakingRecorderProvider =
    Provider<SpeakingRecorder>((Ref ref) => const SilentSpeakingRecorder());
