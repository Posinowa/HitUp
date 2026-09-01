# Issue Execution Order

**STATUS: APPROVED guidance**

> **GitHub `#` number is NOT the implementation sequence.**  
> Use **Backlog IDs** (`HIT-XXX`) and this dependency-aware order.

Package / Firebase chain:

```text
HIT-001 → HIT-078 → HIT-009
```

Home (`HIT-021B`) is **M2**, not M1.  
QA (`HIT-073` / `HIT-074`) feeds **into** Release Readiness (`HIT-076`), not the reverse.

Phases are a sequence for feature work. **Phase A2** is not: it collects the
repository and toolchain issues opened after the sequence was written, which
run alongside everything else.

---

## Phase A — Repository Foundation

1. HIT-001 — Initialize Flutter Project *(bootstrap largely done on main)*
2. HIT-078 — Package / Bundle Identifiers (`com.posinowa.hitup` provisional)
3. HIT-002 — Git Workflow & Conventions *(CONTRIBUTING.md present — verify AC)*
4. HIT-003 — Static Analysis / Lint
5. HIT-004 — Application Architecture
6. HIT-005 — Configure Riverpod
7. HIT-006 — Configure go_router

## Phase A2 - Repository Governance & Toolchain

Opened from 26 August 2026 onward, after the phases below were already under
way. These do not block feature work and feature work does not block them; they
are listed here because they extend Phase A, not because they run between A
and B.

Separator note: entries added in this section use a hyphen rather than the dash
used above, matching the convention already adopted for issue templates.

The `*(done)*` markers are true as of 31 August 2026. They are dated rather than
bare because a status marker with no date stops being a claim about a moment and
starts being a claim about now, which is the way this kind of list goes quietly
wrong. Check the issue before relying on one.

1. HIT-082 - Issue forms *(done)*
2. HIT-084 - Presentation layer boundary enforced in CI *(done)*
3. HIT-085 - Content-level secret scanning *(done)*
4. HIT-086 - Pin the Flutter SDK version in CI *(done)*
5. HIT-090 - Build in release mode during release validation *(done)*
6. HIT-091 - Pin the Android and iOS floors *(done)*
7. HIT-093 - Single source for the pinned Flutter version *(done)*
8. HIT-083 - Commit convention enforced on PR titles *(code merged, gate not armed, see below)*
9. HIT-089 - Harden the analyzer configuration
10. HIT-094 - Allow release validation to run on demand
11. HIT-087 - Enable auto-merge *(admin only)*
12. HIT-088 - Disable rebase merging *(admin only)*
13. HIT-092 - Keep this file current
14. HIT-095 - Correct the OS floor rule in `ARCHITECTURE.md`

### Dependencies that are real but not written in the issues

- **HIT-091 gates HIT-057.** `flutter_local_notifications` declares
  `minSdkVersion 24` in its own Gradle config and will not link below it.
  `android/app/build.gradle` carries that floor as an explicit literal, put
  there by HIT-091, and HIT-057 relies on it rather than setting it again.
  The same plugin moves the iOS floor to 13.0.
- **HIT-095 came out of those two floor moves.** It corrects the rule in
  `ARCHITECTURE.md` that both of them departed from: HIT-091 raised the Android
  floor in its own PR ahead of the dependency needing it, and HIT-057 moved the
  iOS floor alongside the dependency that required it. Nothing blocks it, but it
  is read best next to the entry above.
- **HIT-093 depends on HIT-086** and edits the same two workflow files.
  Anything else touching `flutter_ci.yml` at the same time will need rebasing
  rather than merging.
- **HIT-094 depends on HIT-090**, and its acceptance criterion cannot be met
  before it merges: a `workflow_dispatch` button appears only once the trigger
  exists on the default branch, which is `develop`.
- **HIT-089 is best merged last of this group.** It enables lint rules on a
  file that had none, and `flutter analyze` already stops on what they report,
  so every open pull request goes red until it picks up the fixes. Landing it
  while several are open costs a round of rebasing each, for no gain.
- **HIT-086 constrains anything that regenerates `pubspec.lock`.** Pinning the
  SDK is what makes a lock file reproducible; resolving dependencies on a
  different Flutter can produce a different lock file, and the difference does
  not announce itself.

### What needs repository admin, and what that means

Three items cannot be finished with write access alone.

- **HIT-087** and **HIT-088** are repository settings and have no code at all.
- **HIT-083** has code, and it is merged, but its check only reports. As of
  31 August 2026 `pr-title` is in neither ruleset's required status checks, so
  a pull request with a red title check can still be merged. The issue was
  closed as completed on 28 August and reopened on 30 August for exactly this
  reason, which is the case for writing the state down here rather than leaving
  it in one issue's history. Arming it is a settings change on both
  `develop-integration-protection` and `main-production-protection`.

