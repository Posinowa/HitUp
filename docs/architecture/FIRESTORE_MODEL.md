# Firestore Data Model

**STATUS: SETTLED (HIT-010).** Access goes through the repositories in HIT-079; ownership and shape are enforced by `firestore.rules` (HIT-011).

## Principles

- Minimal collections
- Curriculum stays in local JSON (not Firestore)
- No user audio in Firestore
- Users may only access their own paths (HIT-011 security rules)

## Shape

```text
users/{uid}
  displayName: string                 // from the account, may be empty
  email: string                       // from the account
  createdAt: timestamp                // server time, set once, never changes
  currentProgramDay: int              // 1 on registration
  totalTrainingMinutes: int           // 0 on registration
  currentStreak: int                  // 0 on registration
  longestStreak: int                  // 0 on registration
  lastTrainingDate: string            // "yyyy-MM-dd", the user's local day, absent until the first training

users/{uid}/trainingHistory/{yyyy-MM-dd}
  trainingDate: string                // "yyyy-MM-dd", the same value as the document id
  programDay: int                     // which day of the programme this was
  completedExerciseIds: string[]      // ids from assets/content/exercises.json
  durationMinutes: int
  completedAt: timestamp              // server time

users/{uid}/exerciseProgress/{exerciseId}
  exerciseId: string                  // the same value as the document id
  completionCount: int                // only ever grows
  lastCompletedAt: timestamp          // server time, on every write

users/{uid}/preferences/settings
  reminderEnabled: bool
  reminderTime: string                // "HH:mm", 24 hour, the user's local clock, absent until chosen
  soundEnabled: bool
  hapticEnabled: bool
```

Nothing else exists. A field not in this list is refused by the rules rather than stored and ignored.

## Days are strings, moments are timestamps

`lastTrainingDate` and the `trainingHistory` document id are the user's **local calendar day** as a plain `"yyyy-MM-dd"` string, not a timestamp. The earlier draft left this open; this is the decision.

The streak (HIT-054) asks one question: is today the same day as last time, the next day, or a gap. It has to answer in the user's own calendar, not in UTC. A timestamp stores a point in time, so answering from one means carrying the user's timezone next to it and converting correctly on every read, every time, for a user who may travel or cross a daylight saving shift between two sessions. Storing the day the device already computed turns every later comparison into a string comparison with no timezone arithmetic in it.

`createdAt`, `completedAt` and `lastCompletedAt` stay timestamps. They answer "exactly when", which is a real moment and belongs in UTC. Only the fields whose whole purpose is "which day, for the streak" are strings.

## The history document id is the date

Completing the same day twice must not create two entries or count the day's minutes twice (HIT-053). With `{yyyy-MM-dd}` as the id, a second completion on the same day targets the document that already exists, and the rules refuse any update to a history entry. So the second write is **refused**, not merged and not duplicated.

That refusal is what keeps the totals right, because a completion is one batched write (below): Firestore applies a batch whole or not at all, so when the history entry in it is refused, the increments to `totalTrainingMinutes` and the rest are refused with it.

What the repository has to handle: the refusal arrives as `permission-denied`, which the mapper turns into `FailureCode.permissionDenied`. For a history entry that already exists for today, that is "already saved", not an error to show the user. The repository should check its own cache for today's entry before writing, and treat the refusal as success if it still happens, for instance when a completion queued offline meets one already synced from another device.

## Writes that must not half-apply

- **Counters are incremented, never read-modify-written.** `totalTrainingMinutes` and `completionCount` use `FieldValue.increment()`. Reading a value into Dart, adding to it and writing it back loses an update whenever two writes race, and offline queuing makes that more likely rather than less: two completions queued offline read the same stale value and compute the same total.
- **Server time comes from the server.** `createdAt`, `completedAt` and `lastCompletedAt` use `FieldValue.serverTimestamp()`, not `DateTime.now()`. A device clock can be wrong or skewed. `lastTrainingDate` is the deliberate exception: the day it feels like to the user has to come from the user's device.
- **Completion is one batch.** Saving a training (HIT-053) writes the `trainingHistory/{yyyy-MM-dd}` document and the aggregate fields on `users/{uid}` together, as a batched write. Two separate calls can leave history recorded with no matching aggregate, or the reverse.
- **The streak is a transaction.** Whether `currentStreak` rises, resets to 1, or stays depends on comparing today against `lastTrainingDate` first, so it is read, decide, write. A transaction re-reads at write time and retries if another write raced it; a batch built from a value read earlier cannot.

