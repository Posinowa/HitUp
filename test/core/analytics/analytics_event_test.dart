import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/core/analytics/analytics_event.dart';
import 'package:hitup/core/analytics/analytics_service.dart';

/// Every event the taxonomy defines, built with plausible values.
///
/// One list, so a new event cannot be added without the checks below seeing
/// it: the name rules, the parameter rules and the no-personal-data rule all
/// run over this.
final Map<String, AnalyticsEvent> everyEvent = <String, AnalyticsEvent>{
  'sign_up': AnalyticsEvent.signUp(method: 'password'),
  'login': AnalyticsEvent.login(method: 'password'),
  'onboarding_completed': AnalyticsEvent.onboardingCompleted(),
  'training_started': AnalyticsEvent.trainingStarted(
    programDay: 4,
    exerciseCount: 5,
  ),
  'training_completed': AnalyticsEvent.trainingCompleted(
    programDay: 4,
    exerciseCount: 5,
    durationMinutes: 13,
  ),
  'exercise_started': AnalyticsEvent.exerciseStarted(
    exerciseId: 'breathing_diaphragm_04',
    presentationType: 'breathing',
    programDay: 4,
  ),
  'exercise_completed': AnalyticsEvent.exerciseCompleted(
    exerciseId: 'breathing_diaphragm_04',
    presentationType: 'breathing',
    programDay: 4,
  ),
  'tongue_twister_completed': AnalyticsEvent.tongueTwisterCompleted(
    tongueTwisterId: 'tt_r_01',
    repetitions: 3,
  ),
  'speaking_challenge_started': AnalyticsEvent.speakingChallengeStarted(
    speakingChallengeId: 'sc_intro_01',
  ),
  'speaking_challenge_completed': AnalyticsEvent.speakingChallengeCompleted(
    speakingChallengeId: 'sc_intro_01',
    durationSeconds: 90,
  ),
  'reminder_enabled': AnalyticsEvent.reminderEnabled(hour: 19),
  'reminder_disabled': AnalyticsEvent.reminderDisabled(),
  'streak_advanced': AnalyticsEvent.streakAdvanced(
    currentStreak: 3,
    longestStreak: 5,
  ),
  'program_finished': AnalyticsEvent.programFinished(programDay: 14),
};

