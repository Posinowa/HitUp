import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_gateway.dart';
import '../../features/auth/data/firebase_auth_repository.dart';
import '../../features/auth/data/user_profile_store.dart';
import '../../features/auth/domain/models/auth_user.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';

/// The app's authentication repository (HIT-016).
///
/// Exposed as the [AuthRepository] interface, so a screen or controller cannot
/// reach past it into Firebase, and so tests and previews can replace it:
///
/// ```dart
/// ProviderScope(
///   overrides: <Override>[
///     authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
///   ],
///   child: const HitUpApp(),
/// );
/// ```
///
/// Reading `FirebaseAuth.instance` needs Firebase initialised, which
/// `AppBootstrap` does before the first frame, and a provider body runs only
/// when something first reads it.
final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>(
  (Ref ref) => FirebaseAuthRepository(
    gateway: FirebaseAuthGateway(FirebaseAuth.instance),
    profiles: FirestoreUserProfileStore(FirebaseFirestore.instance),
  ),
);

/// The signed-in user, or null, kept current as it changes.
///
/// What an auth guard or the router watches (HIT-020).
final StreamProvider<AuthUser?> authStateChangesProvider =
    StreamProvider<AuthUser?>(
  (Ref ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);
