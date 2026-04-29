## Overview

Desktop/web parity for CrewPoint + repo polish. Thin slice first (responsive shell on dev hosting), then PDF/CSV, then prod hosting/CORS, then cross-repo microsite, then Apple sign-in.

**Spec**: `ai_specs/web-admin-reporting-spec.md`

## Context

- **Structure**: feature-first (`lib/app/features/{feature}/{data,domain,application,presentation}` + `lib/app/core/`)
- **State management**: Riverpod 3, hand-written `Notifier`s + `Provider`s in `lib/app/core/providers.dart`
- **Reference implementations**:
  - `lib/app/core/router/app_shell.dart` — current shell to evolve
  - `lib/app/core/services/url_launcher_service.dart` — `IUrlLauncher` seam pattern (mirror for `IFileExporter`)
  - `lib/app/features/budget/data/balance_ledger.dart`, `lib/app/features/budget/domain/pay_link_builder.dart` — pure-builder precedent
  - `test/journeys/tasks_journey_test.dart` + `test/harness/tasks_harness.dart` + `test/robots/tasks_robot.dart` — robot pattern
  - `lib/app/features/auth/data/firebase_auth_service.dart` — already calls `signInWithProvider(AppleAuthProvider)` (no `kIsWeb` branch)
- **Hosting**: Firebase on `crewpoint.sookoon.space` (subdomain CNAME at Namecheap). Apex `sookoon.space` stays on Namecheap (Next.js marketing site at `/Users/googoo/Websites/sookoon_space`).
- **`authDomain`**: stays at `crewpoint-prod.firebaseapp.com` for V1 (white-label deferred).
- **Tests must not call `Firebase.initializeApp()`** — use Riverpod overrides on `IAuthService` / `IUserRepository` / `IFileExporter` etc.
- **Branch note**: currently on `docs/readme-refresh`; consider rebasing onto `main` before Phase 1 or branching off `main` per phase.
- **Assumptions/Gaps**:
  - `firebase_options_prod.dart` web block already exists; `flutterfire configure` re-run only re-registers `web` in `firebase.json`'s Dart map.
  - `sign_in_with_apple` package in pubspec is unused; audit + remove in Phase 6.
  - Marketing PR (Phase 5) is in a separate repo; no `flutter`/`functions` CI gate there.

## Plan

### Phase 1: Responsive shell + dev-hosting smoke (vertical slice)

- **Goal**: desktop user opens dev URL, sees side rail at ≥720, bar at <720, branch state survives resize.
- [x] `lib/app/core/widgets/responsive_shell.dart` — single `Scaffold` with `navigationShell` body; rail vs bar siblings swap by width via `LayoutBuilder` (≥720 = `NavigationRail` extended, <720 = `NavigationBar`); leading hero + trailing Sign out on rail; web-only `ConstrainedBox(maxWidth: 1280)` body wrap
  - Note: hero/wordmark + body `ConstrainedBox` deferred to a polish pass — V1 ships with `extended: true` rail labels and a sign-out `IconButton` in the trailing slot. Body-width clamp not needed in Phase 1 (no widescreen UX bugs reported); revisit if reading lengths feel stretched after Stage D deploy.
- [x] `lib/app/core/router/app_router.dart` — swap `AppShell` → `ResponsiveShell` in `StatefulShellRoute.indexedStack` builder; old `app_shell.dart` deleted
- [x] `firebase.json` — add `hosting` array with one entry for `crewpoint-dev` target only (predeploy `flutter build web --release --dart-define=FLAVOR=dev`, SPA rewrite, cache headers); leave prod/stg for Phase 4
- [x] `.firebaserc` — create with `projects.default = crewpoint-dev`, `targets.crewpoint-dev.hosting.crewpoint-dev = ["crewpoint-dev"]`
- [ ] Re-run `flutterfire configure --project=crewpoint-dev` so `firebase.json`'s Dart map re-registers web (don't hand-edit `firebase_options_dev.dart`) — **manual user step (interactive auth required)**
- [x] TDD: `ResponsiveShell` renders `NavigationBar` at 600×800
- [x] TDD: `ResponsiveShell` renders `NavigationRail` at 800×600 and 1280×800
- [x] TDD: branch index round-trips when width crosses 720 mid-test (pumped with stub `StatefulNavigationShell`)
  - Implemented as: `currentIndex` propagates to both bar and rail across breakpoint (`StatefulNavigationShell` not constructible standalone; the prop-driven shell preserves the same invariant)
