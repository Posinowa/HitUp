# HitUp

HitUp is a guided daily diction, articulation, breathing and public-speaking training application for Android and iOS.

This repository is the Flutter mobile project (repository root = app root).

## Product Vision

HitUp is not a passive content library. The primary experience is **Today's Training**: a predefined daily sequence that builds habit through warm-up, breathing, articulation, diction and speaking practice.

## MVP Scope

- Onboarding + email auth (Firebase Auth)
- Today's Training engine + reusable exercise renderers
- Breathing, Rive warm-ups, Turkish letter drills, tongue twisters, diction exercises, speaking challenges (timer-based)
- Local curriculum JSON (offline-capable catalog)
- Firestore-synced user progress via repository layer
- Streaks, progress, local reminders, profile/settings
- Analytics + Crashlytics
- Tests + CI

Voice recording playback is **Post-MVP**. AI scoring, payments, social network, admin panel, custom backend, Cloud Functions are **out of scope**.

## Technology Stack

| Area | Choice |
|------|--------|
| Framework | Flutter + Dart |
| Platforms | Android + iOS |
| State management | **Riverpod** (locked) |
| Routing | **go_router** (locked) |
| Auth / DB / Analytics / Crash | Firebase client SDKs |
| Animations | Rive (prefer local `.riv` for MVP) |
| Large static media | Cloudflare R2 **read-only** URLs (optional) |

### NO CUSTOM BACKEND

HitUp does **not** contain or require a custom REST/GraphQL backend.  
The Flutter application communicates directly with Firebase client services where sync is needed.

### R2 SECURITY

Cloudflare R2 write credentials must **never** be embedded in the Flutter client.  
The MVP app only consumes static read-only media URLs where R2 is used.  
First Rive exercises should be bundled locally — R2 is not required to show U-X.

## Architecture

```text
Presentation (widgets/screens)
    ↓
Riverpod providers / controllers
    ↓
Domain services + repository interfaces
    ↓
Repository implementations
    ↓
Firebase client SDKs  |  Local assets (JSON / Rive)
```

**Rule:** Presentation widgets MUST NOT call `FirebaseAuth` or `FirebaseFirestore` directly.

See:

- [`docs/architecture/ARCHITECTURE.md`](docs/architecture/ARCHITECTURE.md)
- [`docs/architecture/FIRESTORE_MODEL.md`](docs/architecture/FIRESTORE_MODEL.md)
- [`docs/architecture/R2_MEDIA.md`](docs/architecture/R2_MEDIA.md)

## Folder Structure

```text
lib/
  app/           # bootstrap, router, root app
  core/          # config, errors, theme, shared primitives
  features/      # feature-first modules (auth, training, …)
  shared/        # cross-feature providers
assets/content/  # local curriculum JSON (placeholders until HIT-080)
docs/            # architecture + design + execution order
```

## Setup Requirements

- Flutter stable (project created with 3.27.x / Dart 3.6.x)
- Android Studio / Xcode tooling for device builds
- Owner-provided Firebase project access (do not invent configs)

## Flutter Setup

```bash
git clone https://github.com/Posinowa/HitUp.git
cd HitUp
flutter pub get
```

## Running the Project

```bash
flutter run
```

Foundation UI shows a placeholder screen only. Product screens belong to GitHub Issues.

## Firebase Setup

**STATUS: OWNER SETUP REQUIRED (HIT-009)**

Do not invent:

- `google-services.json`
- `GoogleService-Info.plist`
- `lib/firebase_options.dart`

When access is available, use FlutterFire / Firebase console to register apps using package/bundle id:

- `com.posinowa.hitup`, settled by HIT-078. Registering the apps binds Firebase to it.

Then initialize Firebase in `AppBootstrap` (see TODO in code).

## Cloudflare R2 Strategy

Documentation-first. Read-only public (or appropriately configured) GET URLs for large media.  
No Access Key / Secret in the app. No uploads from Flutter. See `docs/architecture/R2_MEDIA.md`.

## Training Content Strategy

Curriculum JSON is local under `assets/content/`.  
Current files are **PLACEHOLDER** fixtures. Final MVP content requires **HIT-080** approval. Developers must not invent professional medical/speech claims as code logic.

## State Management

**Riverpod** only. See HIT-005.

## Navigation

**go_router** with centralized route names. See HIT-006 and `lib/app/router/`.

## Design System

Temporary tokens in `lib/core/theme/`. Finalize via HIT-007 + HIT-008. Logo/icons via HIT-081.  
Do not scatter raw colors in feature widgets.

## Testing

```bash
dart format .
flutter analyze
flutter test
```

## Branch Strategy

```text
feature/*  →  develop  →  main
```

| Branch | Role |
|--------|------|
| `main` | Production / release branch (highly protected) |
| `develop` | Integration branch (protected) |
| `feature/*` | Issue implementation |

Developers branch **from `develop`** and open PRs **into `develop`**.  
Releases are `develop` → `main`. Emergency fixes use `hotfix/*` → `main`, then sync to `develop`.

`com.posinowa.hitup` is the Android/iOS **application identifier**, not a domain or API URL.

See [`CONTRIBUTING.md`](CONTRIBUTING.md).

## CI + Release-Ready Pipeline

GitHub Actions validates PRs to `develop` / `main`:

- repository policy + secret-file guard
- `dart format` / `flutter analyze` / `flutter test` (+ coverage artifact)
- Dependency Review (high severity)
- Android debug APK build (unsigned)
- iOS simulator build (no codesign)
- `branch-policy` on `main` (only `develop` or `hotfix/*` allowed as head)

This is **CI + release-ready validation**. It does **not** deploy to the App Store or Google Play. Store CD requires approved signing credentials (future work).

## Security

See [`SECURITY.md`](SECURITY.md). Secret scanning, push protection, Dependabot, and CODEOWNERS are part of repository governance.

## Explicitly Out of Scope

Custom backend, Cloud Functions, AI speech analysis, payments, social network, admin/CMS, cloud audio upload, R2 uploads from the client, camera/lip tracking.

See [`docs/development/FUTURE_BACKLOG.md`](docs/development/FUTURE_BACKLOG.md) for the fuller list of deferred ideas and why each one is deferred.

## GitHub Issues & Development Flow

Work starts from a GitHub Issue (Backlog ID like `HIT-029`).  
**GitHub `#` numbers are not the execution order.**  
Follow: [`docs/development/ISSUE_EXECUTION_ORDER.md`](docs/development/ISSUE_EXECUTION_ORDER.md)
