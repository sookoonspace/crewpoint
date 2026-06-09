# Firebase full-stack deploy guide (CrewPoint)

End-to-end manual deploy of **Firestore rules + indexes, Storage rules,
all Cloud Functions, and the Flutter web app** to one of the three
CrewPoint Firebase projects.

Use this when you want to be sure every part of the backend matches
`main` — typically after merging a phase that touched multiple layers
(rules, CFs, indexes, web). For routine web-only re-deploys, use
[`firebase-hosting-dev-deploy.md`](./firebase-hosting-dev-deploy.md)
or [`web-hosting-guide.md`](./web-hosting-guide.md) instead.

> **First-time prod deploys are higher-risk.** Run dev end-to-end,
> smoke-test in a browser, then stg, smoke again, and only then prod.
> The same sequence below works for all three; only `--project` and
> the SW swap change.

## Environments at a glance

| Flavor | Firebase project   | Hosting site ID  | Public URL                              | `--project` flag |
| ------ | ------------------ | ---------------- | --------------------------------------- | ---------------- |
| dev    | `crewpoint-dev`    | `crewpoint-dev`  | `https://crewpoint-dev.web.app`         | `--project dev`  |
| stg    | `crewpoint-stg`    | `crewpoint-stg`  | `https://crewpoint-stg.web.app`         | `--project stg`  |
| prod   | `crewpoint-prod`   | `crewpoint-prod` | `https://crewpoint.sookoon.space` (custom) | `--project prod` |

Aliases come from `.firebaserc` (`dev` / `stg` / `prod` → the three
project IDs).

## Stage 0 — Prerequisites

- **Firebase CLI** ≥ 13.x, logged in to an account with **Editor** or
  **Firebase Admin** on each project you intend to deploy to:
  ```bash
  firebase --version
  firebase login:list
  firebase projects:list   # should show all three crewpoint-* projects
  ```
- **Flutter** on the version in `pubspec.yaml`'s `environment.flutter`
  range. Run `flutter doctor` and `flutter pub get` once after pulling.
- **Node** ≥ 22 (matches the CF runtime in `functions/package.json`),
  and `npm install` inside `functions/` has been run.
- You're on the **commit you want deployed** — typically tip of `main`:
  ```bash
  git checkout main
  git pull --ff-only
  git log -1 --oneline
  ```
- (Web-only) For web push to actually deliver, set the recipient
  project's VAPID public key as a dart-define on the build:
  ```bash
  --dart-define=FIREBASE_VAPID_KEY=<vapid>
  ```
  Found in **Firebase Console → Project settings → Cloud Messaging →
  Web configuration**. Without it the web app still loads, but
  `getToken()` returns null and no web push tokens land in Firestore.

## Stage 1 — Firestore rules + indexes + Storage rules

Lowest blast radius. Run this first so any rule changes propagate
before the CFs that depend on them.

```bash
firebase deploy \
  --only firestore:rules,firestore:indexes,storage \
  --project <dev|stg|prod>
```

- Rules releases are atomic and effectively instant.
- New composite indexes start building in the background; queries that
  need them fail until the index reports **Enabled** in the console
  (Firestore → Indexes tab). For small datasets this is seconds; for
  large ones it can be minutes.
- If a CF query references a composite index that isn't declared in
  `firestore.indexes.json`, the first invocation returns a
  `FAILED_PRECONDITION` error with a **click-to-create URL** in the
  Cloud Logging entry. Follow that link, accept the proposed shape,
  and then add the same shape to `firestore.indexes.json` so the next
  deploy is self-sufficient.

## Stage 2 — Cloud Functions

```bash
firebase deploy --only functions --project <dev|stg|prod>
```

- The `predeploy` hook in `firebase.json` runs
  `npm --prefix functions run build` (TypeScript compile) — no manual
  build step needed.
- First deploys auto-enable any missing GCP APIs the CFs require:
  `cloudfunctions`, `cloudbuild`, `artifactregistry`, `cloudscheduler`,
  `run`, `eventarc`, `pubsub`. You'll see `ensuring required API …`
  lines for each. This is one-time per project.
- The CLI may warn that `firebase-functions` is on an outdated version
  — non-fatal. Track an upgrade as a separate change.

### Scheduled CFs (`onSchedule`)

The first deploy of a new scheduled CF (e.g. `onTaskDueScheduled`,
`onDigestSummary`) triggers Pub/Sub + Cloud Scheduler API enablement.
Watch for a successful `… Successful create operation.` line for each
scheduled function. After deploy, verify the schedule lands in
**Cloud Scheduler → Jobs** in the GCP console.

### Functions that depend on Firestore indexes

