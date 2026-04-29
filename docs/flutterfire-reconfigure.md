# Re-running `flutterfire configure` without breaking iOS/Android

This guide covers when (and how) to re-run `flutterfire configure` against the
three CrewPoint Firebase projects (`crewpoint-dev`, `crewpoint-stg`,
`crewpoint-prod`) without losing platform config that's already in place.

## TL;DR

You probably don't need to re-run. The `firebase_options_*.dart` files
already contain working web blocks for all three flavors. The only thing
out of sync is `firebase.json`'s `flutter.platforms.dart` map, which is
metadata used by future re-runs. **Path A below (hand-edit metadata)** is
safer and faster than re-running.

## What's actually configured today

The Dart options files already have full platform coverage:

| File                              | `web` block | `android` block | `ios` block |
| --------------------------------- | ----------- | --------------- | ----------- |
| `lib/firebase_options.dart`       | ✓           | ✓               | ✓           |
| `lib/firebase_options_dev.dart`   | ✓           | ✓               | ✓           |
| `lib/firebase_options_stg.dart`   | ✓           |                 | ✓           |
| `lib/firebase_options_prod.dart`  | ✓           |                 | ✓           |

But `firebase.json`'s registration map under-reports:

| File                              | Map says registered  |
| --------------------------------- | -------------------- |
| `lib/firebase_options.dart`       | android, ios, web    |
| `lib/firebase_options_dev.dart`   | **web only**         |
| `lib/firebase_options_stg.dart`   | **ios only**         |
| `lib/firebase_options_prod.dart`  | **ios only**         |

The danger: if you re-run `flutterfire configure` and pick "only web"
because that's what looks missing, the CLI will rewrite the options file
with **only web**, deleting the existing android/ios blocks. That's how
mobile builds break.

## Path A — Hand-edit `firebase.json` (recommended)

Pure metadata fix. No code touched. Takes ~5 minutes.

1. Open `firebase.json`.
2. Open the four `firebase_options_*.dart` files in another tab — you'll
   copy `appId` strings from each.
3. Update each `flutter.platforms.dart[<file>].configurations` block to
   list every platform the file actually contains:

   ```json
   "lib/firebase_options_dev.dart": {
     "projectId": "crewpoint-dev",
     "configurations": {
       "web": "<from firebase_options_dev.dart web.appId>",
       "android": "<from firebase_options_dev.dart android.appId>",
       "ios": "<from firebase_options_dev.dart ios.appId>"
     }
   },
   "lib/firebase_options_stg.dart": {
     "projectId": "crewpoint-stg",
     "configurations": {
       "web": "<from firebase_options_stg.dart web.appId>",
       "ios": "<from firebase_options_stg.dart ios.appId>"
     }
   },
   "lib/firebase_options_prod.dart": {
     "projectId": "crewpoint-prod",
     "configurations": {
       "web": "<from firebase_options_prod.dart web.appId>",
       "ios": "<from firebase_options_prod.dart ios.appId>"
     }
   }
   ```

4. Commit (`docs(infra): align firebase.json platform map with actual options files`).

Future `flutterfire configure` runs will now know exactly which platforms
each flavor owns, so accepting the defaults won't drop anything.

## Path B — Full re-run with explicit platform flags

Only do this if you genuinely want to refresh keys / measurement IDs from
the Firebase console (not for routine maintenance).

**Rule:** select every platform the file currently has, even if you don't
think anything changed for it. Anything you deselect is removed from the
generated file.

```bash
# DEV — has android + ios + web today
flutterfire configure \
  --project=crewpoint-dev \
  --out=lib/firebase_options_dev.dart \
  --platforms=android,ios,web \
  --yes

# STG — has ios + web today (no android)
flutterfire configure \
  --project=crewpoint-stg \
  --out=lib/firebase_options_stg.dart \
  --platforms=ios,web \
  --yes

# PROD — has ios + web today (no android)
flutterfire configure \
  --project=crewpoint-prod \
  --out=lib/firebase_options_prod.dart \
  --platforms=ios,web \
  --yes
```

Flag rationale:

- `--platforms=` bypasses the interactive picker so you can't tick the
  wrong boxes by mistake.
- `--out=` pins the output path explicitly; protects against accidentally
  overwriting `lib/firebase_options.dart` (the default).
- `--yes` accepts existing Firebase app registrations rather than creating
  duplicates.

**After each command, diff the file:**

```bash
git diff lib/firebase_options_<flavor>.dart
```

You should see only `apiKey` / `measurementId` / similar token changes. If
a whole platform block (`static const FirebaseOptions android = …`)
disappears from the diff, **don't commit** — re-run with the missing
platform added to `--platforms=`.

### Native config side-effects

`flutterfire configure` may also try to update:

- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

In this repo those files come from `firebase.json`'s
`flutter.platforms.android.default` / `.ios.default` (both pinned to
`crewpoint-prod`). They are **independent of the per-flavor Dart options**
and should not change when you reconfigure dev or stg. If `git diff`
shows changes to either native config file after a stg/dev reconfigure,
revert them.

## When you'd actually want to re-run

- Adding a brand-new platform to a flavor (e.g., bringing Android into
  stg).
- Rotating an API key in the Firebase console.
- After a `flutterfire`/`firebase_core` major upgrade that bumps the
  options file format.

For routine work — including the web-hosting setup in
`docs/web-hosting-guide.md` — Path A is sufficient.

## Cross-references

- `firebase.json` — registration map, the file Path A edits.
- `lib/firebase_options*.dart` — generated; never hand-edit unless you
  also update `firebase.json`'s map to match.
- `docs/cloud-functions-guide.md` — Cloud Functions deploy lifecycle.
- `docs/web-hosting-guide.md` — (forthcoming, Phase 4) Firebase Hosting
  custom-domain setup for `crewpoint.sookoon.space`.
