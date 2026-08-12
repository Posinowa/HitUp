# Cloudflare R2 Media Architecture

**STATUS: DRAFT / DOCUMENTATION-FIRST**

## MVP decision

- Rive exercise animations for MVP **should be bundled locally** under `assets/rive/` where practical.
- Do **not** require R2 merely to display the first U-X Rive exercise.
- **No dedicated Remote Media Client issue** is required for MVP foundation.
- If remote media becomes necessary later, implement HTTP GET-only against public/read-only URLs with loading/failure/fallback — still **no** Access Key / Secret / upload / signed-write generation in the Flutter app.

## Allowed use

- Larger instructional audio
- Optional video (not default teaching medium)
- Heavy downloadable static assets

## Forbidden

- Embedding Cloudflare Access Key ID or Secret in Dart, `.env`, assets, Android, or iOS configs
- Uploading from the Flutter client (including user audio)
- Treating R2 as a private write API without a future trusted signing architecture (out of MVP)

## App configuration

Public base URL (if any) may live in non-secret config (`AppConfig.remoteMediaBaseUrl`). Never put write credentials there.
