# Branching & protection

**STATUS: APPROVED**

## Flow

```text
GitHub Issue
    ↓
feature/HIT-XXX-description  (from develop)
    ↓
PR → develop
    ↓
Release PR develop → main
```

Emergency: `hotfix/*` → `main`, then merge/sync into `develop`.

## Application identifier (not a URL)

```text
Android applicationId: com.posinowa.hitup
iOS bundle identifier: com.posinowa.hitup
```

This is **not** a domain, subdomain, API, or backend address. HitUp has **no custom backend**.

## CODEOWNERS vs bypass

- CODEOWNER: `@yusufyilmazf` (required review for normal PRs)
- Owner bypass account: authenticated admin used only for emergency/admin ruleset bypass
- CODEOWNER role does **not** grant general bypass

## CodeQL

CodeQL is **not** configured for Dart source because Dart is not a supported CodeQL language for this repository’s primary codebase. Use Flutter analyzer, tests, Dependency Review, Dependabot, and secret scanning instead.