The distinction matters for anyone reading this file to find work: a
contributor without admin can write the code for HIT-083, and did, but cannot
make it enforce anything.

## Phase B — Brand & Design Foundation

1. HIT-007 — Corporate Identity & Design Tokens Spec
2. HIT-081 — Finalize Logo & App Icon Assets
3. HIT-008 — Implement Flutter Design Token System (replace temporary tokens)

## Phase C — Firebase & Data Foundation

1. HIT-009 — Configure Firebase Project (depends on HIT-078)
2. HIT-010 — Firestore Data Model
3. HIT-011 — Firestore Security Rules
4. HIT-079 — Implement User Progress Repository
5. HIT-012 — Local Curriculum Content Schema
6. HIT-013 — Cloudflare R2 Media Architecture (docs; local Rive preferred for MVP)
7. HIT-080 — Define & Validate MVP Diction Curriculum *(content approval — parallelizable; gates final content population)*

## Phase D — App Shell & Authentication

1. HIT-016 — Auth Repository
2. HIT-014 — Splash / Bootstrap Flow
3. HIT-015 — Onboarding
4. HIT-017 — Registration
5. HIT-018 — Login
6. HIT-019 — Forgot Password
7. HIT-020 — Auth Guard & Session Persistence
8. HIT-021 — Main Bottom Navigation (placeholder tab bodies for M1)

## Phase E — Training Core

1. HIT-022 — Exercise Domain Models
2. HIT-023 — Training Program Models
3. HIT-024 — Local Curriculum Repository
4. HIT-025 — Today's Training Engine *(uses HIT-079)*
5. HIT-026 — Training Session State Machine
6. HIT-028 — Generic Exercise Container
7. HIT-021B — Home Screen (Today's Training) — **M2**
8. HIT-027 — Training Overview
9. HIT-021C — Practice Categories

## Phase F — Exercise Engines

### Breathing
1. HIT-029 — Breathing Engine
2. HIT-030 — Breathing UI
3. HIT-031 — Breathing dataset *(final content gated by HIT-080)*

### Rive / Articulation warm-ups
1. HIT-032 — Integrate Rive
2. HIT-033 — Reusable Rive Renderer
3. HIT-034 — U-X Lip Exercise (local `.riv`)
4. HIT-035 / HIT-036 / HIT-037 — Lip / Tongue / Jaw sets *(final content gated by HIT-080)*

### Letters
1. HIT-038 — Turkish Letter Exercise System
2. HIT-039 — Initial letter content *(final gated by HIT-080)*

### Tongue twisters
1. HIT-040 — Twister model
2. HIT-041 — Twister library *(final gated by HIT-080)*
3. HIT-042 — Twister screen

### Diction
1. HIT-043 — Emphasis renderer
2. HIT-044 — Intonation renderer
3. HIT-045 — Pause renderer
4. HIT-047 — WPM calculation
5. HIT-046 — Timed reading

### Speaking
1. HIT-049 — Preparation countdown
2. HIT-048 — Speaking challenge system (timer MVP; recording is Post-MVP)

## Phase G — Progress & Engagement

1. HIT-052 — Persist exercise completion *(via HIT-079)*
2. HIT-053 — Persist daily training completion
3. HIT-054 — Streak algorithm
4. HIT-055 — Progress screen
5. HIT-056 — Weekly activity
6. HIT-057 — Local notification infrastructure
7. HIT-060 — Profile
8. HIT-061 — Settings
9. HIT-062 — Logout
10. HIT-058 — Reminder settings
11. HIT-059 — Schedule daily reminder

## Phase H — Quality

1. HIT-063 — Analytics integration
2. HIT-064 — Analytics taxonomy
3. HIT-065 — Crashlytics
4. HIT-066 — Central error handling
5. HIT-067 — Loading / empty / error components
6. HIT-068 — Core unit tests
7. HIT-069 — Critical widget tests
8. HIT-070 — E2E smoke strategy
9. HIT-071 — GitHub Actions CI (minimal workflow already bootstrapped)
10. HIT-072 — Accessibility review
11. HIT-075 — Finalize README (keep updated)
12. HIT-073 — Android Device QA
13. HIT-074 — iOS Device QA
14. **HIT-076 — MVP Release Readiness Checklist** ← **LAST**

## Post-MVP (M5)

- HIT-050 — Local voice recording
- HIT-051 — Recording playback
- HIT-077 — Future backlog notes

## First issue for an intern (after reading docs)

Recommended: **HIT-007** (identity) in parallel with verifying **HIT-004/005/006** completion against acceptance criteria, then **HIT-078** owner confirmation → **HIT-009** Firebase.
