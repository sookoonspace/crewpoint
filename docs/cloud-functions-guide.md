# CrewPoint — Cloud Functions Deployment Guide

Living document for deploying and managing Firebase Cloud Functions across all 3 flavors.

**Last updated**: 2026-04-28

> **Sibling concern**: Hosting deploys are independent of Cloud Functions
> deploys. `firebase deploy --only functions` and `firebase deploy --only hosting:<target>`
> can run in either order; neither blocks the other. Web hosting setup
> (custom domain, CORS, Apple sign-in domain verification, rollback) is
> documented in **[web-hosting-guide.md](./web-hosting-guide.md)**.

---

## 1. Prerequisites

- **Node.js 22+** — [Download](https://nodejs.org/) (check with `node --version`)
- **Firebase CLI** — `npm install -g firebase-tools` (check with `firebase --version`)
- **gcloud CLI** — [Install](https://cloud.google.com/sdk/docs/install) (needed for IAM setup)
- **Firebase login** — `firebase login`
- **Project access** — You must be a project owner/editor on all 3 Firebase projects

---

## 2. First-Time Setup (Per Project)

Each Firebase project needs IAM roles configured before deploying functions. Do this once per project.

### 2.1 Enable Required APIs

```bash
# Replace PROJECT_ID with crewpoint-dev, crewpoint-stg, or crewpoint-prod
gcloud services enable cloudbuild.googleapis.com --project=PROJECT_ID
gcloud services enable cloudfunctions.googleapis.com --project=PROJECT_ID
gcloud services enable artifactregistry.googleapis.com --project=PROJECT_ID
```

### 2.2 Grant IAM Roles

Get your project number (visible in Firebase Console → Project Settings → General):

```bash
# For crewpoint-dev (project number: 711822236757)
gcloud projects add-iam-policy-binding crewpoint-dev \
  --member="serviceAccount:711822236757@cloudbuild.gserviceaccount.com" \
  --role="roles/cloudbuild.builds.builder"

gcloud projects add-iam-policy-binding crewpoint-dev \
  --member="serviceAccount:711822236757-compute@developer.gserviceaccount.com" \
  --role="roles/cloudfunctions.developer"
```

Repeat for staging and production with their respective project numbers:

```bash
# For crewpoint-stg (project number: 715030987637)
gcloud projects add-iam-policy-binding crewpoint-stg \
  --member="serviceAccount:715030987637@cloudbuild.gserviceaccount.com" \
  --role="roles/cloudbuild.builds.builder"

gcloud projects add-iam-policy-binding crewpoint-stg \
  --member="serviceAccount:715030987637-compute@developer.gserviceaccount.com" \
  --role="roles/cloudfunctions.developer"

# For crewpoint-prod (project number: 394956084700)
gcloud projects add-iam-policy-binding crewpoint-prod \
  --member="serviceAccount:394956084700@cloudbuild.gserviceaccount.com" \
  --role="roles/cloudbuild.builds.builder"

gcloud projects add-iam-policy-binding crewpoint-prod \
  --member="serviceAccount:394956084700-compute@developer.gserviceaccount.com" \
  --role="roles/cloudfunctions.developer"
```

### 2.3 Install Dependencies

```bash
cd functions
npm install
cd ..
```

---

## 3. Deploying Functions

### 3.1 Build First

```bash
cd functions && npm run build && cd ..
```

### 3.2 Deploy Per Flavor

Functions must be deployed to each Firebase project separately:

```bash
# Development
firebase deploy --only functions --project crewpoint-dev

# Staging
firebase deploy --only functions --project crewpoint-stg

# Production
firebase deploy --only functions --project crewpoint-prod
```

### 3.3 Verify Deployment

After deploying, verify in the Firebase Console:

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select the project (e.g., crewpoint-dev)
3. Navigate to **Functions** tab
4. Confirm your function appears with status "Active"

Or via CLI:
```bash
firebase functions:list --project crewpoint-dev
```

---

## 4. Function Registry

All deployed Cloud Functions, kept up-to-date as features are added.

| Function | Trigger | Module | Description | Timeout | Added |
|----------|---------|--------|-------------|---------|-------|
| `deleteUserAccount` | HTTPS Callable | `account/` | Server-side account deletion: anonymizes shared data, transfers event ownership (to a Co-owner, or else the longest-standing Admin, or else the longest-standing member, Req 14b), deletes solo events, then participant data (Req 14a, `participants/accountData.ts`): linked records become unnamed entries keeping only age band, status, group and choice answers, with a server-only match key in `participantKeys` while the event has not ended; children they entered in their own group go unless another linked adult remains; group links, link requests and any member documents left go. Clears storage, removes Auth user | 120s | 2026-11-10 |
| `promoteToAdmin` | HTTPS Callable | `events/` | Needs `roles.manage` (Owner or Co-owner): promotes an event member to admin (arrayUnion into `adminIds`), swapping Participant for Admin on their member document and recalculating `permissions`. Requires target to already be a member. | 30s | 2026-04-25 |
| `demoteAdmin` | HTTPS Callable | `events/` | Needs `roles.manage`: removes admin role from an event member (arrayRemove from `adminIds`), and from their member document, leaving Participant if no role is left. Owner cannot be demoted. | 30s | 2026-04-25 |
| `markTaskComplete` | HTTPS Callable | `events/` | `tasks.manage`, the creator or the assignee transitions a task to `done`, stamping `completedAt` + `completedBy` server-side. Reserves a seam for future side effects (notifications, ledger hooks). | 30s | 2026-04-26 |
| `disputeSettlement` | HTTPS Callable | `events/` | Payer or payee rolls back a settlement: deletes the `isPayment` expense, replaces the chat notice with `kind: 'settlement_disputed'`. | 30s | 2026-04-27 |
| `createEvent` | HTTPS Callable | `events/` | The only way to create an event, with the caller as Owner, in `draft`, including the owner's member document. Membership never comes from the client. Safe to retry. | 30s | 2026-11-03 |
| `onEventStatusScheduled` | Scheduled (every 15 minutes) | `events/` | Moves events to `live` at their start time and `ended` after their end time, in the event's time zone. A time that passed before a change by hand does not count. | 60s | 2026-11-04 |
| `changeEventCurrency` | HTTPS Callable | `events/` | `event.manage` changes an event's currency. Refused once the event has any expense or charge, which rules cannot check. Safe to retry. | 30s | 2026-11-04 |
| `setMemberRoles` | HTTPS Callable | `events/` | A `roles.manage` holder replaces a member's roles. Recalculates `permissions` and keeps `adminIds` in step. The Owner role moves only by transfer, and a draft keeps only admin-level members. | 30s | 2026-11-06 |
| `saveEventRole` | HTTPS Callable | `events/` | A `roles.manage` holder saves an event's own version of a preset, or a custom role, in `events/{id}/roles/{roleId}`, and recalculates everyone holding it. The Owner role cannot be edited. | 60s | 2026-11-06 |
| `deleteEventRole` | HTTPS Callable | `events/` | A `roles.manage` holder removes an event's own version of a role. A preset goes back to its built-in permissions and its holders are recalculated. A custom role is deleted only while nobody holds it. | 60s | 2026-11-06 |
| `generateInviteCode` | HTTPS Callable | `events/` | `members.manage` gets the event's one active invite, which carries a role (`roleId`, Participant by default) and an expiry (Req 47, 56). Any other role also needs `roles.manage`, and nobody is invited as Owner. A different role replaces the code; `rotate: true` replaces the code and keeps the role and expiry. `expiresAt` (ms, 5 minutes to 400 days) sets the expiry and keeps the code; without it a new invite lasts 24 hours on Blank and Party, or until the event starts on other templates (`inviteExpiry.ts`). Returns `{code, roleId, expiresAt}`. One transaction. | 30s | 2026-11-10 |
| `previewInvite` | HTTPS Callable | `events/` | A signed-in person opening `/join/:code` sees the event's title and start, the role the invite carries, and whether they can join: `open` with a `reason` (`draft`, `ended`, `archived`), `full`, `alreadyMember`. An unknown or expired code is `not-found`. | 30s | 2026-11-10 |
| `joinEvent` | HTTPS Callable | `events/` | Joins with a code and applies the invite's role, falling back to Participant for older invites or a role since removed. Writes the member document and both arrays, keeps `adminIds` in step, and respects `memberLimit`. | 30s | 2026-11-06 |
| `saveCrew` | HTTPS Callable | `events/` | `members.manage` creates a crew or renames one in `events/{id}/crews/{crewId}`. | 30s | 2026-11-07 |
| `setCrewMembers` | HTTPS Callable | `events/` | `members.manage` sets exactly who is in a crew, adding or removing it from `crewIds` on member documents and keeping roles and permissions. Everyone must be a member. | 60s | 2026-11-07 |
| `deleteCrew` | HTTPS Callable | `events/` | `members.manage` deletes a crew, takes it off everyone in it, then clears `crewId` from its tasks in chunks. Safe to retry. | 120s | 2026-11-07 |
| `offerOwnership` | HTTPS Callable | `events/` | The Owner (`event.transfer`) offers ownership to anyone else in the event, in `events/{id}/ownership/offer`. Nothing changes until it is accepted, and a new offer replaces the old one. | 30s | 2026-11-07 |
| `acceptOwnership` | HTTPS Callable | `events/` | The person offered becomes Owner and the old owner becomes Co-owner, in one transaction, so there is always one Owner. Moves `creatorId` and `organizerId`, and keeps `adminIds` in step. Returning ownership is another offer. | 30s | 2026-11-07 |
| `cancelOwnershipOffer` | HTTPS Callable | `events/` | The Owner withdraws the offer, or the person offered declines it. | 30s | 2026-11-07 |
| `saveExpense` | HTTPS Callable | `events/` | A member other than Observer or Vendor adds an expense as its payer, or the payer or `money.record` edits it. Validates amounts, splits and members, and writes `involvedUids`. The only way to write a non-payment expense. | 30s | 2026-11-03 |
| `recordSettlement` | HTTPS Callable | `events/` | Payer records a payment. Writes the `isPayment` expense and its `settlement` chat notice together, with server-written text. The notice shows the amount only when everyone who can read chat can read every expense (Req 38f), or else says "Settled up". Safe to retry. | 30s | 2026-11-03 |
| `onUrgentMessageCreated` | Firestore-trigger v2 (`onDocumentCreated` on `events/{eid}/messages/{mid}`) | `events/` | Fans out an FCM push when an urgent (high-priority) chat message is created. Sends to members holding `chat.send` (Req 32), skips the sender, chunks tokens at 500 with `sendEachForMulticast`, prunes dead tokens via batched arrayRemove. `retry: false`. | 30s | 2026-04-28 |
| `saveGroup` | HTTPS Callable | `events/` | `participants.edit` creates a group of participants (a household, team or foursome) or renames one, in `events/{id}/groups/{groupId}` with `sortName` and `adultUids` (Req 40). | 30s | 2026-11-08 |
| `setGroupAdults` | HTTPS Callable | `events/` | `participants.edit` sets exactly which members are a group's linked adults. Copies the group into `groupIds` on their member documents and grants `group.editOwn` while they are in any group, so rules check own-group access with one member-document read (Req 26b). | 60s | 2026-11-08 |
| `deleteGroup` | HTTPS Callable | `events/` | `participants.edit` deletes an empty group, its private answers, and unlinks its adults. Refused while participants are in it. Safe to repeat. | 30s | 2026-11-08 |
| `onImportQueued` | Firestore-trigger v2 (`onDocumentWritten` on `events/{eid}/imports/{jobId}`) | `imports/` | Runs a queued roster import (Req 44a): reads `events/{eid}/imports/{jobId}.csv` from Storage, plans it with `plan.ts` (mapping, row checks, re-import matching on external ID or group plus name), and writes a report (`checked`), or applies it in chunks of 400 with `progress`, writing only mapped columns, then deletes the file (`done`). Claims the job in a transaction, so a job runs once. | 540s | 2026-11-08 |
| `cancelImportedGroups` | HTTPS Callable | `imports/` | `participants.import` confirms which groups a re-import listed as missing (Req 45): their people become `cancelled`, leaving counts, and the records are kept. | 60s | 2026-11-08 |
| `linkMyParticipants` | HTTPS Callable | `participants/` | The app calls it once a signed-in person's email is verified (Req 46). Finds participant records carrying that email in their private details, or the match key of an unnamed entry a deleted account left (Req 14a), and decides with `linking.ts`: exactly one adult links, making them a member with the Participant role unless they already are one, and a linked adult of that record's group only; two or more adults, or only children, open `events/{id}/linkRequests/{uid}` for an organizer. Never links on a name, an unverified email, a child, a draft for someone not yet in it, an ended event, or a full one. Safe to repeat. | 60s | 2026-11-10 |
| `resolveLinkRequest` | HTTPS Callable | `participants/` | Someone with `participants.edit` and `participants.readPrivate` settles a link request: links the person to one adult record from it, or to one of its groups when only children matched, or marks it not a match, so it is not asked again. | 30s | 2026-11-10 |
| `cleanupImports` | Scheduled (every 24 hours) | `imports/` | Deletes import files older than 7 days that no finished job removed (Req 44a). | 300s | 2026-11-08 |
| `setExpenseAccess` | HTTPS Callable | `events/` | `event.manage` chooses who reads every expense (Req 38): Everyone (Observers and Vendors only with `includeNonContributors`), Only people involved, or Selected roles and people. Saves `settings.expenseAccess`, logs the change in `settingsLog` with who and when, and recalculates `expenses.readAll` on every member document in transactions of 400. Safe to retry. | 120s | 2026-11-08 |
| `getMyBalance` | HTTPS Callable | `events/` | A member's own balance and the transfers that settle it, from every expense in the event, for someone who cannot read them all (Req 38c). Uses `ledger.ts`, which mirrors the app's `BalanceLedger`. | 30s | 2026-11-08 |
| `onMemberProfileSync` | Firestore-trigger v2 (`onDocumentWritten` on `events/{eid}/members/{uid}`) | `events/` | Someone joining gets `events/{eid}/profiles/{uid}`, a copy of their name, photo and payment handles from `users/{uid}`, which only people in the event can read (Req 37). Someone leaving keeps the name there, so older records still show it, and loses the handles. | 30s | 2026-11-08 |
| `onUserProfileSync` | Firestore-trigger v2 (`onDocumentWritten` on `users/{uid}`) | `events/` | A change to someone's name, photo or payment handles reaches their profile in every event they are in, and none they have left. Other changes write nothing. | 60s | 2026-11-08 |

Every callable and trigger checks the named permission through `requirePermission` / `readPermissions` in `functions/src/events/members.ts` (#66), falling back to the arrays only for an event with no member documents. Membership callables (`createEvent`, `joinEvent`, `removeEventMember`, `promoteToAdmin`, `demoteAdmin`, `setMemberRoles`, `deleteUserAccount`) write both the old arrays and `events/{id}/members/{uid}` until the arrays are removed, so rollback and verification stay accurate. The rollout is in `docs/ops/permissions-cutover.md`. Admin scripts for that cutover are `functions/scripts/migrateToMembers.ts` (dry run unless `--write`) and `functions/scripts/verifyMembers.ts`.

> **Note:** this table is incomplete — 16 functions are exported from
> `functions/src/index.ts` and only the rows above are documented. Treat
> `functions/src/index.ts` as the source of truth until the table is caught up.

### 4.1 Required Firestore Indexes

Collection-group queries do **not** work off the automatic single-field indexes. Every
one currently in the codebase, and the index that serves it:

| Query | Function | Index required |
|---|---|---|
| `collectionGroup('tasks').where('dueDate', '>=' / '<=')` | `onTaskDueScheduled` | `fieldOverrides` → `tasks.dueDate`, `COLLECTION_GROUP` ASC |
| `collectionGroup('private').where('notificationPrefs.dailyDigest', '==', true)` | `onDigestSummary` | `fieldOverrides` → `private.notificationPrefs.dailyDigest`, `COLLECTION_GROUP` ASC |
| `collectionGroup('tasks').where('assigneeId','==').where('status','!=')` | `onDigestSummary` | composite → `tasks` (`assigneeId` ASC, `status` ASC), `COLLECTION_GROUP` |
| `collectionGroup('expenses').where('payerId','!=')` | `onDigestSummary` | `fieldOverrides` → `expenses.payerId`, `COLLECTION_GROUP` ASC |
| `collectionGroup('members').where('uid','==')` | the app's "My events" (#66), `onUserProfileSync` | `fieldOverrides` → `members.uid`, `COLLECTION_GROUP` ASC |
| `collectionGroup('profiles').where('uid','==')` | `deleteUserAccount` (Req 37) | `fieldOverrides` → `profiles.uid`, `COLLECTION_GROUP` ASC |
| `collectionGroup('private').where('email','==')` | `linkMyParticipants` (Req 46) | `fieldOverrides` → `private.email`, `COLLECTION_GROUP` ASC |
| `collectionGroup('participantKeys').where('emailKey','==')` | `linkMyParticipants` (Req 14a) | `fieldOverrides` → `participantKeys.emailKey`, `COLLECTION_GROUP` ASC |
| `collectionGroup('participants').where('uid','==')` | `deleteUserAccount` (Req 14a) | `fieldOverrides` → `participants.uid`, `COLLECTION_GROUP` ASC |
| `collectionGroup('groups').where('adultUids','array-contains')` | `deleteUserAccount` (Req 14a) | `fieldOverrides` → `groups.adultUids`, `COLLECTION_GROUP` CONTAINS |
| `collectionGroup('linkRequests').where('uid','==')` | `deleteUserAccount` (Req 14a) | `fieldOverrides` → `linkRequests.uid`, `COLLECTION_GROUP` ASC |

The last three all sit inside `onDigestSummary`. The `private` query runs first, so while
it was failing the other two had never executed — fixing only the reported index would
have moved the failure rather than removed it.

All four are declared in `firestore.indexes.json`. See Step 4 of Section 5 for the
`fieldOverrides` replacement caveat before editing that file.

---

## 5. Adding a New Function

### Step 1: Create the Function File

Create a new TypeScript file in the appropriate feature directory:

```
functions/src/{feature}/{functionName}.ts
```

Example: `functions/src/notifications/sendPushNotification.ts`

### Step 2: Write the Function

Use Firebase Functions v2 (2nd gen) syntax:

```typescript
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {logger} from "firebase-functions/v2";
// firebase-admin 14 removed the legacy `admin.*` namespace. Import the
// modular entry point you need instead — `getFirestore` from
// "firebase-admin/firestore", `getAuth` from "firebase-admin/auth", etc.

export const myFunction = onCall(
  {timeoutSeconds: 60, memory: "256MiB"},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }
    // Your logic here
    logger.info("Function executed", {uid: request.auth.uid});
    return {success: true};
  }
);
```

### Step 3: Export from index.ts

Add the export to `functions/src/index.ts`:

```typescript
export {myFunction} from "./{feature}/{functionName}";
```

### Step 4: Declare Any Indexes the Query Needs

**If the function runs a `collectionGroup()` query, it needs an index declared by hand
in `firestore.indexes.json` — and the emulator will not tell you.**

The Firestore emulator serves collection-group queries without requiring the index, so
`npm test` passes against queries that cannot run in production. **Emulator-green is not
index-safe.** This is not hypothetical: `onTaskDueScheduled` and `onDigestSummary` both
failed on *every* run in `crewpoint-dev` for over a month before anyone noticed, because
a scheduled trigger that throws has no user-visible surface (see #36).

Automatic single-field indexes are `COLLECTION` scope only. A collection-group query
therefore needs either:

- a **`fieldOverrides` entry** adding `COLLECTION_GROUP` scope, for a single-field
  filter or range; or
- a **composite index** with `"queryScope": "COLLECTION_GROUP"`, for multi-field filters.

⚠️ A `fieldOverrides` entry **replaces** the automatic index configuration for that
field. Always carry the three default `COLLECTION`-scope entries (`ASCENDING`,
`DESCENDING`, `CONTAINS`) alongside the new `COLLECTION_GROUP` entry, or you will
silently delete indexes that existing queries depend on:

```jsonc
{
  "collectionGroup": "tasks",
  "fieldPath": "dueDate",
  "ttl": false,
  "indexes": [
    {"order": "ASCENDING",     "queryScope": "COLLECTION"},
    {"order": "DESCENDING",    "queryScope": "COLLECTION"},
    {"arrayConfig": "CONTAINS","queryScope": "COLLECTION"},
    {"order": "ASCENDING",     "queryScope": "COLLECTION_GROUP"}  // <- the addition
  ]
}
```

Deploy indexes separately from code, and to **every** environment — index state does not
travel with the function:

```bash
firebase deploy --only firestore:indexes --project crewpoint-dev
```

Verify what a project actually has with `firebase firestore:indexes --project <id>`.
Note that `firebase functions:log` cannot be relied on to confirm a recent invocation;
check for the resulting Firestore write instead.

### Step 5: Build and Deploy

```bash
cd functions && npm run build && cd ..
firebase deploy --only functions --project crewpoint-dev
```

### Step 6: Update This Guide

Add a row to the Function Registry table in Section 4.

---

## 6. Updating Existing Functions

1. Edit the function code in `functions/src/{feature}/{name}.ts`
2. Build: `cd functions && npm run build && cd ..`
3. Deploy: `firebase deploy --only functions --project crewpoint-dev`

**Zero downtime**: 2nd gen functions deploy as new revisions. Traffic shifts automatically after the new version is healthy.

---

## 7. Rollback

### Via Firebase Console

1. Go to **Cloud Functions** in Google Cloud Console (not Firebase Console)
2. Click the function name
3. Go to **Revisions** tab
4. Route traffic to a previous revision

### Via Code

Revert the code change in git and redeploy:

```bash
git revert HEAD
cd functions && npm run build && cd ..
firebase deploy --only functions --project crewpoint-dev
```

---

## 8. Local Testing with Emulators

### Start the Emulator Suite

```bash
firebase emulators:start --project crewpoint-dev
```

This starts emulators for Functions, Firestore, Auth, and Storage.

### Point Flutter App at Emulators

Add this to your Flutter app's `main.dart` (development only):

```dart
// Only for local testing — remove before production
FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
```

### Test a Callable Function

```bash
firebase functions:shell --project crewpoint-dev
> deleteUserAccount({})
```

---

## 9. Monitoring

### View Logs

```bash
# Recent logs
firebase functions:log --project crewpoint-dev

# Follow logs in real-time
firebase functions:log --project crewpoint-dev --follow

# Filter by function
firebase functions:log --project crewpoint-dev --only deleteUserAccount
```

### Cloud Console Dashboard

For advanced monitoring (latency, error rates, invocation counts):

1. Go to [Cloud Console](https://console.cloud.google.com)
2. Select the project
3. Navigate to **Cloud Functions** → click function name → **Metrics** tab

---

## 10. Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| `PERMISSION_DENIED` during deploy | Missing IAM roles on build service account | Run the `gcloud projects add-iam-policy-binding` commands from Section 2.2 |
| `Runtime Node.js X was decommissioned` | Outdated Node version in `package.json` | Update `"engines": { "node": "22" }` in `functions/package.json` |
| Function timeout | Operation exceeds configured timeout | Increase `timeoutSeconds` in function config (max 540s for 2nd gen) |
| `RESOURCE_EXHAUSTED` / batch limit | More than 500 Firestore operations in one batch | Use `commitInChunks()` from `utils/batch.ts` — processes in sequential 500-doc batches |
| `MODULE_NOT_FOUND` after deploy | Build not run before deploy | Run `cd functions && npm run build` before deploying |
| Memory exceeded | Function processing too much data | Increase `memory` in function config (e.g., `"512MiB"`, `"1GiB"`) |
| Emulator won't start | Port conflict | Kill processes on ports 8080, 9099, 5001, 9199 or change ports in `firebase.json` |
| `UNAUTHENTICATED` error from client | User not signed in when calling function | Ensure `FirebaseAuth.instance.currentUser` is not null before calling |

---

## 11. Project Structure

```
functions/
  src/
    index.ts              ← Export hub (imports from feature modules)
    account/
      deleteUserAccount.ts ← Account deletion logic
    utils/
      batch.ts            ← Shared chunked batch helper
    notifications/        ← Future: push notifications
    events/               ← Future: event lifecycle triggers
  package.json
  tsconfig.json
  lib/                    ← Compiled JS output (gitignored)
  node_modules/           ← Dependencies (gitignored)
```

**Convention**: One function per file, grouped by feature directory. `index.ts` only imports and re-exports.
