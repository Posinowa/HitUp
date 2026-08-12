# Security Policy

## Supported versions

HitUp currently supports security fixes on:

- `main` (production / release line)
- current `develop` integration work when relevant to unreleased fixes

There is no older published store version yet.

## Reporting a vulnerability

**Do not** publicly disclose secrets, private keys, or exploit details in GitHub Issues.

If GitHub private vulnerability reporting is enabled for this repository, use:

**Security → Report a vulnerability** on the repository page.

If private reporting is unavailable, contact a Posinowa repository administrator through your internal team channel. Do not invent or publish a personal email here.

## Secrets policy

Never commit:

- `.env` files with secrets
- Firebase Admin / service-account private keys
- Cloudflare R2 Access Key ID / Secret Access Key / API tokens
- Apple `.p8` / `.p12` / distribution private material
- Google Play service-account JSON
- Android release keystores (`.jks` / `.keystore`) and passwords
- GitHub tokens or any privileged API credentials

### Firebase client config vs admin secrets

Mobile client files such as `google-services.json`, `GoogleService-Info.plist`, and `firebase_options.dart` are **not** equivalent to Firebase Admin SDK private keys.

Security must rely on:

- Firebase Authentication
- Firestore Security Rules
- correct app configuration

Never commit Admin SDK credentials.

### Cloudflare R2

MVP media is **read-only** static distribution. The Flutter client must never embed R2 write credentials.

### Hardcoded secrets

Do not hardcode privileged credentials in Dart:

```dart
const apiKey = 'secret...'; // FORBIDDEN for privileged services
```

Anything shipped inside an APK/IPA must be considered **inspectable by the user**. Privileged server credentials cannot safely live in Flutter. Obfuscation is not a security control for secrets.

If a future feature needs a privileged credential, it requires a separate architecture / security review (and must not invent a custom backend without explicit product approval).

## Mobile client trust model

```text
Anything shipped in APK/IPA must be considered inspectable by the user.
```

Therefore privileged secrets cannot exist in the Flutter application.

## Custom backend

HitUp has **no custom backend**. Do not introduce `backend/`, `server/`, `functions/`, or Cloud Functions to “solve” secret handling without an approved architecture change.

`com.posinowa.hitup` is the Android `applicationId` / iOS bundle identifier — **not** a domain, API host, or server URL.

## Firestore

Users must only access their own data. Open/test-mode Firestore rules are not acceptable for production.

## CI / CodeQL

Dart is not covered by GitHub CodeQL as a first-class language for this project. Security gating uses Flutter analyzer, tests, Dependency Review, Dependabot, secret scanning, credential-file guards, and Android/iOS build validation instead.

## Permission changes

PRs that modify `android/app/src/main/AndroidManifest.xml` or `ios/Runner/Info.plist` require CODEOWNER review and must explain any new microphone, notification, camera, storage, or related permissions. Camera permission is not part of HitUp MVP.