## When each document is created

- **`users/{uid}` on registration**, not lazily on first training. HIT-016 already says so; what this document adds is the defaults: `currentProgramDay` 1, the three counters 0, and `lastTrainingDate` **absent** rather than an empty string, so "never trained" and "trained on some day" can never be confused.
- **`users/{uid}/preferences/settings` at the same time**, with `reminderEnabled` false and `soundEnabled` and `hapticEnabled` true. `reminderTime` is absent until the user picks one, since no issue sets a default hour and inventing one would put a reminder where nobody chose it. Reminders start off because notification permission is asked for only when the user turns them on (`NOTIFICATIONS.md`). A screen reading preferences before the user has changed anything then never meets a missing document. HIT-058 and HIT-061, which own these settings, can revise the defaults.
- **`trainingHistory` and `exerciseProgress` documents lazily**, on the first completion they describe. There is nothing meaningful to write before that.

## Offline

The Firestore SDK's own persistence is the mechanism; the app builds nothing of its own. What that means for the repositories (HIT-079) and the error surface (HIT-066):

- A write made offline is queued and applied when connectivity returns. The caller sees it succeed immediately, and the server confirmation is not surfaced separately for the MVP.
- A read made offline, before that path has ever synced, has nothing cached. That is "not fetched yet", which is not the same as "this user has no data", and the repository is the layer that can tell them apart.
- A genuine failure goes through the mapper HIT-066 already built: `unavailable` becomes `FailureCode.networkUnavailable` and `deadline-exceeded` becomes `FailureCode.networkTimeout`. No Firestore-specific failure type is invented.

## Indexes

None beyond what Firestore creates by itself. The only query the MVP runs over a collection is the training history for one user, ordered by document id or by `trainingDate`, which single-field indexing already covers. A composite index becomes necessary the first time a query filters on one field and orders by another; there is no such query today.

## Example documents

```json
// users/{uid}
{
  "displayName": "Ada",
  "email": "ada@example.com",
  "createdAt": "2026-09-16T09:00:00Z",
  "currentProgramDay": 4,
  "totalTrainingMinutes": 87,
  "currentStreak": 3,
  "longestStreak": 5,
  "lastTrainingDate": "2026-09-16"
}
```

```json
// users/{uid}/trainingHistory/2026-09-16
{
  "trainingDate": "2026-09-16",
  "programDay": 4,
  "completedExerciseIds": ["breathing_diaphragm_04", "letter_i_01"],
  "durationMinutes": 13,
  "completedAt": "2026-09-16T09:14:00Z"
}
```

```json
// users/{uid}/exerciseProgress/breathing_diaphragm_04
{
  "exerciseId": "breathing_diaphragm_04",
  "completionCount": 6,
  "lastCompletedAt": "2026-09-16T09:14:00Z"
}
```

```json
// users/{uid}/preferences/settings
{
  "reminderEnabled": true,
  "reminderTime": "19:30",
  "soundEnabled": true,
  "hapticEnabled": true
}
```

## Curriculum against user state

Nothing under `users/{uid}` names or copies curriculum content. `completedExerciseIds`, and the document ids under `exerciseProgress`, are the bare exercise ids from `CONTENT_SCHEMA.md`, which promises never to change them. Every descriptive field, the title, the instructions, the duration, lives only in `assets/content/exercises.json`. A screen that needs the title of an exercise joins the id against the local JSON; Firestore has no title to read.

That is also why the curriculum can be rewritten without touching a single user document, and why a user's history stays meaningful when it is.

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

Every field check in the rules is marked `HIT-010`. Now that the model is
settled, those marks say which checks follow this document, so a later change
here moves the rule and its test with it.

**One check is still looser than this document.** The rules do not require a
history document's id to equal its `trainingDate`. Adding that means rewriting
the paths in most of the history tests, which sit in an open pull request, so it
follows on #12 rather than colliding with it. Nothing depends on it yet: the id
is written by the repository (HIT-079), and the cost of the gap is a user able
to file their own history under an odd id.

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
console rules to deny everything is safe in the meantime: no app code reads or
writes Firestore yet, because the repositories that would are HIT-079.
