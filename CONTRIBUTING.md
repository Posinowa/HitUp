# Contributing to HitUp

This guide is for intern/junior Flutter developers working from the GitHub backlog.

## Important exception

Initial repository bootstrap was created directly on `main`.  
**All subsequent issue implementation must use feature branches and pull requests.**

## Development Workflow

Start from a GitHub Issue, for example:

```text
HIT-029 – Build Reusable Breathing Engine
```

GitHub issue numbers (`#32`) are **not** the same as Backlog IDs (`HIT-029`).  
Execution order: [`docs/development/ISSUE_EXECUTION_ORDER.md`](docs/development/ISSUE_EXECUTION_ORDER.md)

## Branch Rule

```text
feature/HIT-029-breathing-engine
feature/HIT-017-registration-screen
fix/HIT-XXX-short-description
chore/HIT-XXX-short-description
```

Do **not** commit application work directly to `main`.

## Before Starting an Issue

1. Read the complete issue (Objective, Scope, Acceptance Criteria, Out of Scope).
2. Read dependencies — verify they are Done.
3. Pull latest `main`.
4. Create a new branch from `main`.
5. Implement **only** the issue scope.

## During Implementation

- Follow feature-first architecture in `docs/architecture/ARCHITECTURE.md`
- Use **Riverpod** for DI and state
- Use **go_router** for navigation
- Call Firebase only through repositories — never from presentation widgets
- Use design tokens in `lib/core/theme/`
- Reuse components; avoid scope creep
- Do not add unrequested packages
- Do not add a backend, Cloud Functions, AI, or payments
- Do not embed secrets or R2 credentials

## Required Before PR

```bash
dart format .
flutter analyze
flutter test
```

All must pass. Existing tests must not fail.

## Commit Convention

```text
feat(auth): add registration screen [HIT-017]
feat(training): add breathing engine [HIT-029]
fix(progress): handle streak rollover [HIT-054]
chore(firebase): configure firebase core [HIT-009]
docs: update architecture guide
```

## Pull Request

Every PR must:

- reference the GitHub issue
- describe changes and testing
- include screenshots for UI changes
- contain no unrelated work
- contain no secrets

Template (also in `.github/pull_request_template.md`):

```markdown
## Related Issue

Closes #XX

## What Changed

-

## Screenshots

If UI change.

## Testing

- [ ] flutter analyze
- [ ] flutter test
- [ ] Android tested
- [ ] iOS tested if applicable

## Checklist

- [ ] Scope matches issue
- [ ] No secrets committed
- [ ] No backend introduced
- [ ] Design tokens used
- [ ] Relevant documentation updated
```

## Do NOT

- work directly on `main`
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
