## Overview

Add `promoteToAdmin` and `demoteAdmin` Cloud Functions to secure RBAC flow. Wire member management UI to call CFs instead of direct Firestore writes. Update Cloud Functions deployment guide.

## Context

- **Security gap**: `member_management_screen.dart` has a TODO for promote/demote — currently no server-side enforcement. Client-side `adminIds` mutation is a privilege escalation vulnerability.
- **Pattern**: Follow existing `removeEventMember.ts` structure (onCall, owner verification, arrayUnion/Remove)
- **Reference**: `functions/src/events/removeEventMember.ts`, `lib/app/features/dashboard/presentation/member_management_screen.dart`

## Plan

### Phase 1: Cloud Functions + Client Wiring

- **Goal**: Server-side promote/demote + wire UI
- [x] `functions/src/events/promoteToAdmin.ts` — caller must be creatorId; verify target in memberIds; add target to adminIds via arrayUnion
- [x] `functions/src/events/demoteAdmin.ts` — caller must be creatorId; verify target in adminIds; remove target from adminIds via arrayRemove (stays in memberIds)
- [x] `functions/src/index.ts` — export both new functions
- [x] `npm run build` — verify TypeScript compiles
- [x] `lib/app/features/dashboard/presentation/member_management_screen.dart` — replace `_toggleAdmin` TODO with CF calls (`promoteToAdmin` / `demoteAdmin`); add loading state + error snackbar
- [x] `docs/cloud-functions-guide.md` — add `promoteToAdmin` and `demoteAdmin` to Function Registry table
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Out of scope**: Web CORS config, PDF export CFs, `deleteUserAccount` edge case (valid for V1, noted for V2)