If you added a new CF that does a `collectionGroup` query, make sure
the corresponding composite index is either declared in
`firestore.indexes.json` (deployed in Stage 1) **or** you accept the
first-invocation failure and click the create-URL in Cloud Logging.
The current code path that intentionally defers this is the digest
CF's `(assigneeId asc, status asc)` composite — see Phase 6.1 in
`ai_specs/push-notifications-plan.md`.

## Stage 3 — Flutter web build + hosting

This stage has one known quirk: the Firebase CLI's `predeploy` hook
**mangles the `--dart-define=FLAVOR=…` flag** (the `=` is interpreted
as a shell special char) and the predeploy build silently no-ops.
You'll see a warning like:

> ⚠ Warning: Your command contains '=', it may result in the command
> not running. Please consider removing it.

…followed by `Error: Directory 'build/web' for Hosting does not exist.`
the first time around.

**Workaround**: build manually, then run the hosting deploy. The
predeploy `=` warning re-appears but is harmless because `build/web`
already exists and the no-op predeploy doesn't overwrite it.

### 3a. Build the right flavor

```bash
flutter build web --release --dart-define=FLAVOR=<dev|stg|prod>
```

This compiles `lib/main.dart` to `build/web/` and copies everything
under `web/` (including `firebase-messaging-sw.js`) into the output.

The wasm dry-run warning (`Unexpected wasm dry run failure (252)`)
and the icon-font tree-shaking messages are normal — no action
required.

### 3b. Swap the FCM service worker (stg / prod only — skip for dev)

