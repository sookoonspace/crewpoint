## Overview

Replace manual Firebase config (envied placeholders + plist/json copying) with `flutterfire_cli`-generated `firebase_options.dart`. Patch Firestore security rules to enforce event ownership, membership, and expense access.

## Context

- **Current approach**: `firebase_service.dart` reads keys from `Env` (placeholder constants); setup-guide instructs manual `google-services.json` / `GoogleService-Info.plist` per flavor + envied
- **Target approach**: `flutterfire configure` generates `firebase_options.dart` per flavor; no manual file copying; no envied for Firebase keys
- **Security holes in current rules**:
  - Events: any auth'd user can write/delete any event (no creator check)
  - Events/messages: no membership enforcement — any auth'd user sees all events and messages
  - Expenses: no rules at all
- **Reference**: `lib/app/core/services/firebase_service.dart`, `lib/app/core/env/env.dart`, `ai_specs/setup-guide.md`

## Plan

### Phase 1: FlutterFire CLI Setup & Code Changes

- **Goal**: Replace manual Firebase config with `flutterfire configure` output
- [x] `ai_specs/setup-guide.md` — Rewrite Section 1 (Firebase Project Setup):
  - Remove "Register Android/iOS Apps" manual steps
  - Remove "Place google-services.json in flavor dirs" instructions
  - Replace with: install `flutterfire_cli` (`dart pub global activate flutterfire_cli`), run `flutterfire configure` per flavor, generating `lib/firebase_options_{flavor}.dart`
  - Document: `flutterfire configure --project=crewpoint-dev --out=lib/firebase_options_dev.dart --platforms=android,ios,web`
  - Repeat for stg/prod
- [x] `ai_specs/setup-guide.md` — Rewrite Section 2.4 (GoogleService-Info.plist Copy Phase):
  - Remove the entire Run Script build phase — `flutterfire configure` handles plist placement
  - Note: Xcode scheme setup (2.1–2.3) still needed for bundle IDs; keep those sections intact
- [x] `ai_specs/setup-guide.md` — Rewrite Section 3 (Environment Variables & Envied):
  - Remove Firebase keys from `.env` files (no longer needed)
  - Keep envied for non-Firebase secrets only (future API keys, etc.)
  - Update `env.dart` section to note Firebase keys are in generated `firebase_options_{flavor}.dart`
- [x] `lib/app/core/services/firebase_service.dart` — Replace `Env`-based `FirebaseOptions` with import of generated `firebase_options_{flavor}.dart`; select correct options based on `AppFlavor`
- [x] `lib/app/core/env/env.dart` — Remove Firebase key placeholders; keep class skeleton for future non-Firebase secrets
- [x] `.env.dev`, `.env.stg`, `.env.prod` — Remove `FIREBASE_*` keys; add comment noting Firebase config is auto-generated
- [x] `android/app/build.gradle.kts` — Verified: `com.google.gms.google-services` will be added by `flutterfire configure` when run
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 2: Firestore Security Rules Hardening

- **Goal**: Enforce ownership, membership, and per-collection access control
- [x] `ai_specs/setup-guide.md` — Replace Section 6 (Firestore Security Rules) with hardened rules:
  - **Events**: `create` only if `request.auth.uid == request.resource.data.creatorId`; `update/delete` only if `request.auth.uid == resource.data.creatorId`; `read` only if user is creator or in `members` array
  - **Messages**: `read/write` only if user is member of parent event; `create` requires `senderId == request.auth.uid`; `delete` only own messages
  - **Expenses**: `read` only if member of parent event; `create` requires `payerId == request.auth.uid`; `delete` only by creator or payer
  - **Users**: `read` if authenticated; `write` only own document (already correct)
- [x] `firestore.rules` — Create rules file at project root for version control
- [x] `firebase.json` — Create config pointing to `firestore.rules` for CLI deploy
- [x] Verify: review rules against spec requirements (no automated test for rules)

## Risks / Out of scope

- **Risks**:
  - `flutterfire configure` requires Firebase CLI auth + project access — fails if not logged in
  - Per-flavor `firebase_options_{flavor}.dart` files are gitignored by default — must decide: commit them (convenient) or regenerate in CI (secure)
  - Membership array on events must be populated by app code — rules depend on it existing
- **Out of scope**:
  - Firebase CLI installation instructions (link to official docs)
  - CI/CD pipeline for rules deployment
  - Firestore indexes
  - Firebase App Check
