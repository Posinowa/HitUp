import 'package:flutter/foundation.dart';

import 'content_envelope.dart';
import 'json_reader.dart';

/// One open speaking task.
///
/// A `speakingChallenge` exercise names one of these by id through
/// [SpeakingChallengeConfig.challengeId].
@immutable
class SpeakingChallenge {
  /// Creates a challenge.
  const SpeakingChallenge({
    required this.id,
    required this.title,
    required this.prompt,
    required this.durationSeconds,
    required this.preparationSeconds,
  });

  /// Parses one challenge.
  factory SpeakingChallenge.fromJson(Map<String, dynamic> json) {
    final String id = json.requireString('id', ownerId: '<speakingChallenge>');

    return SpeakingChallenge(
      id: id,
      title: json.requireString('title', ownerId: id),
      prompt: json.requireString('prompt', ownerId: id),
      durationSeconds: json.requireIntAtLeast(
        'durationSeconds',
        1,
        ownerId: id,
      ),
      // Zero is allowed and means "start straight away". A missing value is
      // not: silence about preparation time is how one challenge ends up
      // starting instantly while its neighbour counts down.
      preparationSeconds: json.requireIntAtLeast(
        'preparationSeconds',
        0,
        ownerId: id,
      ),
    );
  }

  /// Stable identifier. Never renamed, never reused.
  final String id;

  /// Short name for the task, shown in lists.
  final String title;

  /// The question or instruction the user speaks to.
  final String prompt;

  /// How long the user speaks for.
  final int durationSeconds;

  /// Quiet time before speaking starts, for reading the prompt.
  ///
  /// This is what the shared preparation countdown runs for.
  final int preparationSeconds;

  /// How long the whole challenge occupies, preparation included.
  ///
  /// A day's estimated duration is built from this rather than from
  /// [durationSeconds], because the preparation is time the user spends in the
  /// exercise too.
  int get totalSeconds => preparationSeconds + durationSeconds;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpeakingChallenge &&
          other.id == id &&
          other.title == title &&
          other.prompt == prompt &&
          other.durationSeconds == durationSeconds &&
          other.preparationSeconds == preparationSeconds;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        prompt,
        durationSeconds,
        preparationSeconds,
      );

  @override
  String toString() => 'SpeakingChallenge($id, ${durationSeconds}s '
      'after ${preparationSeconds}s)';
}

/// `assets/content/speaking_challenges.json`, parsed.
///
/// Reading the bytes off the asset bundle is the repository's job, which is why
/// nothing here touches `rootBundle`.
@immutable
class SpeakingChallengeLibrary {
  /// Creates a library.
  const SpeakingChallengeLibrary({
    required this.envelope,
    required this.challenges,
  });

  /// Parses the whole file.
  factory SpeakingChallengeLibrary.fromJson(Map<String, dynamic> json) {
    const String fileName = 'speaking_challenges.json';

    final ContentEnvelope envelope = ContentEnvelope.fromJson(
      json,
      ownerId: fileName,
    );
    envelope.ensureSupported(fileName);

    final List<SpeakingChallenge> parsed = <SpeakingChallenge>[];
    final Set<String> seen = <String>{};

    for (final Map<String, dynamic> item in json.requireObjectList(
      'challenges',
      ownerId: fileName,
    )) {
      final SpeakingChallenge challenge = SpeakingChallenge.fromJson(item);

      if (!seen.add(challenge.id)) {
        throw FormatException(
          'Duplicate speaking challenge id "${challenge.id}" in $fileName',
        );
      }

      parsed.add(challenge);
    }

    return SpeakingChallengeLibrary(
      envelope: envelope,
      challenges: List<SpeakingChallenge>.unmodifiable(parsed),
    );
  }

  /// The file's header.
  final ContentEnvelope envelope;

  /// Every challenge in the file, in file order.
  final List<SpeakingChallenge> challenges;

  /// Looks up a challenge by [id], or null when the file does not have it.
  SpeakingChallenge? byId(String id) {
    for (final SpeakingChallenge challenge in challenges) {
      if (challenge.id == id) {
        return challenge;
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpeakingChallengeLibrary &&
          other.envelope == envelope &&
          listEquals(other.challenges, challenges);

  @override
  int get hashCode => Object.hash(envelope, Object.hashAll(challenges));

  @override
  String toString() =>
      'SpeakingChallengeLibrary(${challenges.length} challenges)';
}
