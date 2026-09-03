# Local Curriculum Content Schema

**STATUS: APPROVED structure (HIT-012)** for the *shape* of the files.
The *content* inside them stays `"status": "placeholder"` until HIT-080 approves it.

Training content ships inside the app bundle under `assets/content/`. See the offline rule in
[`ARCHITECTURE.md`](ARCHITECTURE.md) ("Local curriculum JSON must remain usable without network")
and the storage boundary in [`FIRESTORE_MODEL.md`](FIRESTORE_MODEL.md) ("Curriculum stays in local
JSON, not Firestore").

## Files

| File | Root array | Purpose |
|---|---|---|
| `program.json` | `days` | Day by day plan; references exercises by id |
| `exercises.json` | `exercises` | Every exercise definition |
| `letters.json` | `letters` | Turkish letter ladders (syllables, words) |
| `tongue_twisters.json` | `tongueTwisters` | Twister library |
| `speaking_challenges.json` | `challenges` | Speaking prompts |

## Offline principle

**A user must be able to open the app with no network and still run a full day of training.**
`ARCHITECTURE.md` states the rule; this section states what it costs the schema.

1. All five files ship inside the app bundle. They are declared under `flutter: assets:` in
   `pubspec.yaml` as `assets/content/`, so they are present from first launch, before any sign in.
2. **No field in this schema may require a network call to render an exercise.** Everything a screen
   needs to draw and run an exercise is in the file: title, instructions, duration, and the type
   specific config.
3. Curriculum never moves to Firestore. `FIRESTORE_MODEL.md` fixes that boundary: Firestore holds
   user progress, not content.
4. Media follows the same rule. `media.key` resolves to a bundled asset for MVP. If HIT-013 later
   adds a remote template for the same key, remote delivery must be an **optimisation with a local
   fallback**, never a precondition for the exercise to run.
5. Cross file references resolve entirely inside the bundle, which is why the schema test enforces
   them. A dangling reference would surface as a broken exercise on a device with no connection to
   recover from.

Progress writes (HIT-052, HIT-053) do need connectivity. That is a separate concern and surfaces
through the domain `Failure` types, never by blocking the exercise itself.

## Envelope

Every file starts with the same envelope:

```json
{
  "schemaVersion": "1.0.0",
  "contentVersion": "0.1.0",
  "status": "placeholder",
  "locale": "tr-TR"
}
```

| Field | Rule |
|---|---|
| `schemaVersion` | Semver for the *structure*. Bump when fields are added, renamed, or removed. Parsers must reject a major version they do not know. |
| `contentVersion` | Semver for the *content*. Bump on any copy change. Lets caching and analytics tell content revisions apart without a schema change. |
| `status` | `placeholder` or `approved`. HIT-080 flips this to `approved`. The app may ship `placeholder` content in development builds only. |
| `locale` | BCP 47 tag. MVP is `tr-TR`. |

Two separate version fields matter because content changes far more often than structure. A copy fix
must not look like a breaking schema change.

## Identifiers

- Lowercase ASCII, `[a-z0-9_]` only. No spaces, no Turkish characters, no uppercase.
- **Stable forever.** Once an id ships it is never renamed and never reused for different content,
  because completion records in Firestore point at these ids (HIT-052, HIT-053).
- Prefix by file: tongue twisters use `tt_`, speaking challenges use `sc_`. Exercises use
  `<topic>_<slug>_<nn>`. Letters are keyed by `key`, a lowercase form of the letter.

### Turkish letter keys

`letters[].key` must stay inside `[a-z0-9_]`, but the Turkish alphabet is the whole subject of this
app, so the six non ASCII letters get a fixed, reversible transliteration. The display form always
lives in the separate `letter` field, so nothing is lost.

| Letter | `key` | Letter | `key` |
|---|---|---|---|
| ç | `c_cedilla` | ö | `o_umlaut` |
| ğ | `g_breve` | ş | `s_cedilla` |
| ı | `i_dotless` | ü | `u_umlaut` |

Every other letter is simply its own lowercase ASCII form (`r`, `s`, `t`). Note that `i` and `ı` are
distinct letters in Turkish and must never collapse to the same key, which is exactly why `ı` gets
`i_dotless` rather than a lowercasing rule.

## Presentation types

`presentationType` is stored as a **string**, not an integer, so unknown values stay readable in logs
and diffs.

| Value | Consumed by | Extra config block |
|---|---|---|
| `text` | generic container | none |
| `timer` | generic container | none |
| `audio` | audio player | `media` |
| `breathing` | HIT-029 / HIT-030 | `breathing` |
| `rive` | HIT-032 / HIT-033 | `media` |
| `articulation` | HIT-034 to HIT-037 | `media` |
| `letter` | HIT-038 | `letter` |
| `tongueTwister` | HIT-040 to HIT-042 | `tongueTwister` |
| `emphasis` | HIT-043 | `emphasis` |
| `intonation` | HIT-044 | `intonation` |
| `pause` | HIT-045 | `pause` |
| `timedReading` | HIT-046 / HIT-047 | `timedReading` |
| `speakingChallenge` | HIT-048 / HIT-049 | `speakingChallenge` |

**Extensibility rule.** A parser that meets a `presentationType` it does not recognize must map it to
an `unknown` value and skip the exercise, never throw. This lets a newer content file ship to an older
client without crashing it.

**Pairing rule.** An exercise carries **at most one** type specific config block, and if present it
must match its `presentationType`. `text` and `timer` carry none.

## Media references

Media is never a hard coded path inside a screen. It is a reference object resolved by one media
resolver:

```json
"media": { "kind": "rive", "key": "ux_lips", "stateMachine": "LipStates" }
```

| Field | Rule |
|---|---|
| `kind` | `rive`, `audio`, or `image` |
| `key` | Bare asset key, no folder and no extension |
| `stateMachine` | `rive` only; the state machine to drive |

The resolver builds the real location from `kind` and `key`. For MVP that is a local bundle path
(`assets/rive/<key>.riv`). HIT-013 may add a remote URL template for the same key without any change
to content files or screens. That indirection is the whole point: swapping the delivery mechanism must
not touch the curriculum.

## Type specific config blocks

```json
"breathing":         { "inhaleSeconds": 4, "holdSeconds": 2, "exhaleSeconds": 6, "cycles": 5 }
"letter":            { "letterKey": "r", "repetitions": 3 }
"tongueTwister":     { "tongueTwisterIds": ["tt_r_01"], "repetitions": 2 }
"emphasis":          { "text": "...", "emphasisWordIndexes": [0, 3] }
"intonation":        { "text": "...", "contour": [{ "wordIndex": 0, "direction": "rise" }] }
"pause":             { "text": "...", "pauseAfterWordIndexes": [2], "pauseMilliseconds": 400 }
"timedReading":      { "text": "...", "targetWordsPerMinute": 140 }
"speakingChallenge": { "challengeId": "sc_intro_60" }
```

Word positions are **indexes into the whitespace split of `text`**, zero based. Storing indexes rather
than marked up copy keeps the text reusable and keeps the markup out of the translator's way.

`contour.direction` is `rise`, `fall`, or `flat`.

## Cross file references

These must resolve, and the schema test enforces all four:

| Reference | Must exist in |
|---|---|
| `program.days[].exerciseIds[]` | `exercises.json` |
| `letter.letterKey` | `letters.json` |
| `tongueTwister.tongueTwisterIds[]` | `tongue_twisters.json` |
| `speakingChallenge.challengeId` | `speaking_challenges.json` |

## Enumerations

- `tongueTwisters[].difficulty`: `easy`, `medium`, `hard`
- `tongueTwisters[].category`: `letter`, `rhythm`, `breath`
- `media.kind`: `rive`, `audio`, `image`
- `contour[].direction`: `rise`, `fall`, `flat`

## Dart models

**Implemented by HIT-022** in `lib/features/training/domain/models/`, following the plan below.
`models.dart` re-exports the set, so a caller imports one file.

What landed there is the exercise side only: `Exercise`, `ExercisePresentationType`,
`MediaReference`, the eight config classes, and `ContentEnvelope`. `ExerciseLibrary` parses
`exercises.json` as a whole, given an already decoded map, so the schema version guard has an owner
and nothing in the model layer touches the asset bundle. Reading the bytes is HIT-024's job.
`TrainingProgram` and the day plan belong to HIT-023.

The three entities an exercise references by id are modelled by **HIT-024**: `LetterLadder`,
`TongueTwister` and `SpeakingChallenge`, each with a small library type that parses its own file the
way `ExerciseLibrary` does. Two of their fields carry decisions worth repeating here, because both
came out of the shipped content rather than from the shape a reader might assume:

- `TongueTwister.targetLetter` is **optional**. A rhythm or breath twister trains pace or breath
  control and is not about any single sound, so it carries no target letter. Two of the three
  twisters that ship today leave it null.
- `difficulty` and `category` fall back to `unknown` but the record is **kept**, unlike an unknown
  presentation type, which makes an exercise unrenderable and gets it skipped. Neither field decides
  whether the drill works, so a newer file that adds a level is still speakable on an older build.
  An absent value is allowed; a wrong-typed one is still an error.

The plan those models follow:

- Immutable classes with `const` constructors and `final` fields.
- Hand written `factory X.fromJson(Map<String, dynamic>)`. **No codegen package.**
  `CONTRIBUTING.md` forbids unrequested dependencies, and these files are small and stable enough that
  `json_serializable` or `freezed` would cost more than they return.
- `ExercisePresentationType` as an `enum` with an `unknown` member, parsed through a lookup that falls
  back to `unknown` instead of throwing.
- Value equality via `==` and `hashCode` overrides, so models compare by content in tests and in
  Riverpod state.
- Type specific config as separate small classes, nullable on `Exercise`, exactly one non null.

Suggested location, following the feature first layout in `ARCHITECTURE.md`:

```text
lib/features/training/domain/models/
```

## Repository

Implemented by **HIT-024** as `CurriculumRepository` in `domain/repositories/`, with
`AssetCurriculumRepository` in `data/` reading the app bundle. Keeping the interface in `domain/` and
the bundle reader in `data/` means a later remote or cached source can be swapped in without touching
any caller.

```dart
abstract interface class CurriculumRepository {
  Future<TrainingProgram> loadProgram();
  Future<ExerciseLibrary> loadExercises();
  Future<LetterLadderLibrary> loadLetters();
  Future<TongueTwisterLibrary> loadTongueTwisters();
  Future<SpeakingChallengeLibrary> loadSpeakingChallenges();
}
```

**Library types, not bare lists.** The plan drafted here originally returned `List<Exercise>` and the
like. That loses two things the caller needs. The library carries the file's envelope, so a caller can
tell which content version it is looking at; and for exercises it carries `skippedIds`, the exercises
this build could not render. Dropping those would hide the reason a day is running short, which is the
one thing the extensibility rule above exists to make visible. `ProgramDay.resolve` also takes an
`ExerciseLibrary`, so a list would only force every caller to rebuild what had been thrown away.

**Lookups are not repeated on the repository.** `byId`, `byKey` and `byCategory` live on the library
types, next to the data they search. The implementation caches, so asking twice costs one read and a
lookup through the library is as cheap as a method on the repository would be.

**A failed read is not cached.** A successful read is remembered and shared, so two screens opening
together cause one read. A failure is deliberately forgotten: the error surface offers the user a
retry, and a cached failure would hand back the same broken future for the rest of the session, so
the button would do nothing.

## Validation

`test/content/content_schema_test.dart` reads the five files from disk and checks the envelope, the
required fields, the types, id uniqueness, the enumerations, the pairing rule, and the four cross file
references.

That test deliberately does **not** use Dart models. Model parsing tests belong to HIT-022. This one
answers a narrower question: does the JSON on disk match the schema documented above.
