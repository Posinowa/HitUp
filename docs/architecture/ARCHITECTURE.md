# HitUp Architecture

**STATUS: APPROVED (foundation decisions locked)**

## Stack decisions

| Decision | Choice | Issue |
|----------|--------|-------|
| Framework | Flutter (Android + iOS) | HIT-001 |
| State management | Riverpod | HIT-005 |
| Routing | go_router | HIT-006 |
| Backend | **NONE** — Firebase client SDKs only | — |
| Auth / DB / Analytics / Crash | Firebase Auth, Firestore, Analytics, Crashlytics | HIT-009+ |
| Curriculum | Local JSON assets | HIT-012 |
| Large media | Cloudflare R2 read-only (optional) | HIT-013 |
| Animations | Rive (prefer local for MVP) | HIT-032 |
| Reminders | On-device local notifications, **no FCM** | HIT-057 |

## Layering

```text
Presentation (widgets / screens)
    ↓
Riverpod Controllers / Providers
    ↓
Domain / Services
    ↓
Repository Interfaces
    ↓
Repository Implementations
    ↓
Firebase client SDKs  |  Local Assets
```

### Hard rules

1. Presentation widgets **MUST NOT** directly depend on `FirebaseAuth` or `FirebaseFirestore`.
2. There is **no** custom REST/GraphQL backend and **no** Cloud Functions in MVP.
3. User progress sync goes through **UserProgressRepository** (HIT-079) — one abstraction, no duplicates.
4. Curriculum content is **not** stored in Firestore for MVP.
5. Never embed Cloudflare R2 secrets in the client.
6. Do not mix Bloc / competing state libraries.

## Feature-first layout

```text
lib/
  app/          bootstrap, router, HitUpApp
  core/         config, errors, theme, shared primitives
  features/     auth, onboarding, home, training, practice, progress, profile, notifications, recording
  shared/       cross-feature providers
```

Larger features may use `data/`, `domain/`, `presentation/` internally. Tiny features need not create empty ceremony folders.

## Supported OS versions

| Platform | Floor | Set in |
|---|---|---|
| Android | API 24 (7.0) | `android/app/build.gradle` |
| iOS | 13.0 | `ios/Runner.xcodeproj`, `ios/Flutter/AppFrameworkInfo.plist` |

Both are written as **explicit literals**, never derived from
`flutter.minSdkVersion` or any other toolchain default. The floor is visible to
users: raising it stops updates reaching devices below it. That has to be a
change someone makes deliberately and a reviewer sees in a diff, not something
a Flutter SDK upgrade does quietly on a day nobody touched the setting.

Raising a floor is its own change, with its own reasoning, in its own PR. The
Android floor moved 23 to 24 because `flutter_local_notifications` (HIT-057)
declares `minSdkVersion 24` and will not link below it. The iOS floor moved
12.0 to 13.0 for the same dependency, whose podspec sets
`ios.deployment_target = '13.0'`.

## Package identifiers

**STATUS: OWNER DECISION REQUIRED (provisional selected)**

- Android / iOS: `com.posinowa.hitup` (HIT-078)

## Offline

Local curriculum JSON must remain usable without network. Firestore sync may require connectivity; surface failures via domain `Failure` types.

## Related docs

- `CONTENT_SCHEMA.md`
- `ERROR_HANDLING.md`
- `FIRESTORE_MODEL.md`
- `R2_MEDIA.md`
- `NOTIFICATIONS.md`
- `../design/IDENTITY.md`
- `../development/ISSUE_EXECUTION_ORDER.md`