`web/firebase-messaging-sw.js` is the source of truth and ships with
**dev project credentials baked in** (it has to — the service worker
loads outside the Flutter app and can't reach `firebase_options.dart`).

For stg or prod, overwrite the **build artifact** (not the source) so
the deploy ships the right project credentials. Source stays on dev
defaults to keep day-to-day dev re-deploys friction-free.

For **stg**, write `build/web/firebase-messaging-sw.js` containing the
stg `web` block from `lib/firebase_options_stg.dart`:

```js
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCZjDMnW_prMhOtj6mytmcaUFOsinE4Rng',
  appId: '1:715030987637:web:588e1db0f6255fc77a093c',
  messagingSenderId: '715030987637',
  projectId: 'crewpoint-stg',
  authDomain: 'crewpoint-stg.firebaseapp.com',
  storageBucket: 'crewpoint-stg.firebasestorage.app',
});

firebase.messaging();
```

For **prod**, swap the `firebase.initializeApp({...})` block to the
prod values from `lib/firebase_options_prod.dart` instead:

```js
firebase.initializeApp({
  apiKey: 'AIzaSyDixC7AUjyQLBvBTddRwIBi1y7XU79LSJw',
  appId: '1:394956084700:web:9a26cd6a360e6cec52ab19',
  messagingSenderId: '394956084700',
  projectId: 'crewpoint-prod',
  authDomain: 'crewpoint-prod.firebaseapp.com',
  storageBucket: 'crewpoint-prod.firebasestorage.app',
});
```

**Do not commit the swapped file.** It's a build artifact; re-running
the manual build regenerates it from the source (dev) and the swap
needs to be redone on every fresh stg / prod hosting deploy.

### 3c. Push to hosting

```bash
firebase deploy --only hosting:<crewpoint-dev|crewpoint-stg|crewpoint-prod> --project <dev|stg|prod>
```

The target alias matches the site ID. The predeploy `=` warning will
appear; ignore it (per 3a's workaround note).

Final lines you want to see:

```
✔  hosting[crewpoint-<flavor>]: release complete
✔  Deploy complete!
Hosting URL: https://crewpoint-<flavor>.web.app
```

### 3d. Verify the service worker

```bash
curl -s https://<host>/firebase-messaging-sw.js | grep -E "projectId|appId"
```

Confirm the deployed file points at the right project. A mismatch
means web push token registration will silently fail.

## End-to-end smoke checklist (per environment)

Run these in a real browser (Chrome is the reference) on the deployed
URL after every full deploy:

- [ ] App loads with no console errors.
- [ ] Sign-in works (Google or Apple). New users land on onboarding;
      returning users land on the dashboard.
- [ ] Bottom nav (≤ 720 px width) and `NavigationRail` (≥ 720 px) both
      render and navigate.
- [ ] **Notifications**: open Profile → Notifications. Toggle master
      OFF / ON. The OS permission prompt fires on first ON.
- [ ] (Web push, optional) Trigger a categorized push by sending an
      urgent chat message from another account; the foreground banner
      should render, and a background message (tab hidden) should fire
      a system notification. Requires the VAPID key to have been baked
      into the build and the right SW to have been deployed.
- [ ] Sign out cleanly clears the FCM token (verify the
      `users/{uid}/private/profile.fcmTokens` array shrinks by one
      entry in the Firestore console).

If any of the above fails, **do not promote to the next environment**.

## Single-shot deploy (when you trust the source tree)

If you're confident the working tree matches `main` and just want
everything shipped, you can chain the steps:

```bash
# Replace <env> with dev | stg | prod (3×) and the hosting target.
ENV=dev
firebase deploy \
  --only firestore:rules,firestore:indexes,storage,functions \
  --project "$ENV"

flutter build web --release --dart-define=FLAVOR="$ENV"
# (For stg / prod: swap build/web/firebase-messaging-sw.js here.)
firebase deploy \
  --only "hosting:crewpoint-$ENV" \
  --project "$ENV"
```

Avoid a single mega-`firebase deploy --only` for the first prod push:
the per-stage cadence gives you a chance to abort if (e.g.) functions
fail without already having shipped rules that depend on them.

## Promotion order

Always: **dev → smoke → stg → smoke → prod**.

Specifically, the dev gate that unlocks stg lives in
[`dev-first-rollout-checklist.md`](./dev-first-rollout-checklist.md);
stg → prod has no separate document yet, but the smoke checklist above
is the operational gate.

## Common failure modes

| Symptom | Cause | Fix |
| --- | --- | --- |
| `Error: Directory 'build/web' for Hosting does not exist.` after the predeploy log shows the `=` warning | The CLI predeploy mangled `--dart-define=FLAVOR=...` and didn't actually build. | Run `flutter build web --release --dart-define=FLAVOR=<env>` manually, then re-run the hosting deploy. |
| Scheduled CF deploy fails with `cloudscheduler.googleapis.com is not enabled` | First scheduled CF in this project. | Re-run the functions deploy; the CLI auto-enables the API on the second pass. Or enable manually in GCP console. |
| First invocation of a new `collectionGroup` query returns `FAILED_PRECONDITION` | Missing composite index. | Follow the click-to-create URL in Cloud Logging; mirror the shape into `firestore.indexes.json` so the next deploy is self-sufficient. |
| `permission-denied` on a previously-working read | Rules change that tightened a path. | Verify `firestore.rules` matches `main`; redeploy if local was ahead/behind. |
| Deployed SW reports a different `projectId` than expected | Forgot the Stage 3b swap. | Redo the swap on `build/web/firebase-messaging-sw.js` and re-run the hosting deploy (just the upload — no need to rebuild). |
| Functions deploy stalls partway with `Quota exceeded` | Project hit GCF concurrent-build quota | Wait 60s and re-deploy; the partially-deployed batch is idempotent. |
| Web build succeeds locally but the deployed page is white | Service worker cache. | Hard-refresh (`Cmd+Shift+R`). If the app uses `firebase-messaging-sw.js`, unregister the SW under DevTools → Application → Service Workers before reloading. |

## Manual GCP prereqs (one-time per project)

Some Phase deliverables require operations outside the CLI's reach:

- **APNs auth key** — uploaded in Firebase Console → Project settings
  → Cloud Messaging → Apple app configuration. See
  [`apns-auth-key-setup.md`](./apns-auth-key-setup.md). Without this,
  iOS pushes silently fail.
- ~~iOS critical-alert entitlement~~ — **withdrawn for V1/V2**.
  `chat_urgent` ships with `interruption-level: 'time-sensitive'`, which
  needs no entitlement. Re-introduction is a small additive PR (see the
  Phase 4 withdrawal note in `ai_specs/push-notifications-plan.md`).
- **VAPID public key** — needed at web build time
  (`--dart-define=FIREBASE_VAPID_KEY=...`). Source: Firebase Console →
  Project settings → Cloud Messaging → Web configuration → Web Push
  certificates.
- **GCP budget alerts** — see [`gcp_budget_settings.md`](./gcp_budget_settings.md).
- **(prod only) Custom domain** — `crewpoint.sookoon.space` DNS
  records. See [`web-hosting-guide.md`](./web-hosting-guide.md).

## Cross-references

- `firebase.json` — `firestore`, `storage`, `functions`, `hosting`
  blocks the CLI reads.
- `.firebaserc` — `dev` / `stg` / `prod` aliases and hosting target
  bindings.
- [`firebase-hosting-dev-deploy.md`](./firebase-hosting-dev-deploy.md)
  — narrow guide for the routine web re-deploy loop on dev.
- [`web-hosting-guide.md`](./web-hosting-guide.md) — custom-domain and
  per-flavor hosting topology.
- [`cloud-functions-guide.md`](./cloud-functions-guide.md) — CF
  lifecycle, regions, and IAM.
- [`apns-auth-key-setup.md`](./apns-auth-key-setup.md) — iOS push
  prereq.
- [`dev-first-rollout-checklist.md`](./dev-first-rollout-checklist.md)
  — operational dev → stg → prod gates.
- `ai_specs/push-notifications-plan.md` — Phase notes on which deploys
  were exercised in which session (especially Phase 6.2 web push).
