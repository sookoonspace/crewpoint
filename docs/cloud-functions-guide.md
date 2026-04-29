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
| `deleteUserAccount` | HTTPS Callable | `account/` | Server-side account deletion: anonymizes shared data, transfers event ownership, deletes solo events, clears storage, removes Auth user | 120s | 2026-04-21 |
| `promoteToAdmin` | HTTPS Callable | `events/` | Owner-only: promotes an event member to admin (arrayUnion into `adminIds`). Requires target to already be a member. | 30s | 2026-04-25 |
| `demoteAdmin` | HTTPS Callable | `events/` | Owner-only: removes admin role from an event member (arrayRemove from `adminIds`). Owner cannot be demoted. | 30s | 2026-04-25 |
| `markTaskComplete` | HTTPS Callable | `events/` | Owner / admin / assignee transitions a task to `done`, stamping `completedAt` + `completedBy` server-side. Reserves a seam for future side effects (notifications, ledger hooks). | 30s | 2026-04-26 |
| `disputeSettlement` | HTTPS Callable | `events/` | Payer or payee rolls back a settlement: deletes the `isPayment` expense, replaces the chat notice with `kind: 'settlement_disputed'`. | 30s | 2026-04-27 |
| `onUrgentMessageCreated` | Firestore-trigger v2 (`onDocumentCreated` on `events/{eid}/messages/{mid}`) | `events/` | Fans out an FCM push when an urgent (high-priority) chat message is created. Loads recipients from event memberIds, skips the sender, chunks tokens at 500 with `sendEachForMulticast`, prunes dead tokens via batched arrayRemove. `retry: false`. | 30s | 2026-04-28 |

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
import * as admin from "firebase-admin";

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

### Step 4: Build and Deploy

```bash
cd functions && npm run build && cd ..
firebase deploy --only functions --project crewpoint-dev
```

### Step 5: Update This Guide

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
