# MVP Diction Curriculum

**STATUS: DRAFT, OWNER / CONTENT APPROVAL REQUIRED (HIT-080)**

Every file under `assets/content/` carries `"status": "placeholder"` and keeps it until that approval is recorded on #82. Flipping the five files to `approved` is one line per file and belongs to whoever signs the text off.

This is the curriculum HIT-080 asks for: which exercises exist, in what order, how long each lasts, and where each decision came from. The Turkish text itself lives in `assets/content/`, so the app has one source of truth and this document explains it.

Two documents sit behind it:

- [`CURRICULUM_SOURCE.md`](CURRICULUM_SOURCE.md): the page-cited material the facts come from, and the decisions taken on #82 on 14 September 2026.
- [`../architecture/CONTENT_SCHEMA.md`](../architecture/CONTENT_SCHEMA.md): the shape these files have to keep.

## What is authored and what is sourced

The decision on #82 draws the line: **the app does not reproduce source text.** Every Turkish sentence in `assets/content/` is written for HitUp. The sources supply facts, and only these:

| Fact | Source |
|---|---|
| Breathing ratio, one second in, four held, two out | S1 p.14, S2 p.3 |
| Ten repetitions is a session's limit | S2 p.3 |
| Around fifteen minutes a day, across two weeks | S1 p.13, p.15 |
| Which techniques exist for tongue, jaw and lips | S1 p.45-46 |
| A letter drill is a sentence loaded with one sound | S1 p.47-50 |
| Say a drill slowly first, then faster | S1 p.47 |

The rapid panting exercise and the *Akıncılar* excerpt are excluded, both by the decision on #82.

## Shape of a day

Every day runs the order #82 settled: **breathing, then articulation, then a text exercise.**

1. **Breathing.** One exercise at the sourced ratio, growing from five repetitions to ten across the programme, never past ten in one session.
2. **Articulation.** Three exercises, one each for tongue, jaw and lips, rotating through three drills apiece so no day repeats the day before.
3. **Letter.** One Turkish letter, with syllables and example words.
4. **Text exercise.** A tongue twister set or a timed reading, alternating.
5. **From day 6, one expression drill**: emphasis, intonation or pause, and a speaking task in the last three days.

A day lasts 13 to 16 minutes. No day's length is typed by hand: `content_schema_test.dart` fails if `estimatedMinutes` does not match the exercises the day lists.

## The fourteen days

Articulation is one tongue, one jaw and one lip drill every day, rotating, so the table leaves them out.

| Day | Focus | Breathing repetitions | Letter | Text exercise | Also | Minutes |
|---|---|---|---|---|---|---|
| 1 | The basis of breath | 5 | A | easy twisters | opening card | 14 |
| 2 | Settle the rhythm | 6 | E | R and L twisters | silent warm-up | 14 |
| 3 | Tongue tip, and İ | 7 | İ | timed reading 1 | | 13 |
| 4 | Back vowels | 8 | I | sibilant twisters | | 13 |
| 5 | Rounded vowels | 10 | O | timed reading 2 | | 13 |
| 6 | Lip vowels | 10 | U | lip twisters | intonation 2 | 15 |
| 7 | Meet the pause | 10 | P | tempo twisters | pause 1 | 15 |
| 8 | The hissing breath | hiss, 6 | B | timed reading 1 | emphasis 1 | 14 |
| 9 | One line, one breath | 10 | M | single-breath twisters | intonation 1 | 15 |
| 10 | Sibilants | 10 | S | timed reading 2 | pause 2 | 15 |
| 11 | Ş against S | 10 | Ş | hard twisters | emphasis 2 | 15 |
| 12 | Hear the intonation | hiss, 6 | Z | timed reading 1 | speaking task 2 | 15 |
| 13 | Into speaking | 10 | L | R and L twisters | speaking task 1 | 15 |
| 14 | R day, and pulling it together | 10 | R | hard twisters | speaking task 3 | 16 |

The letters run from the ones that open the mouth to the ones people most often stumble on: vowels first, then the lip consonants, then S, Ş, Z, L and R. The hissing breath on days 8 and 12 is S1's exercise III, the same ratio with the exhale voiced as a hiss.

## What ships

| File | Contents |
|---|---|
| `program.json` | 14 days, 6 or 7 exercises each |
| `exercises.json` | 52 exercises, covering all 13 presentation types |
| `letters.json` | 14 letters, each with 5 syllables and 3 example words |
| `tongue_twisters.json` | 12 original twisters: 8 by letter, 2 by rhythm, 2 by breath; 3 easy, 5 medium, 4 hard |
| `speaking_challenges.json` | 3 original prompts, 60 to 120 seconds |

Every twister and every prompt is written for this app. HIT-041 asks for at least ten twisters; there are twelve.

## Safety

Every breathing exercise opens with the same sentence, as the first line of the instructions rather than a separate screen, so it cannot be skipped or drift away from the exercise it belongs to:

> Başın döner ya da sersemlersen dur, normal nefesine dön.

No breathing exercise exceeds ten repetitions, which is S2's limit and the stricter of the two sources. The rapid panting drill is not in the app.

**This is a posture, not a sign-off.** #82 says the final breathing text must be reviewed by someone qualified before any public release, and that item is still open.

## Deferred, with the issue that closes it

| Deferred | Why | Issue |
|---|---|---|
| The audio exercise is not scheduled | there is no audio file yet | HIT-013 |
| The Rive sample is not scheduled | there is no animation yet | HIT-032 |
| The U and X lip exercise is not scheduled | its animation belongs to the articulation work | HIT-034 |
| Letters beyond the fourteen | fourteen days, one letter each | HIT-039 |
| A second source for twisters | the twelve here are original, so the MVP needs none | |

Those three unscheduled exercises stay in `exercises.json` on purpose: the renderers being built need a fixture to build against, and `content_schema_test.dart` names them, so a fourth orphan cannot hide among them.

## Changing this content

- **Ids are permanent.** Completion records in Firestore point at them (HIT-052, HIT-053). Add an exercise rather than renaming one.
- **Durations belong to the exercise.** A breathing exercise's `durationSeconds` equals its own cycles, and a day's `estimatedMinutes` equals its exercises. Both are tested.
- **Bump `contentVersion`** on any copy change. `schemaVersion` moves only when the shape does.
- **Example words** must contain their letter under Turkish case rules, which the schema test checks: I lowers to ı, and İ lowers to i.

## Approval checklist

- [ ] The Turkish text reads naturally and carries no errors
- [ ] The breathing text is reviewed by someone qualified
- [ ] The safety notice is judged sufficient for unsupervised use
- [ ] The programme shape, fourteen days at about fifteen minutes, is accepted
- [ ] `status` is flipped to `approved` in all five files