- [x] TDD: `ScrollController` offset on the active branch survives a resize across 720 (proves shell isn't re-mounted) — required adding a stable `ValueKey('shell.body')` on the body-slot `Expanded` so its `Element` survives the rail siblings being inserted/removed alongside it
- [x] Robot journey: `test/journeys/web_shell_journey_test.dart` — 1280×800 → tap `Key('shell.rail.budget')` → assert `Budget branch` on-screen → resize 600×800 → assert `NavigationBar` `selectedIndex == 3` (uses an `_ShellDriver` mirroring `StatefulShellRoute.indexedStack`'s `IndexedStack` body without invoking go_router/Firebase)
- [x] Selectors: `Key('shell.rail.{dashboard,tasks,chat,budget,profile}')`, `Key('shell.bar.{dashboard,tasks,chat,budget,profile}')`, `Key('shell.rail.signOut')`
- [ ] Manual smoke: `flutter build web --release --dart-define=FLAVOR=dev && firebase deploy --only hosting:crewpoint-dev`; open the Firebase-default URL (`crewpoint-dev.web.app` or default) in Chrome at >720 width, confirm rail — **manual user step (requires Firebase Hosting site provisioned + `firebase target:apply hosting crewpoint-dev <site-name>` first)**
- [x] Verify: `flutter analyze` && `flutter test` (138 tests pass; 0 analyzer issues)

### Phase 2: Repo polish + CI

- **Goal**: LICENSE/CONTRIBUTING/CI green; mobile-feature PRs gated; web-build only when relevant
- [x] `LICENSE` — MIT, copyright `Sookoon Space`, year `2026`
- [x] `CONTRIBUTING.md` — branching, conventional commits, test/analyze gates, links to `ai_specs/setup-guide.md`, `docs/cloud-functions-guide.md`, future `docs/web-hosting-guide.md`
- [x] `.github/PULL_REQUEST_TEMPLATE.md` — Summary / Changes / Testing / Screenshots / Checklist
- [x] `.github/workflows/flutter.yml` — checkout, Flutter `stable`, pub-cache cache, `flutter pub get`, `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze`, `flutter test` (no web build); job `flutter`. Inline grep guard that fails the build if any test references `Firebase.initializeApp` or `FirebaseService.initialize`.
- [x] `.github/workflows/web-build.yml` — `paths: lib/**, web/**, pubspec.yaml, pubspec.lock, firebase.json`; checkout, Flutter stable, `flutter build web --release --dart-define=FLAVOR=dev`; job `web-build`
- [x] `.github/workflows/functions.yml` — `paths: functions/**, firebase.json`; Node 22, `npm ci && npm run build`; job `functions`
- [x] `.github/workflows/release-drafter.yml` + `.github/release-drafter.yml` — categories Features/Fixes/Docs/Chores/Breaking; semver auto-resolver
- [x] `CHANGELOG.md` — Keep-a-Changelog; backfilled prior milestones (tasks/budget/chat phases through Phase 9, plus pre-tasks foundations) and current `[Unreleased]` shape
- [x] `README.md` — added badges row (Flutter CI, Web Build CI, Functions CI, License-MIT) below title; `## Screenshots` placeholder + `## Contributing` + `## License` sections (Phase 6 fills the screenshot images)
- [x] Guard: `grep -rn "Firebase.initializeApp\|FirebaseService.initialize" test/` returns empty (CI invariant) — passes today; enforced by `flutter.yml` step "Verify tests do not initialize Firebase"
- [ ] Verify: open a smoke PR; confirm `flutter`, `web-build` (if paths trigger), `functions` workflows run green — **manual user step (requires push to GitHub remote)**

### Phase 3: PDF + CSV reporting

- **Goal**: Budget + Tasks export downloadable files on web (Wasm-safe) and share on mobile.
- [ ] `pubspec.yaml` — add `pdf: ^3.11.0`, `printing: ^5.13.0`, `csv: ^6.0.0`
- [ ] `lib/app/core/constants/app_pdf_theme.dart` — `PdfColor` mirrors of `AppColors`
- [ ] `lib/app/features/budget/data/expense_pdf_builder.dart` — pure `Future<Uint8List> buildExpenseReport({event, expenses, memberNames, ledger})`
- [ ] `lib/app/features/budget/data/expense_csv_builder.dart` — pure `String buildExpenseCsv({event, expenses, memberNames})`
- [ ] `lib/app/features/tasks/data/task_pdf_builder.dart` — pure `Future<Uint8List> buildTaskReport({event, tasks, memberNames})`
- [ ] `lib/app/core/services/file_export_service.dart` — `IFileExporter` interface + `FileExporterService` impl with `kIsWeb` branch (web Blob+anchor uses **`package:web` + `dart:js_interop`** — never `dart:html`; mobile uses `Printing.sharePdf` / `share_plus.shareXFiles`)
- [ ] `lib/app/core/providers.dart` — `fileExporterProvider`
- [ ] `lib/app/features/budget/presentation/widgets/budget_export_menu.dart` — popup menu with `Key('budget.export.pdf')`, `Key('budget.export.csv')`
- [ ] `lib/app/features/budget/presentation/budget_screen.dart` — wire export menu into AppBar `actions`; resolve `memberNames` via `usersByIdProvider`
- [ ] `lib/app/features/tasks/presentation/event_tasks_page.dart` — AppBar action `Key('tasks.export.pdf')`
- [ ] TDD: CSV builder writes RFC-4180 header + rows; commas/quotes/newlines escaped
- [ ] TDD: CSV builder handles zero expenses (header-only output)
- [ ] TDD: expense PDF builder produces non-empty `Uint8List` parseable by `pdf` package; expected page count for sample event
- [ ] TDD: expense PDF builder embeds slate-grey placeholder when receipt fetch throws (never bubbles)
- [ ] TDD: expense PDF builder caps at 200 pages with "Truncated — filter to see more"
- [ ] TDD: task PDF builder sections by status with row counts; checklist progress fraction rendered
- [ ] TDD: removed-from-event member resolves to `"(no longer in event)"`
- [ ] TDD: `IFileExporter` selector — web path produces `application/pdf` mime + slugified filename; mobile path delegates to share sheet
- [ ] Robot journey: `test/journeys/export_journey_test.dart` — seed event w/ 3 expenses → tap `Key('budget.export.pdf')` → assert `RecordingFileExporter.lastShare` mime + filename pattern; repeat for CSV; repeat PDF from `EventTasksPage`
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 4: Production hosting + CORS + Apple `.well-known`

- **Goal**: `https://crewpoint.sookoon.space` resolves to prod build with valid SSL; Storage CORS narrow to subdomain; Apple domain-verification file in place.
- [ ] `firebase.json` — extend `hosting` array with `crewpoint-stg`, `crewpoint-prod` entries (each with predeploy `flutter build web --release --dart-define=FLAVOR={flavor}`, SPA rewrite, cache headers `**/*.{js,wasm}` immutable, `index.html` no-cache)
- [ ] `.firebaserc` — register stg + prod project aliases and hosting targets
- [ ] Re-run `flutterfire configure --project=crewpoint-stg` and `--project=crewpoint-prod` so `firebase.json` Dart map registers `web` for both flavors (existing `web` blocks in `firebase_options_*.dart` left alone)
- [ ] `web/manifest.json` — rebrand: `name: "CrewPoint"`, `short_name: "CrewPoint"`, `description: "Collaborative event management — by Sookoon."`, `theme_color` = `AppColors.cream` hex, icons 192/512/maskable
- [ ] `web/index.html` — title `"CrewPoint"`, fav-tag, `<meta name="apple-mobile-web-app-capable" content="yes">`, drop default scaffold meta lines
- [ ] `web/.well-known/apple-developer-domain-association.txt` — placeholder + replacement comment (real value added in Phase 6 after Apple Services ID is configured)
- [ ] `infra/storage-cors.json` — `[{"origin":["https://crewpoint.sookoon.space"],"method":["GET","HEAD"],"responseHeader":["Content-Type","Cache-Control","Content-Length"],"maxAgeSeconds":3600}]`
- [ ] `scripts/apply-cors.sh` — wrap `gsutil cors set infra/storage-cors.json gs://crewpoint-{flavor}.appspot.com`; idempotent
- [ ] `docs/web-hosting-guide.md` — Firebase Hosting custom-domain wizard for subdomain; Namecheap CNAME (apex unchanged); SSL provisioning; flavor-aware deploy commands; rollback; CORS apply step; **note**: `authDomain` stays at `crewpoint-prod.firebaseapp.com` for V1 (white-label later requires adding subdomain as Firebase Hosting site first); cross-link to `docs/cloud-functions-guide.md`
- [ ] `ai_specs/setup-guide.md` — add brief "web setup" pointer to `docs/web-hosting-guide.md`
- [ ] `docs/cloud-functions-guide.md` — note hosting deploy is sibling concern; cross-link
- [ ] Manual smoke: `firebase deploy --only hosting:crewpoint-prod` (predeploy auto-builds); open `https://crewpoint.sookoon.space` incognito; confirm SSL valid + side rail renders + apex `https://sookoon.space/` still serves Namecheap site unchanged
- [ ] Manual smoke: open Budget on a public event with one receipt; browser console shows zero CORS errors
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 5: Marketing microsite (cross-repo PR in `/Users/googoo/Websites/sookoon_space`)

- **Goal**: `https://sookoon.space/crewpoint/` mirrors `/sanctuary/` shape; "Open web app" CTA → subdomain; privacy/terms pages publicly reachable (gates Phase 6).
- [ ] (sookoon_space) `app/[locale]/crewpoint/page.tsx`, `layout.tsx` — mirror `app/[locale]/sanctuary/` shape; CrewPoint brand colors + copy
- [ ] (sookoon_space) `app/[locale]/crewpoint/{about,how-it-works,download,faq,privacy,terms,guidelines,contact}/page.tsx` — mirror Sanctuary subroutes
- [ ] (sookoon_space) `app/crewpoint/page.tsx` — locale-redirect mirroring `app/sanctuary/page.tsx`
- [ ] (sookoon_space) `app/[locale]/apps/page.tsx` — add CrewPoint entry to `apps` array (cream/sage/terracotta accents)
- [ ] (sookoon_space) `messages/{en,es,hi}.json` — add `crewpointPage.*` and `appsPage.crewpoint.*` keys (English copy V1; ES/HI fallback)
- [ ] (sookoon_space) Primary CTA on `crewpoint/page.tsx` and `crewpoint/download/page.tsx`: **"Open web app"** → `https://crewpoint.sookoon.space`, `target="_blank" rel="noopener noreferrer"`
- [ ] (sookoon_space) `DEPLOY_NAMECHEAP.md` — extend Step 4 test list with `/crewpoint/`, `/crewpoint/about/`, `/crewpoint/privacy/`, etc.
- [ ] (crewpoint_app) Deliverables to marketing PR: launcher icon PNG (resize from `assets/icons/launcher_icon.png`), copy strings (tagline + features + FAQ), reviewed privacy/terms/guidelines text, final web-app URL
- [ ] Manual smoke: `npm run build` in sookoon_space; FTP upload `out/`; `curl https://sookoon.space/crewpoint/privacy/` returns 200 with privacy page content; "Open web app" CTA navigates to `https://crewpoint.sookoon.space`
- [ ] Verify (this repo unchanged): `flutter analyze` && `flutter test`

### Phase 6: Apple sign-in + screenshots + final docs

- **Goal**: Apple sign-in works on web round-trip; placeholder screenshots in repo + README; spec done.
- [ ] Apple Developer Console: create Services ID `com.sookoonspace.crewpoint.web`; enable Sign in with Apple; Configure → Return URLs `https://crewpoint.sookoon.space/__/auth/handler` + `https://crewpoint.sookoon.space/__/auth/iframe`; primary App ID linked
- [ ] Apple Developer Console: domain verification — download Apple-issued domain-association content; replace `web/.well-known/apple-developer-domain-association.txt` placeholder; `firebase deploy --only hosting:crewpoint-prod`; verify Apple console "Verified"
- [ ] Apple Developer Console: generate `.p8` key; Firebase Console → Auth → Sign-in providers → Apple → upload `.p8` + Services ID + Team ID; **do not commit `.p8`**
- [ ] Firebase Auth → Authorized Domains: add `crewpoint.sookoon.space` (keep `crewpoint-prod.firebaseapp.com`)
- [ ] `lib/app/features/auth/data/firebase_auth_service.dart` — extend `_mapFirebaseError` with `auth/popup-blocked`, `auth/popup-closed-by-user`, `auth/cancelled-popup-request`
- [ ] `pubspec.yaml` — audit `sign_in_with_apple`; remove if unused (grep across `lib/`)
- [ ] `lib/app/features/auth/presentation/auth_gate_screen.dart` — show Apple sign-in tile on web (`kIsWeb` toggle if not already)
- [ ] TDD: `_mapFirebaseError('auth/popup-blocked')` returns user-friendly "Please allow pop-ups…" string
- [ ] TDD: `_mapFirebaseError('auth/cancelled-popup-request')` returns "Sign-in cancelled" (or equivalent)
- [ ] Widget test: `_AuthGateScreen` renders Apple tile on web target only
- [ ] `test/screenshots/dashboard_screenshot_test.dart`, `budget_screenshot_test.dart`, `tasks_screenshot_test.dart`, `chat_screenshot_test.dart` — render at iPhone (375×812) + desktop (1280×800); each wraps the screen in a 1px terracotta-bordered Container with overlay "PLACEHOLDER — replace before public launch"; **all tagged `@Tags(['screenshots'])`** so default `flutter test` skips them
- [ ] `scripts/regenerate-screenshots.sh` — `flutter test --update-goldens --tags screenshots test/screenshots/`
- [ ] `screenshots/` — committed PNGs produced by the regen script
- [ ] `README.md` — `## Screenshots` section embeds the four PNGs via relative paths
- [ ] `docs/web-hosting-guide.md` — finalize Apple section: Services ID setup, domain verification, `.p8` upload, post-deploy `curl … | grep PLACEHOLDER` guard
- [ ] `ai_specs/todo.md` — remove "Web platform support (CORS, FCM web push)"; add follow-ups (FCM web push, RTL audit, rules emulator harness, `authDomain` white-label)
- [ ] Manual smoke: incognito → `https://crewpoint.sookoon.space` → "Sign in with Apple" → Apple popup → returns to dashboard; verify `users/{uid}` doc created
- [ ] Manual smoke: `curl -fsSL https://crewpoint.sookoon.space/.well-known/apple-developer-domain-association.txt | grep -q PLACEHOLDER` → fails (placeholder gone)
- [ ] Verify: `flutter analyze` && `flutter test` && `cd functions && npm run build && cd ..`

## Risks / Out of scope

- **Risks**:
  - Apple Services ID setup is manual + brittle; allow buffer in Phase 6 for domain-verification round-trip with Apple
  - `flutterfire configure` re-runs may rewrite `firebase.json`'s `flutter.platforms.dart` map and stomp existing entries — diff carefully, commit before running
  - `dart:js_interop` + `package:web` Blob/anchor download has fewer code samples than the legacy `dart:html` path; budget extra time for the web CSV adapter
- **Out of scope**:
  - Firestore + Storage rules emulator harness (deferred again)
  - FCM web push, real-device push smoke
  - Multi-currency / FX, server-side PDF generation
  - `EventRepository` Firestore-stream + Drift-mirror refactor
  - `authDomain` white-label to `crewpoint.sookoon.space` (V2)
  - ES/HI translations beyond the marketing-site stub-fallback
  - LICENSE other than MIT, real screenshots before public launch
