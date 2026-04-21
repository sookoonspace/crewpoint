## Overview

Server-side account deletion via Firebase Callable Cloud Function. Flutter client re-authenticates, calls function, clears local data. Server handles anonymization, ownership transfer, and Auth deletion atomically.

## Context

- **Current state**: `DeleteAccountDialog` exists (UI only, not wired); `ProfileScreen` has `onDeleteAccount` callback (unused); no `cloud_functions` package; no `functions/` directory
- **Architecture**: Flutter calls `httpsCallable('deleteUserAccount')` → Cloud Function handles all Firestore/Storage/Auth cleanup → Flutter clears local state
- **Key decision**: Shared data (messages, expenses) anonymized server-side (`senderId`/`payerId` → `'deleted_user'`); solo events hard-deleted; shared events transfer ownership to next member
- **Dialog copy**: Must explicitly state what happens to shared data per Sookoon privacy standards

## Plan

### Phase 1: Cloud Function (Node.js/TypeScript)

- **Goal**: `deleteUserAccount` callable function handling the full server-side deletion
- [x] `functions/package.json` — Init Node.js project with `firebase-functions`, `firebase-admin`
- [x] `functions/src/index.ts` — `deleteUserAccount` callable with all 8 steps
- [x] **CRITICAL — 500-doc batch limit**: `commitInChunks()` helper processes all operations in sequential 500-doc batches
- [x] Set function timeout to 120s (`runWith({ timeoutSeconds: 120 })`)
- [x] `functions/tsconfig.json` — TypeScript config
- [x] `firebase.json` — Added `functions` section
- [x] Deploy instructions documented (per-flavor with `--project` flag)

### Phase 2: Flutter Client Wiring

- **Goal**: Wire delete flow: dialog → dynamic re-auth → call function → clear local → navigate out
- [ ] `pubspec.yaml` — Add `cloud_functions: ^5.3.3`
- [ ] `lib/app/core/services/account_deletion_service.dart` — Service that:
  1. Determines auth provider from `FirebaseAuth.instance.currentUser.providerData`
  2. Re-authenticates using the correct method (email/password credential OR Google/Apple re-sign-in)
  3. Calls `FirebaseFunctions.instance.httpsCallable('deleteUserAccount').call()`
  4. On success: clears Drift DB (all tables), clears `flutter_secure_storage`, signs out
  5. Returns success/failure result
- [ ] `lib/app/features/profile/presentation/widgets/delete_account_dialog.dart` — Rewrite:
  - Step 0 (Warning): "This action is permanent. Your profile, solo events, and local data will be erased. Financials and messages in shared events will be anonymized to protect group integrity."
  - Step 1 (Dynamic Re-Auth): Check `user.providerData` — if email provider → show password field; if Google → show "Sign in with Google to confirm" button; if Apple → show "Sign in with Apple to confirm" button
  - Step 2 (Processing): Loading overlay with `LoadingAnimation` during function call
  - Step 3 (Done): On success → pop dialog, clear local state, navigate to onboarding
- [ ] `lib/app/features/profile/presentation/profile_screen.dart` — Wire `onDeleteAccount` to show dialog → call deletion service
- [ ] `lib/app/core/providers.dart` — Add `accountDeletionServiceProvider`
- [ ] TDD: deletion service clears all Drift tables on success
- [ ] TDD: deletion service returns failure if function call throws
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 3: Update Setup Guide

- **Goal**: Document Cloud Function deployment steps
- [ ] `ai_specs/setup-guide.md` — Add new section "11. Cloud Functions" covering:
  - `firebase init functions` (if starting fresh)
  - Environment setup (Node 18+, TypeScript)
  - Per-flavor deploy: `firebase deploy --only functions --project crewpoint-dev`
  - Testing locally with Firebase emulator suite (`firebase emulators:start`)
  - Note: must deploy to all 3 projects separately
- [ ] Verify: guide is consistent with new `firebase.json` structure

## Risks / Out of scope

- **Risks**:
  - Cloud Function timeout: set to 120s, but users with thousands of messages across many events could still exceed. Mitigation: log progress, consider async queue for very large accounts in V2
  - Storage folder deletion requires listing all files first (`bucket.getFiles({ prefix })`) — may need pagination for users with many uploads
- **Out of scope**:
  - GDPR data export (right to portability) — separate feature
  - Soft-delete / grace period — V2 consideration
  - Admin dashboard for manual deletion requests
  - Biometric re-auth (Phase 2 deferred feature)
