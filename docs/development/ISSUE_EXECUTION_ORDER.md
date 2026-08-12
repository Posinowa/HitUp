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

---

## Phase A — Repository Foundation

1. HIT-001 — Initialize Flutter Project *(bootstrap largely done on main)*
2. HIT-078 — Package / Bundle Identifiers (`com.posinowa.hitup` provisional)
3. HIT-002 — Git Workflow & Conventions *(CONTRIBUTING.md present — verify AC)*
4. HIT-003 — Static Analysis / Lint
5. HIT-004 — Application Architecture
6. HIT-005 — Configure Riverpod
7. HIT-006 — Configure go_router

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
