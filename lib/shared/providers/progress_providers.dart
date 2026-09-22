import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/models/auth_user.dart';
import '../../features/progress/data/firebase_user_progress_repository.dart';
import '../../features/progress/data/firestore_progress_store.dart';
import '../../features/progress/domain/models/user_profile.dart';
import '../../features/progress/domain/repositories/user_progress_repository.dart';
import 'auth_providers.dart';

/// The app's user progress repository (HIT-079).
///
/// Exposed as the [UserProgressRepository] interface, the one path to user
/// progress, so a screen or controller cannot reach past it into Firestore,
/// and so tests and previews can replace it:
///
/// ```dart
/// ProviderScope(
///   overrides: <Override>[
///     userProgressRepositoryProvider.overrideWithValue(FakeProgress()),
///   ],
///   child: const HitUpApp(),
/// );
/// ```
final Provider<UserProgressRepository> userProgressRepositoryProvider =
    Provider<UserProgressRepository>(
  (Ref ref) => FirebaseUserProgressRepository(
    FirestoreProgressStore(FirebaseFirestore.instance),
  ),
);

/// The signed-in user's profile, kept current, or null when nobody is signed in.
///
/// Follows the account: signing out ends the profile stream and emits null,
/// and signing in as someone else starts that user's. While the auth state is
/// still loading, so is this.
final StreamProvider<UserProfile?> currentUserProfileProvider =
    StreamProvider<UserProfile?>((Ref ref) {
  final AsyncValue<AuthUser?> auth = ref.watch(authStateChangesProvider);
  return auth.when(
    data: (AuthUser? user) => user == null
        ? Stream<UserProfile?>.value(null)
        : ref.watch(userProgressRepositoryProvider).watchUserProfile(user.uid),
    loading: () => const Stream<UserProfile?>.empty(),
    error: (Object error, StackTrace stackTrace) =>
        Stream<UserProfile?>.error(error, stackTrace),
  );
});
