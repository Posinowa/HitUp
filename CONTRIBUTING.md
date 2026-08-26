# Contributing to HitUp

This guide is for intern/junior Flutter developers working from the GitHub backlog.

## Branch strategy

```text
feature/*  →  develop  →  main
```

| Branch | Purpose |
|--------|---------|
| `main` | Production / release line (highly protected) |
| `develop` | Integration branch (protected) |
| `feature/*` | Issue implementation |
| `fix/*` | Bug fixes |
| `chore/*` | Tooling / docs / config |
| `hotfix/*` | Emergency fixes → `main`, then sync back to `develop` |

### NEVER push directly to `main` or `develop`

Except the authenticated repository owner bypass account under exceptional/administrative circumstances.  
Owner bypass is an **emergency / admin mechanism only** — interns must never rely on it. Prefer a PR even when bypassing reviews, for audit history.

CODEOWNER (`@yusufyilmazf`) is **not** a general bypass role.

## Start from a GitHub Issue

Example:

```text
HIT-029 – Build Reusable Breathing Engine
```

GitHub issue numbers (`#32`) are **not** the same as Backlog IDs (`HIT-029`).  
Execution order: [`docs/development/ISSUE_EXECUTION_ORDER.md`](docs/development/ISSUE_EXECUTION_ORDER.md)

## Create a branch FROM develop

```bash
git checkout develop
git pull origin develop
git checkout -b feature/HIT-XXX-description
```

Naming examples:

```text
feature/HIT-029-breathing-engine
feature/HIT-017-registration-screen
fix/HIT-054-streak-rollover
chore/HIT-009-firebase-config
hotfix/HIT-XXX-critical-fix
```

## Pull request destination

| Change type | Open PR against |
|-------------|-----------------|
| Normal feature / fix / chore | **`develop`** |
| Release | **`main`** (head must be `develop`) |
| Emergency hotfix | **`main`** (head must be `hotfix/*`) then sync into `develop` |

**Never** open `feature/*` → `main`.

## Before starting an issue

1. Read the complete issue (Objective, Scope, Acceptance Criteria, Out of Scope).
2. Read dependencies — verify they are Done.
3. Pull latest **`develop`**.
4. Create a new branch from **`develop`**.
5. Implement **only** the issue scope.

## During implementation

- Follow feature-first architecture in `docs/architecture/ARCHITECTURE.md`
- Use **Riverpod** for DI and state
- Use **go_router** for navigation
- Call Firebase only through repositories — never from presentation widgets
- Use design tokens in `lib/core/theme/` (see [`docs/design/THEMING.md`](docs/design/THEMING.md))
- Reuse components; avoid scope creep
- Do not add unrequested packages
- Do not add a backend, Cloud Functions, AI, or payments
- Do not embed secrets or R2 credentials

### New dependencies

Any new `pubspec.yaml` package must be justified in the PR:

- Why is it needed?
- Why are existing dependencies insufficient?
- Is it maintained?
- Does it introduce native permissions?

Avoid package sprawl.

### Manifest / Info.plist changes

Changes to `android/app/src/main/AndroidManifest.xml` or `ios/Runner/Info.plist` require CODEOWNER review and must explain new permissions (microphone, notifications, camera, storage, etc.). Camera is not MVP.

## Flutter version

Install **Flutter 3.47.0**, stable channel. CI pins the same version, in the
`FLUTTER_VERSION` value at the top of both workflow files.

Running a different SDK locally is the usual reason a PR is green on one machine
and red in CI, and the failure then reads as though the change caused it.
Upgrading is a deliberate `chore(toolchain):` PR that moves the pin and the line
above together, never something that happens on its own.

## Required before PR

```bash
dart format .
flutter analyze
flutter test
```

All must pass. Existing tests must not fail.

Tests are written alongside the code they cover, in the same PR, not added afterward. A piece of work is not done until its tests exist.

## Commit convention

```text
feat(auth): add registration screen [HIT-017]
feat(training): add breathing engine [HIT-029]
fix(progress): handle streak rollover [HIT-054]
chore(firebase): configure firebase core [HIT-009]
docs: update architecture guide
```

## Pull request checklist

Use `.github/pull_request_template.md`. Every PR must:

- reference the GitHub issue
- target the correct base branch
- describe changes and testing
- include screenshots for UI changes
- contain no unrelated work
- contain no secrets

## CI + release-ready pipeline

PRs run format, analyze, tests, dependency review, secret/repository policy guards, and Android/iOS compile validation.  
This is **CI + release-ready validation**, **not** automatic App Store / Play Store deployment. Store CD requires separate signing credentials (future issue).

## Secrets

See [`SECURITY.md`](SECURITY.md). Never commit `.env` secrets, Admin SDK keys, R2 write credentials, or signing material.

## Generated files

Do **not** commit `build/` or `.dart_tool/`.  
**Do** keep `pubspec.lock` committed for deterministic app dependencies.

## Do NOT

- push directly to `main` or `develop`
- open `feature/*` → `main`
- create a custom backend
- add Firebase Cloud Functions
- add AI integrations
- add payments / IAP / ads
- upload user audio to R2 or Firestore
- embed R2 Access Key / Secret
- call Firestore directly from presentation widgets
- hard-code design colors across widgets
- implement unrelated features
- ignore issue dependencies
- close an issue unless its acceptance criteria are truly met

## Historical note

Initial Flutter bootstrap was committed directly to `main` before protections existed. That exception is closed; normal workflow applies going forward.
