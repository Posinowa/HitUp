# Future Backlog

**STATUS: Tracking document, no implementation required by this file.**

> Everything below is a candidate for a future milestone, not a commitment. Nothing in this document creates mandatory work for the MVP (M1 to M4).

## Hard bans (restated)

These are not "later" items, they are architecture decisions a future feature must not route around silently:

- No custom backend (`backend/`, `server/`, `functions/`), no Firebase Cloud Functions used to sneak in backend-shaped logic. See [`SECURITY.md`](../../SECURITY.md#custom-backend) and [`ARCHITECTURE.md`](../architecture/ARCHITECTURE.md).
- A privileged credential, or a "just this once" Cloud Function, requires a separate architecture and security review before it exists, not after.

## Candidate post-MVP ideas

For each: what it is, why it is deferred. None of these are scoped, estimated, or assigned a `HIT-XXX` id yet.

### Auth & account

- **Social auth (Google / Apple sign-in).** MVP ships email/password only (`HIT-016`). Adding providers later is additive to the existing auth repository, not a rewrite.

### Engagement & notifications

- **FCM (server-pushed notifications).** MVP uses local, on-device scheduled reminders only (`HIT-057`). FCM needs a trigger source, and the only ways to build one are a backend or a Cloud Function, both banned for MVP.
- **Remote Config.** Would let copy or flags change without a release. Not needed while every change already goes through direct CODEOWNER review.

### Content & media

- **Cloud audio sync / recording upload.** MVP exercises are text and visual, plus local Rive playback. Storing or syncing user-recorded audio is a separate feature: storage, privacy, and the R2 write path all need their own design.
- **AI speech analysis.** Scoring pronunciation against a model is the largest post-MVP idea on this list. Blocked until there is a working approach that does not require a custom backend.

### Growth

- **Payments.** No monetization in MVP.
- **CMS / admin panel.** Content is hand-authored local JSON for MVP (`HIT-012`). An admin panel implies a backend to serve it from.
- **Social network features.** Following, sharing, leaderboards. Outside the "daily habit, solo practice" framing MVP is built around.

### Personalization

- **Dark mode.** Design tokens (`HIT-008`) are structured to make this additive later, a second `ColorScheme` next to the current one, but it is not built or requested for MVP.

## Why this list exists

The spec requires MVP and future work to stay visibly separated, so a "small addition" does not quietly grow MVP scope. When a post-MVP idea turns into real work, it gets its own `HIT-XXX` issue. This file is not itself a queue of issues waiting to be opened.
