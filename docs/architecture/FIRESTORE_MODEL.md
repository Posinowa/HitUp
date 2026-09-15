# Firestore Data Model

**STATUS: DRAFT** — finalize under HIT-010; implement access via HIT-079.

## Principles

- Minimal collections
- Curriculum stays in local JSON (not Firestore)
- No user audio in Firestore
- Users may only access their own paths (HIT-011 security rules)

## Proposed shape

```text
users/{uid}
  displayName: string
  email: string
  createdAt: timestamp
  currentProgramDay: number
  totalTrainingMinutes: number
  currentStreak: number
  longestStreak: number
  lastTrainingDate: string (yyyy-MM-dd local calendar day) | timestamp (decide in HIT-010)

users/{uid}/trainingHistory/{historyId}
  trainingDate: string
  programDay: number
  completedExerciseIds: string[]
  durationMinutes: number
  completedAt: timestamp

users/{uid}/exerciseProgress/{exerciseId}
  exerciseId: string
  completionCount: number
  lastCompletedAt: timestamp

users/{uid}/preferences/settings
  reminderEnabled: bool
  reminderTime: string (HH:mm)
  soundEnabled: bool
  hapticEnabled: bool
```

Exact field types and timezone strategy are owned by HIT-010 + HIT-054.

## Security rules

`firestore.rules` at the repository root enforces the shape above (HIT-011).

- **Ownership.** A signed-in user reads and writes only `users/{their uid}` and
  the subcollections listed above. Unauthenticated access, other users' paths,
  and any path not listed here are denied.
- **Append-only history.** `trainingHistory` entries cannot be updated, and
  `completedAt` must be the server's time on create, so an entry can be neither
  edited nor backdated. Deleting an entry is allowed, because a user must be
  able to remove their own data and a re-created entry is stamped with the time
  it was re-created.
- **Monotonic counts.** `exerciseProgress.completionCount` never decreases.
- **Server-stamped times.** `users.createdAt` is the server's time on create and
  never changes; `exerciseProgress.lastCompletedAt` is the server's time on
  every write. Clients write these with `FieldValue.serverTimestamp()`.
- **No unknown fields.** Each document accepts only the fields in the shape
  above.

Every field check in the rules is marked `HIT-010`. This model is still a
draft, so when HIT-010 changes a field, the matching rule and its test change in
the same pull request.

**What rules cannot do.** HitUp has no backend, so progress is computed on the
device. Rules stop history being rewritten or backdated and refuse impossible
values; they cannot prove that a user actually trained.

### Testing the rules

The tests run the real rules file against the Firestore emulator. They need
Node 20+ and Java 21+ (the emulator is a Java process).

```bash
cd firebase/rules_test
npm install
npm test
```

`npm test` starts the emulator, runs every test in `firestore_rules.test.js`,
and stops it. The project id is `demo-hitup`: a `demo-` id makes the emulator
refuse to talk to any real project, so the tests cannot touch production data.

Any change to `firestore.rules` should be accompanied by a test and a passing
local run. The tests are not wired into CI yet.

### Deploying the rules

Deploy only from `develop` or `main`, after the change has been reviewed and
merged. Deploying from a feature branch puts unreviewed security rules into
production.

```bash
npx firebase-tools@15.30.0 login
npx firebase-tools@15.30.0 use --add        # choose the HitUp project
npx firebase-tools@15.30.0 deploy --only firestore:rules
```

`firebase use --add` writes `.firebaserc`, which records a project alias for
your machine and is git-ignored.

Until the first deploy, the Firestore database must not be left in the
console's test mode, which allows anyone to read and write it. Setting the
console rules to deny everything is safe in the meantime: no app code talks to
Firestore before HIT-009 lands.
