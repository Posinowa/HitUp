# Cloudflare R2 Media Architecture

**STATUS: APPROVED (HIT-013).** The MVP decision below is settled: media is bundled, R2 is
documented for later. `CONTENT_SCHEMA.md` (HIT-012) owns the reference format this builds on
and is merged.

## MVP decision

- Rive exercise animations for MVP **should be bundled locally** under `assets/rive/` where practical.
- Do **not** require R2 merely to display the first U-X Rive exercise.
- **No dedicated Remote Media Client issue** is required for MVP foundation.
- If remote media becomes necessary later, implement HTTP GET-only against public/read-only URLs with loading/failure/fallback, still **no** Access Key / Secret / upload / signed-write generation in the Flutter app.

## Allowed use

- Larger instructional audio
- Optional video (not default teaching medium)
- Heavy downloadable static assets

**Gap found while writing this doc: video has no schema support yet.** `CONTENT_SCHEMA.md`'s
`media.kind` enum is `rive`, `audio`, or `image` only, nothing named `video` exists anywhere in it.
This "allowed use" line predates that schema and was never reconciled with it. Until a `video` kind is
added to `CONTENT_SCHEMA.md` (a HIT-012-owned change, not this doc's), there is no way to actually
reference a video from a content file. Treat this line as aspirational, not implemented.

## Forbidden

- Embedding Cloudflare Access Key ID or Secret in Dart, `.env`, assets, Android, or iOS configs
- Uploading from the Flutter client (including user audio)
- Treating R2 as a private write API without a future trusted signing architecture (out of MVP)

## The media reference, and where it comes from

Content files (`assets/content/*.json`) never hold a path. They hold a reference:

```json
"media": { "kind": "rive", "key": "ux_lips", "stateMachine": "LipStates" }
```

`kind` is `rive`, `audio`, or `image`. `key` is a bare identifier, `[a-z0-9_]+`, no folder and no
extension, matching the same id pattern the rest of the curriculum schema uses. This part is owned by
`CONTENT_SCHEMA.md` (HIT-012), not by this document. What belongs here is what happens to that
reference once a screen needs the actual bytes.

## Asset key naming

A key names *what* the media is, never *where* it lives. `ux_lips`, not `rive/ux_lips_v2`. That is
what lets the same key resolve to a bundled asset today and a remote URL later without the content
file changing.

This doc's resolver treats `kind` plus `key` as the identity, not `key` alone, so `audio` and `rive`
can each safely have a key called `intro` without colliding. Nothing enforces this yet: the schema test
checks key format, and HIT-022's models reject a key carrying a folder or an extension, but neither one
checks whether two exercises of the same kind reuse a key for different assets. That gap belongs to the
resolver, since the collision only becomes real once a key is turned into a location.

## Resolving a key

For MVP every `kind` resolves locally. The formula is the folder `pubspec.yaml` already declares for
that kind, plus the key, plus the kind's extension:

| `kind` | Local path | Extension |
|---|---|---|
| `rive` | `assets/rive/<key>.riv` | `.riv`, fixed by the Rive format itself |
| `audio` | `assets/audio/<key>.<ext>` | not yet decided, no audio player package is chosen yet |
| `image` | `assets/images/<key>.<ext>` | not yet decided, no format has been picked yet |

`.riv` is verified: `CONTENT_SCHEMA.md` already states that exact path formula. The other two rows are
placeholders in the folder shape only. Whoever picks the audio player package (a separate decision,
likely alongside HIT-050) fixes the audio extension then; this doc should be updated at that point
rather than guessed at now.

When a remote source is needed later, the same key resolves against a base URL instead:

```text
<AppConfig.remoteMediaBaseUrl>/<kind>/<key>.<extension>
```

Same folder-like shape as the local path, on purpose: a person reasoning about where a key lives does
not need to hold two different mental models for local and remote.

## The `MediaAssetRef` model, and what it is not

```text
MediaAssetRef
  kind: MediaKind (rive | audio | image)
  key: String
  resolvedUri: Uri          // file:// or local asset path today, https:// once R2 is live
  source: MediaSource       // bundled | remote
```

The resolver is the only thing that constructs a `MediaAssetRef`. A screen receives one and never
builds a path itself, the same rule the design tokens (HIT-008) apply to colors: never spell out the
concrete value, always ask the layer whose job it is to know.

**This is a contract, not something that exists yet, and it is not what HIT-022 built.** Two different
objects are easy to confuse here:

| | Holds | Owned by |
|---|---|---|
| `MediaReference` | `kind` and `key`, exactly as written in the content file | HIT-022, implemented |
| `MediaAssetRef` | the same key already resolved to a `resolvedUri` and a `source` | whoever writes the resolver, not yet written |

HIT-022 deliberately stopped at the first one. A model that parses content has no business knowing
whether an asset ships in the bundle or arrives over the network, and giving it that knowledge is how
a domain model ends up importing the asset bundle. The resolver is the layer that knows, and it does
not exist until something needs remote media.

## Loading, failure, and fallback

A remote fetch can fail in ways a bundled asset cannot: no connection, a 404 because a key was
retired, a slow network. None of that is new error surface. It goes through the same mapper HIT-066
already built:

- Missing bundled asset -> `FailureCode.contentAssetMissing`
- A key present in content but never resolvable (bad data) -> `FailureCode.contentMalformed`
- A remote media fetch that fails -> `FailureCode.contentMediaUnavailable`

There is no separate "media error" concept. Whatever fetches the bytes catches its own exception and
lets `mapErrorToFailure` turn it into one of the codes above, the same as everything else in the app.
The fallback behavior for MVP is simple because MVP has no remote media: if a bundled asset key does
not resolve, that is a content bug caught by the schema test, not a runtime condition to design a
graceful fallback for.

**What the screen shows in place of the failed media is not decided here.** `showFailureSnackBar` and
`showFailureDialog` (HIT-066) tell the user something went wrong, but neither one replaces a missing
image or a broken Rive animation with a placeholder graphic in the layout itself. That is a widget-level
decision for whichever issue builds the first screen that renders remote media (likely alongside
HIT-033, the Rive renderer), not something this architecture doc can answer without a screen to answer
it for.

## Caching

Bundled assets need no caching, they ship with the app. For a future remote source, the platform HTTP
cache (respecting standard cache headers on the R2 object) is the starting point, not a hand rolled
disk cache. Do not build a custom cache layer before there is a single remote asset that needs one.

## How an intern adds a new remote audio URL safely

1. Upload the file to the R2 bucket at `<kind>/<key>.<extension>`, matching the table above.
2. Add or update the content JSON entry with `"media": { "kind": "audio", "key": "<key>" }`. Never
   put a URL in the content file.
3. Confirm `AppConfig.remoteMediaBaseUrl` is the only place the bucket's public base URL is
   configured, and that it is not a secret (it is a public read URL, not a credential).
4. Never touch Cloudflare Access Key ID or Secret to do this. If a step seems to require them,
   stop, that step does not belong in this flow.

## App configuration

Public base URL (if any) may live in non-secret config (`AppConfig.remoteMediaBaseUrl`). Never put
write credentials there.

`AppConfig` already has a `development` / `production` `Environment`, but `remoteMediaBaseUrl` is one
constant, not environment-specific. That is fine while it is `null` and nothing reads it. Whoever
turns on the first remote asset needs to decide then whether dev and prod point at different buckets;
this doc does not answer that question because there is no remote asset yet to make it concrete.

## Related docs

- [`CONTENT_SCHEMA.md`](CONTENT_SCHEMA.md), owns the media reference format itself
- [`ERROR_HANDLING.md`](ERROR_HANDLING.md), owns how a failed fetch becomes a `Failure`

`ERROR_HANDLING.md` and the three `FailureCode` values named above arrive with HIT-066, which is
approved and not yet merged. That link is dead until it lands. The codes were checked against that
branch rather than assumed, so nothing here has to change when it merges; this note goes away instead.

---

**What is settled here and what is not.** The MVP decision, the forbidden list, the key naming rule
and the local resolution formula are decided; nothing later should reopen them without a reason.
Three things are deliberately left open, each with its owner named in the section above: the audio and
image file extensions, whether dev and prod ever point at different buckets, and what a screen draws
in place of media that failed to load. Each of them needs a real asset or a real screen to answer it,
and guessing now would only put a wrong answer in a document people trust.