void main() {
  group('the taxonomy', () {
    test('every event carries the name it is filed under', () {
      everyEvent.forEach((String name, AnalyticsEvent event) {
        expect(event.name, name);
      });
    });

    test('every name is one Firebase keeps', () {
      for (final AnalyticsEvent event in everyEvent.values) {
        expect(
          event.name,
          matches(RegExp(r'^[a-z][a-z0-9_]*$')),
          reason: event.name,
        );
        expect(
          event.name.length,
          lessThanOrEqualTo(AnalyticsEvent.maxNameLength),
          reason: event.name,
        );
        // Firebase reserves its own names and refuses these outright.
        expect(
          event.name,
          isNot(anyOf('app_open', 'first_open', 'session_start')),
        );
      }
    });

    test('every parameter is a short name with an id or a number in it', () {
      for (final AnalyticsEvent event in everyEvent.values) {
        expect(
          event.parameters.length,
          lessThanOrEqualTo(AnalyticsEvent.maxParameters),
          reason: event.name,
        );
        event.parameters.forEach((String key, Object value) {
          final String where = '${event.name}.$key';
          expect(key, matches(RegExp(r'^[a-z][a-z0-9_]*$')), reason: where);
          expect(value, anyOf(isA<int>(), isA<String>()), reason: where);
          if (value is String) {
            expect(
              value,
              matches(RegExp(r'^[a-z][a-z0-9_.]*$')),
              reason: where,
            );
            expect(
              value.length,
              lessThanOrEqualTo(AnalyticsEvent.maxValueLength),
              reason: where,
            );
          }
        });
      }
    });

    test('no parameter can carry personal data', () {
      // The rule the type is meant to enforce: ids and numbers only. An email,
      // a name with a capital letter or a sentence cannot be an id.
      for (final String value in <String>[
        'ada@example.com',
        'Ada Lovelace',
        'Kırmızı şemsiye dedi',
        'Breathing',
        '',
      ]) {
        expect(
          () => AnalyticsEvent.exerciseCompleted(
            exerciseId: value,
            presentationType: 'breathing',
            programDay: 1,
          ),
          throwsArgumentError,
          reason: value,
        );
      }
    });

    test('a value too long for Firebase is refused, not silently dropped', () {
      final String tooLong = 'a' * (AnalyticsEvent.maxValueLength + 1);
      expect(
        () => AnalyticsEvent.exerciseStarted(
          exerciseId: tooLong,
          presentationType: 'breathing',
          programDay: 1,
        ),
        throwsArgumentError,
      );
      // Exactly at the limit is allowed.
      final String atLimit = 'a' * AnalyticsEvent.maxValueLength;
      expect(
        AnalyticsEvent.exerciseStarted(
          exerciseId: atLimit,
          presentationType: 'breathing',
          programDay: 1,
        ).parameters['exercise_id'],
        atLimit,
      );
    });

    test('the reminder hour has to be an hour', () {
      expect(
        AnalyticsEvent.reminderEnabled(hour: 0).parameters,
        <String, Object>{'hour': 0},
      );
      expect(AnalyticsEvent.reminderEnabled(hour: 23).parameters['hour'], 23);
      expect(
        () => AnalyticsEvent.reminderEnabled(hour: 24),
        throwsArgumentError,
      );
      expect(
        () => AnalyticsEvent.reminderEnabled(hour: -1),
        throwsArgumentError,
      );
    });
  });

  group('the events themselves', () {
    test('a training day carries its day, count and minutes', () {
      expect(
        AnalyticsEvent.trainingCompleted(
          programDay: 4,
          exerciseCount: 5,
          durationMinutes: 13,
        ).parameters,
        <String, Object>{
          'program_day': 4,
          'exercise_count': 5,
          'duration_minutes': 13,
        },
      );
    });

    test('an event with nothing to say carries no parameters', () {
      expect(AnalyticsEvent.onboardingCompleted().parameters, isEmpty);
      expect(AnalyticsEvent.reminderDisabled().parameters, isEmpty);
    });

    test('parameters cannot be changed after the event is built', () {
      final AnalyticsEvent event = AnalyticsEvent.programFinished(
        programDay: 14,
      );
      expect(
        () => event.parameters['program_day'] = 1,
        throwsUnsupportedError,
      );
    });

    test('events compare by name and parameters', () {
      expect(
        AnalyticsEvent.programFinished(programDay: 14),
        AnalyticsEvent.programFinished(programDay: 14),
      );
      expect(
        AnalyticsEvent.programFinished(programDay: 14).hashCode,
        AnalyticsEvent.programFinished(programDay: 14).hashCode,
      );
      expect(
        AnalyticsEvent.programFinished(programDay: 14),
        isNot(AnalyticsEvent.programFinished(programDay: 13)),
      );
      expect(
        AnalyticsEvent.trainingStarted(programDay: 1, exerciseCount: 2),
        isNot(
          AnalyticsEvent.trainingCompleted(
            programDay: 1,
            exerciseCount: 2,
            durationMinutes: 0,
          ),
        ),
      );
    });

    test('an event prints its name, and its parameters when it has any', () {
      expect(
        AnalyticsEvent.reminderDisabled().toString(),
        'AnalyticsEvent(reminder_disabled)',
      );
      expect(
        AnalyticsEvent.programFinished(programDay: 14).toString(),
        'AnalyticsEvent(program_finished, {program_day: 14})',
      );
    });
  });

  group('the service that records nothing', () {
    test('accepts everything and does nothing with it', () async {
      const AnalyticsService service = NoopAnalyticsService();

      for (final AnalyticsEvent event in everyEvent.values) {
        await service.log(event);
      }
      await service.setUserId('uid-1');
      await service.setUserId(null);
      await service.setCollectionEnabled(true);
      await service.setCollectionEnabled(false);
    });
  });
}
