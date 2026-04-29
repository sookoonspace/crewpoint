# Deploying CrewPoint web to dev Firebase Hosting

End-to-end walkthrough for shipping the Flutter web build to
`crewpoint-dev` Firebase Hosting and verifying the responsive shell in a
browser. Run-through time: ~10 minutes the first time, ~2 minutes for
subsequent deploys.

## Prerequisites

- Firebase CLI installed and logged in. Verify:
  ```bash
  firebase --version          # >= 13.x
  firebase login:list         # should show your account
  ```
  If not logged in: `firebase login` (opens a browser).

- You have at least Editor / Firebase Admin role on the `crewpoint-dev`
  Firebase project. Check the Firebase Console → Project settings →
  Users and permissions.

- Working tree builds locally:
  ```bash
  flutter build web --release --dart-define=FLAVOR=dev
  ```
  Should produce `build/web/index.html` plus hashed JS/Wasm assets. Fix
  any analyzer / build errors before continuing.

- `.firebaserc` and `firebase.json` already wired up (Phase 1 commit
  `feat(web): wire dev Firebase Hosting + responsive-shell journey test`).

## Step 1 — Confirm the Hosting site exists

Each Firebase project comes with a default Hosting site named after the
project ID. For `crewpoint-dev` the default site is **`crewpoint-dev`**,
serving at `https://crewpoint-dev.web.app` (and
`https://crewpoint-dev.firebaseapp.com`).

Check whether it's provisioned:

```bash
firebase hosting:sites:list --project=crewpoint-dev
```

Expected output includes a row like:

```
┌─────────────────┬─────────────────────────────────────────┬───────────┐
│ Site ID         │ Default URL                             │ App ID    │
├─────────────────┼─────────────────────────────────────────┼───────────┤
│ crewpoint-dev   │ https://crewpoint-dev.web.app           │ ―         │
└─────────────────┴─────────────────────────────────────────┴───────────┘
```

If the table is empty, the project has never used Hosting. Create the
default site:

```bash
firebase hosting:sites:create crewpoint-dev --project=crewpoint-dev
```

(The site ID can match the project ID; the CLI accepts that.)

## Step 2 — Apply the target

`.firebaserc` already declares a logical target named `crewpoint-dev`
that points at site `crewpoint-dev`. Lock it in via the CLI:

```bash
firebase target:apply hosting crewpoint-dev crewpoint-dev \
  --project=crewpoint-dev
```

Argument order: `firebase target:apply hosting <target-name> <site-id>`.

This command writes the binding into `.firebaserc` if it's not already
there. Since we've pre-populated `.firebaserc`, the CLI should report
"already applied" — that's expected and harmless.

Verify:

```bash
firebase target --project=crewpoint-dev
```

Expected output:

```
[ Project: crewpoint-dev ]
hosting:
  crewpoint-dev (crewpoint-dev)
```

## Step 3 — Deploy

Run a single command:

```bash
firebase deploy --only hosting:crewpoint-dev --project=crewpoint-dev
```

The `predeploy` hook in `firebase.json` automatically runs
`flutter build web --release --dart-define=FLAVOR=dev` first, so you do
**not** need a separate build step.

Expected timeline:

1. `predeploy` — Flutter web build (~30–90s depending on machine).
2. Upload — typically 50–200 files; hashed bundles, so subsequent
   deploys re-upload only what changed.
3. Release — Hosting promotes the upload to live within seconds.
4. Final line: **"Deploy complete!"** with a URL like
   `https://crewpoint-dev.web.app`.

If the predeploy fails, the deploy aborts before any upload happens.
Diagnose with `flutter build web --release --dart-define=FLAVOR=dev`
locally to reproduce.

## Step 4 — Verify in Chrome

1. Open the deployed URL (`https://crewpoint-dev.web.app`) in **Chrome**
   (Safari and Firefox should also work; Chrome is the reference).
2. Open DevTools (`Cmd+Option+I`) → Console tab. Watch for errors during
   load.
3. Confirm the auth gate or dashboard renders. Sign-in flows depend on
   Firebase Auth being configured for this project's web app — should be
   in place since `firebase_options_dev.dart` already has a web block.
4. **Resize the browser window** so the inner width is ≥ 720 px. The
   bottom navigation bar should disappear and a left-side
   `NavigationRail` should appear with five destinations
   (Dashboard / Tasks / Chat / Budget / Profile) plus a Sign out button
   at the bottom.
5. Drag the window narrower (< 720 px). The rail should swap back to a
   `NavigationBar` at the bottom. Branch state and scroll position
   should survive the transition.

If the rail doesn't render at ≥ 720 px, hard-refresh
(`Cmd+Shift+R`) to bust any service-worker cache, then retry.

## Step 5 — Subsequent deploys

For routine redeploys, just run:

```bash
firebase deploy --only hosting:crewpoint-dev --project=crewpoint-dev
```

The predeploy auto-rebuilds, so no manual build step is needed.

## Troubleshooting

- **"Error: HTTP Error: 404, Not Found"** during `target:apply` — the
  site doesn't exist yet. Run Step 1's `hosting:sites:create` command.
- **"Error: Authentication Error"** — `firebase login` (re-auth).
- **Predeploy fails with "No Firebase web app"** — the project has the
  web app config in `firebase_options_dev.dart` but the Firebase Console
  may have a stale registration. Open Firebase Console →
  `crewpoint-dev` → Project settings → Your apps; verify a web app
  exists with appId `1:711822236757:web:7fc7f232d8f717188788dc`.
- **Page loads white / 404 on routes** — check that
  `firebase.json`'s `hosting[*].rewrites` rule routes `/**` →
  `/index.html`. Already in place; if you edited the file, this is the
  most common regression.
- **Stale build served** — the cache headers mark `index.html` as
  `no-cache, no-store, must-revalidate`, so a hard refresh
  (`Cmd+Shift+R`) is sufficient. Service worker also picks up the new
  build on next load.
- **CORS errors on receipts / avatars** — expected at this stage; CORS
  allow-list isn't applied until Phase 4.

## What this does **not** cover

- Custom domain (`crewpoint.sookoon.space`) — Phase 4. Use the default
  Firebase URL for Phase 1 verification.
- Cloud Storage CORS allow-list — Phase 4.
- Apple sign-in domain configuration — Phase 6.
- Production / staging deploys — Phase 4 wires those flavors.

## Cross-references

- `firebase.json` — `hosting[]` block defining target, predeploy,
  rewrites, headers.
- `.firebaserc` — project aliases and target mapping.
- `docs/cloud-functions-guide.md` — sibling deploy lifecycle for Cloud
  Functions.
- `docs/flutterfire-reconfigure.md` — when (and how) to refresh
  `firebase_options_*.dart` without breaking iOS/Android.
- `ai_specs/web-admin-reporting-plan.md` — Phase 1 manual smoke task,
  Phase 4 production hosting.
