import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/features/auth/domain/models/auth_user.dart';
import 'package:hitup/features/progress/domain/models/user_profile.dart';
import 'package:hitup/features/progress/domain/repositories/user_progress_repository.dart';
import 'package:hitup/shared/providers/auth_providers.dart';
import 'package:hitup/shared/providers/progress_providers.dart';

/// Hands out one profile stream per uid and remembers which were asked for.
class _FakeProgress implements UserProgressRepository {
  final Map<String, StreamController<UserProfile>> streams =
      <String, StreamController<UserProfile>>{};

  @override
  Stream<UserProfile> watchUserProfile(String uid) => streams
      .putIfAbsent(uid, () => StreamController<UserProfile>.broadcast())
      .stream;

  Future<void> close() async {
    for (final StreamController<UserProfile> c in streams.values) {
      await c.close();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

UserProfile _profile(String uid) => UserProfile(
      uid: uid,
      displayName: '',
      email: '$uid@example.com',
      createdAt: null,
      currentProgramDay: 1,
      totalTrainingMinutes: 0,
      currentStreak: 0,
      longestStreak: 0,
      lastTrainingDate: null,
    );

void main() {
  late StreamController<AuthUser?> auth;
  late _FakeProgress progress;
  late ProviderContainer container;

  setUp(() {
    auth = StreamController<AuthUser?>.broadcast();
    progress = _FakeProgress();
    container = ProviderContainer(
      overrides: <Override>[
        authStateChangesProvider.overrideWith((Ref ref) => auth.stream),
        userProgressRepositoryProvider.overrideWithValue(progress),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await auth.close();
    await progress.close();
  });

  test('follows the signed-in user, and is null when signed out', () async {
    final List<AsyncValue<UserProfile?>> states = <AsyncValue<UserProfile?>>[];
    container.listen<AsyncValue<UserProfile?>>(
      currentUserProfileProvider,
      (_, AsyncValue<UserProfile?> next) => states.add(next),
      fireImmediately: true,
    );
    expect(container.read(currentUserProfileProvider).isLoading, isTrue);

    auth.add(const AuthUser(uid: 'ada'));
    await pumpEventQueue();
    expect(progress.streams.keys, <String>['ada']);
    progress.streams['ada']!.add(_profile('ada'));
    await pumpEventQueue();
    expect(container.read(currentUserProfileProvider).value, _profile('ada'));

    auth.add(null);
    await pumpEventQueue();
    expect(container.read(currentUserProfileProvider).value, isNull);
    expect(container.read(currentUserProfileProvider).hasValue, isTrue);

    auth.add(const AuthUser(uid: 'grace'));
    await pumpEventQueue();
    progress.streams['grace']!.add(_profile('grace'));
    await pumpEventQueue();
    expect(
      container.read(currentUserProfileProvider).value,
      _profile('grace'),
    );
    // A late event on the previous user's stream no longer reaches it.
    progress.streams['ada']!.add(_profile('ada'));
    await pumpEventQueue();
    expect(
      container.read(currentUserProfileProvider).value,
      _profile('grace'),
    );
  });

  test('an auth error is passed on', () async {
    container.listen<AsyncValue<UserProfile?>>(
      currentUserProfileProvider,
      (_, __) {},
    );
    auth.addError(StateError('auth failed'));
    await pumpEventQueue();
    expect(container.read(currentUserProfileProvider).hasError, isTrue);
  });
}
