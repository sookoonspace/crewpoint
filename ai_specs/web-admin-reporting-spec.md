<goal>
Bring the desktop / web experience to parity with the mobile app for event planners and admins so they can run a session from a laptop instead of a phone, and clean up the GitHub repo so external contributors and onlookers see a polished, contributor-friendly project.

Two parallel tracks:

1. **Web Admin & Reporting** — responsive `AppShell` (bottom nav on mobile, side rail on desktop), Firebase Hosting on the **`crewpoint.sookoon.space` subdomain** (the apex `sookoon.space` is owned by the separate Sookoon LLC marketing site and stays on Namecheap), branded PDF expense + task reports and CSV expense exports, Apple sign-in on web, Cloud Storage CORS allow-list so receipts and profile pictures load without browser errors.
2. **Repo polish** — `LICENSE` (MIT), `CONTRIBUTING.md`, GitHub Actions CI (Flutter analyze+test+web-build smoke; Functions TypeScript build), README CI badges, auto-generated placeholder `screenshots/` (with a "replace before public launch" watermark), `CHANGELOG.md` + GitHub Releases via `release-drafter`.

This spec is for `crewpoint_app` (Flutter + Riverpod 3 + Firebase + Drift). Mobile features (Tasks, Budget, Chat, FCM seams) shipped in the prior `tasks-budget-chat` plan; that data layer is the foundation this spec extends.
</goal>

<background>
**Tech stack & constraints**

- Flutter 3.11.5 / Dart 3.x; Riverpod 3 (hand-written `Notifier`s); `go_router` 14
- Firebase: Auth, Firestore, Storage, Cloud Functions (TS v2), Messaging
- Drift v4 (mobile cache); web reads from Firestore directly (no Drift/sqlite on web)
- Three flavors: `crewpoint-dev`, `crewpoint-stg`, `crewpoint-prod`
- Web is already enabled (`web/` folder exists; `firebase_options*.dart` has the `kIsWeb` branch); the `web/manifest.json` is still the default Flutter scaffold and must be rewritten as part of this spec
- The mobile `AppShell` (`lib/app/core/router/app_shell.dart`) is bottom-nav-only with five branches (Dashboard / Tasks / Chat / Budget / Profile)
- `firebase.json` has no `hosting` block yet — Firebase Hosting must be wired in this spec
- No `.github/` directory — CI is greenfield
- Repo lives at `git@github.com:sookoonspace/crewpoint.git` (public)

**Hosting topology (cross-repo)**

- The Flutter web app for this spec is hosted on Firebase Hosting at the subdomain **`crewpoint.sookoon.space`**.
- The apex `https://sookoon.space` is owned by the separate Sookoon LLC marketing repo at `/Users/googoo/Websites/sookoon_space` (Next.js i18n static export, deployed to Namecheap shared hosting via FTP/cPanel; see `next.config.js` and `DEPLOY_NAMECHEAP.md` in that repo). It already serves `/`, `/about/`, `/apps/`, `/contact/`, `/sanctuary/*`, and locale-prefixed routes (`/en/`, `/es/`, `/hi/`). **The apex is not changed by this spec.**
- The marketing repo will gain a `crewpoint/` microsite mirroring the existing `sanctuary/` microsite, plus an "Open web app" CTA pointing at the Firebase-hosted subdomain. That work is scoped under section F and lives in a separate PR in the `sookoon_space` repo.
- Firebase Auth's `authDomain` for prod stays at the default `crewpoint-prod.firebaseapp.com` for V1 (the OAuth popup will show that hostname). White-labeling `authDomain` to `crewpoint.sookoon.space` is documented as a future enhancement in `web-hosting-guide.md`; it requires the subdomain to be a Firebase Hosting site first and adds Authorized Domains complexity.

**Files to examine before implementing**

- `@lib/app/core/router/app_shell.dart` — current bottom-nav shell to evolve
- `@lib/app/core/router/app_router.dart` — `StatefulShellRoute.indexedStack` config + `onRouteChanged` hook
- `@lib/app/features/budget/presentation/budget_screen.dart` — where the export CTAs land
- `@lib/app/features/budget/domain/models/balance_ledger.dart` — feeds the PDF
- `@lib/app/features/tasks/presentation/event_tasks_page.dart` — where the task PDF CTA lands
- `@firebase.json` — needs new `hosting` block + flavor-aware deploy targets
- `@web/manifest.json` and `@web/index.html` — defaults must be rebranded
- `@lib/firebase_options*.dart` — confirm web `appId` exists for prod (currently dev-only)
- `@docs/cloud-functions-guide.md` — the deploy doc style to mirror
- `@README.md` — already rewritten; will gain CI badges + screenshot section
- `@ai_specs/setup-guide.md` — Firebase + flavor setup, gets a new "web hosting" section

**Out of scope** (to keep V1 honest):

- Firestore + Storage **rules emulator harness** — deferred again to a future spec; **CI does not run rules tests in this spec**
- Refactoring `EventRepository` to Firestore-stream + Drift-mirror (long-standing `todo.md` item)
- Real-device push smoke / FCM bootstrap wiring (separately tracked from the previous plan)
- Multi-currency display / FX conversion
- Server-side PDF generation; everything renders client-side
- Web push notifications (FCM web)
</background>

<user_flows>

## Web admin / reporting

**Primary — desktop planner runs the event end-to-end:**
1. Planner opens `https://crewpoint.sookoon.space` in Chrome/Safari/Firefox on desktop
2. Auth gate detects signed-out → email / Google / **Apple** sign-in tile rendered; sign-in completes via the web OAuth flow
3. Lands on Dashboard (left side rail visible: Dashboard / Tasks / Chat / Budget / Profile + a "Logout" affordance at the bottom)
4. Selects an event from the list → side rail stays; main pane shows the event hub
5. Navigates to Budget → sees expenses + balances + suggested settlements (same data as mobile)
6. Clicks "Export PDF" → browser downloads `{eventTitle}-expenses-{yyyy-mm-dd}.pdf`
7. Clicks "Export CSV" → browser downloads `{eventTitle}-expenses-{yyyy-mm-dd}.csv`
8. Navigates to Tasks → clicks "Export PDF" → downloads `{eventTitle}-tasks-{yyyy-mm-dd}.pdf`
9. Receipt thumbnails on the Budget screen and profile pictures in the member list render cleanly (no CORS console error)

**Alternative — same planner on a tablet (768×1024):**
- `≥720px` width matches → side rail renders (extended labels visible)
- Layout reflows when the tablet is rotated to portrait `<720px` → bar replaces rail, no jank, current branch preserved

**Alternative — Mobile (existing behavior):**
- Identical navigation surface but `NavigationBar` at the bottom, which is what the existing app already does. Nothing should regress.

**Alternative — Entry via Sookoon marketing site:**
- Visitor lands on `https://sookoon.space/` → clicks "Apps" → CrewPoint card on `/apps/` → clicks the CrewPoint card → arrives at `/crewpoint/` microsite (mirrors `/sanctuary/`) → clicks the **"Open web app"** primary CTA → opens `https://crewpoint.sookoon.space` in a new tab → auth gate (same as primary flow). The microsite is shipped from the `sookoon_space` repo (section F); the CTA URL is the only contract this spec carries.

**Alternative — Sign in with Apple on web:**
- Planner clicks "Sign in with Apple" on `crewpoint.sookoon.space` → Apple's sign-in popup → completes → redirected to `https://crewpoint.sookoon.space/__/auth/handler` → app receives the credential and signs the user in
- First sign-in creates the `users/{uid}` doc; profile completion lands on the Profile page

**Error flows:**
- **CORS not yet applied** on Storage → image fetch fails; UI shows a placeholder + a small "Image unavailable" tooltip; export functions still work (PDF embeds a placeholder rectangle for missing receipts, never crashes)
- **PDF generation OOM** (1000+ expenses) → snackbar "Report too large to generate in browser; please filter" + log; user can retry after filtering
- **CSV generation** → never throws; even with malformed data, fields are quoted and escaped per RFC-4180
- **Apple sign-in popup blocked** → snackbar "Pop-ups are blocked — please allow pop-ups for crewpoint.sookoon.space and try again"
- **Apple sign-in domain not yet verified** → user sees Apple's "Verification failed" message; deploy doc explicitly covers domain verification as a pre-launch step
- **Service worker stale (cached old build)** → `flutter build web --release` produces a content-hashed bundle; the web `flutter_service_worker.js` invalidates on version bump

## Repo / GitHub flows (developer / contributor)

**Primary — contributor opens a PR:**
1. Pushes branch → opens PR on GitHub
2. CI runs three workflows in parallel:
   - `flutter.yml` — `flutter analyze`, `flutter test`, `flutter build web --release`
   - `functions.yml` — `cd functions && npm ci && npm run build`
3. Both must be green before merge; status badges in the README mirror the latest `main`-branch run
4. After merge, `release-drafter` updates the draft release notes from labeled PRs

**Primary — onboarding a new contributor:**
1. Lands on README → reads overview, sees CI badges showing repo health, sees screenshots
2. Clicks LICENSE → MIT, no surprise
3. Clicks CONTRIBUTING.md → finds branching, commit-message format, test/analyze gates, link to setup-guide

</user_flows>

<requirements>

## A. Responsive AppShell

**Functional:**
1. New `lib/app/core/widgets/responsive_shell.dart` wraps `StatefulNavigationShell` and chooses layout via `LayoutBuilder` on a single breakpoint: `< 720` width → `NavigationBar` (existing); `≥ 720` → `NavigationRail` with `extended: true` and `labelType: NavigationRailLabelType.none` (because rails with extended labels don't take a `labelType`)
2. Both branches share the same five destinations (Dashboard / Tasks / Chat / Budget / Profile) and route to the same `StatefulShellBranch`es; the active branch index is preserved across breakpoint transitions
3. Side rail includes a leading hero (app icon + "CrewPoint" wordmark), the destinations group, and a trailing **Sign out** action that calls the existing `authProvider.notifier.signOut()`
4. Body content is wrapped in a `Center` + `ConstrainedBox(maxWidth: 1280)` only on web (`kIsWeb && width ≥ 720`) to avoid stretched line lengths on ultra-wide monitors

**Edge Cases:**
5. Width crosses the 720 threshold mid-session → branch index, route stack, scroll position preserved; no rebuild flicker. **Mechanism**: `ResponsiveShell` returns a single `Scaffold` whose `body` is always `navigationShell` (the `StatefulNavigationShell` keeps the same `Element`); only the rail/bar siblings swap by width. Never branch the entire `Scaffold` in `LayoutBuilder` — that re-mounts the shell and resets branch state.
6. Very narrow rail (e.g., 720–799 width) renders compact rail (no labels) until ≥ 800; this avoids label truncation
7. Mobile portrait + landscape both stay in `NavigationBar` regardless of width because of `MediaQuery.devicePixelRatio` heuristics? **Use raw width only — keep the contract simple**

**Validation:**
8. `responsive_shell_test.dart` pumps the shell at three sizes (375×800, 800×600, 1280×800) and asserts: `NavigationBar` present at the small size, `NavigationRail` present at the medium and large sizes, branch index round-trips after a mid-test width change, and a `ScrollController` offset on the active branch survives the resize (proves the shell is not re-mounted).

## B. Web hosting on `crewpoint.sookoon.space`

**Functional:**
9. `firebase.json` gains a `hosting` array with three entries (one per flavor target: `crewpoint-dev`, `crewpoint-stg`, `crewpoint-prod`). Each entry sets `public: build/web`, single-page rewrites (`/**` → `/index.html`), cache headers (aggressive on `**/*.{js,wasm}`, no-cache on `index.html`), and a flavor-aware `predeploy` hook so deploys cannot ship a stale bundle:
    ```json
    "predeploy": [
      "flutter build web --release --dart-define=FLAVOR=prod"
    ]
    ```
    Document the `FLAVOR` dart-define → `firebase_options_*.dart` selection mechanism in `web-hosting-guide.md`.
10. **Create** `.firebaserc` (does not exist yet): define `projects` (default + `dev`/`stg`/`prod` aliases for `crewpoint-{flavor}`) and `targets` (hosting → `crewpoint-{flavor}-web` per flavor). Document the one-time `firebase target:apply hosting <target> <site>` command in `web-hosting-guide.md`. Wire each flavor's hosting target through `firebase.json` under `hosting[*].target`.
11. Re-run `flutterfire configure --project=crewpoint-prod` and `--project=crewpoint-stg` so `firebase.json`'s `flutter.platforms.dart` map registers `web` under prod and stg (currently lists iOS only). The existing `web` `FirebaseOptions` blocks in `lib/firebase_options_prod.dart:49-57` and `lib/firebase_options_stg.dart` already exist and must not be hand-edited or duplicated; verify they match the Firebase console after re-configuring.
12. `web/manifest.json` rewritten: `name: "CrewPoint"`, `short_name: "CrewPoint"`, `description: "Collaborative event management — by Sookoon."`, `theme_color` = `AppColors.cream` hex, `background_color` = `#FFFFFF`, `orientation: "any"`, icons sized 192/512/maskable (reuse mobile launcher icons; placeholder fallback if missing).
13. `web/index.html` rewritten: title `"CrewPoint"`, fav-tag pointing at `favicon.png`, removes the default `description`/`apple-touch-icon` Flutter scaffold lines.
14. New `docs/web-hosting-guide.md` walks the human steps: Firebase Hosting setup, custom domain `crewpoint.sookoon.space` (custom-domain wizard in Firebase Hosting console), **DNS for the subdomain only** at the Namecheap DNS panel — add a CNAME (or the A records Firebase's wizard provides) for the `crewpoint` subdomain pointing at Firebase Hosting; **the apex `sookoon.space` A/AAAA records remain unchanged and continue to point at Namecheap shared hosting.** SSL provisioning, deploy command per flavor, rollback.
15. *Removed.* Apex / `www` redirect behavior is owned by the Sookoon marketing repo (`/Users/googoo/Websites/sookoon_space`) + Namecheap `.htaccess`; this spec does not touch it.

**Apple sign-in on web:**
16. `lib/app/features/auth/data/firebase_auth_service.dart` already calls `_firebaseAuth.signInWithProvider(AppleAuthProvider..addScope('email')..addScope('name'))` (see `firebase_auth_service.dart:86-97`). `signInWithProvider` already drives both the iOS system sheet and the web popup with no `kIsWeb` branch needed — do not re-introduce one. Required code-side work in this spec is limited to: (a) extend `_mapFirebaseError` with `auth/popup-blocked`, `auth/popup-closed-by-user`, and `auth/cancelled-popup-request` cases; (b) audit whether the unused `sign_in_with_apple` package can be removed from `pubspec.yaml`. The cross-platform behavior contract is provided by `firebase_auth` itself; the heavy lifting is the Apple Developer Console + Firebase Auth provider configuration in req #17.
17. `web-hosting-guide.md` documents the Apple Developer Console setup: Services ID (`com.sookoonspace.crewpoint.web`), Return URL `https://crewpoint.sookoon.space/__/auth/handler` and `https://crewpoint.sookoon.space/__/auth/iframe`, Sign in with Apple Configuration, generated `.p8` private key uploaded to Firebase Auth → Apple provider; domain verification via Apple-provided file at `/.well-known/apple-developer-domain-association.txt`.
18. The verification file `web/.well-known/apple-developer-domain-association.txt` is committed (placeholder + replacement instructions) so the deploy bundle includes it; documented in `web-hosting-guide.md`. **Post-deploy guard**: the guide instructs running `curl -fsSL https://crewpoint.sookoon.space/.well-known/apple-developer-domain-association.txt | grep -q 'PLACEHOLDER' && echo 'Apple verification file is still the placeholder — replace before launch'` after every prod deploy until launch, so the placeholder cannot ship undetected.
19. `web/index.html` includes `<meta name="apple-mobile-web-app-capable" content="yes">` so iOS Safari treats the home-screen icon as a standalone app.

**Error Handling:**
20. Auth-domain mismatch on first sign-in → user-friendly "We couldn't sign you in — please try again" + log via `dart:developer`; do not leak the raw Firebase error.
21. Pop-up blocked → catch `auth/popup-blocked`, surface "Please allow pop-ups for crewpoint.sookoon.space and try again" snackbar.

## C. Storage CORS

**Functional:**
22. `infra/storage-cors.json` defines the CORS rule for the Storage bucket: origins = `["https://crewpoint.sookoon.space"]`; methods = `["GET", "HEAD"]`; `responseHeader` includes `Content-Type`, `Cache-Control`, `Content-Length`; `maxAgeSeconds: 3600`. The marketing apex `https://sookoon.space` is **not** in the allow-list — the marketing site only deep-links into the web app and never fetches Storage assets directly.
23. `scripts/apply-cors.sh` runs `gsutil cors set infra/storage-cors.json gs://crewpoint-{flavor}.appspot.com` for each flavor; idempotent and safe to re-run.
24. `docs/web-hosting-guide.md` references the script as a one-time step per flavor and re-run-after-domain-changes step.
25. The CORS allow-list is intentionally narrow — the `crewpoint.sookoon.space` Firebase-hosted subdomain only. The marketing apex (`sookoon.space`, `www.sookoon.space`) is excluded by design (it does not fetch Storage). Local-dev `localhost` is **not** added because Flutter web in dev runs against the emulator suite where CORS is permissive by default. Document this trade-off.

## D. PDF + CSV reporting

**Functional:**
26. `pubspec.yaml` adds `pdf: ^3.11.0`, `printing: ^5.13.0`, and `csv: ^6.0.0` (or hand-rolled CSV — see implementation). Pure Dart; works on web via the `printing` web plug-in (`printing_web`). Versions are starting points — `flutter pub get` resolves to the latest compatible.
27. New pure builders (no Flutter / Firebase imports beyond `pdf` package types):
    - `lib/app/features/budget/data/expense_pdf_builder.dart` — `Future<Uint8List> buildExpenseReport({required EventModel event, required List<ExpenseModel> expenses, required Map<String, String> memberNames, required BalanceLedgerSnapshot ledger})`
    - `lib/app/features/budget/data/expense_csv_builder.dart` — `String buildExpenseCsv({required EventModel event, required List<ExpenseModel> expenses, required Map<String, String> memberNames})`
    - `lib/app/features/tasks/data/task_pdf_builder.dart` — `Future<Uint8List> buildTaskReport({required EventModel event, required List<TaskModel> tasks, required Map<String, String> memberNames})`
28. PDF branding: cream background, sage section headers, terracotta-only for warning/owe states; reuses `AppColors` constants reflected as `PdfColor`s in a small `app_pdf_theme.dart` helper. Header line: app logo + event title + currency + date range + generated-at timestamp.
29. **Expense PDF** content (in this order):
    - Header (event title, currency, generated-at)
    - "Total spent" big number
    - "Member balances" rows: name + sign + amount (sage for positive, terracotta for negative)
    - "Settle up" rows: from → to + amount
    - "Expenses" table: date, payer, description, amount, donation-flag, splits (compact), receipt thumbnail (40×40, embedded inline) — receipts that fail to fetch render a slate-grey rectangle with "no image"
    - Footer page numbers + "Generated by CrewPoint"
30. **Task PDF** content:
    - Header (event title, generated-at)
    - Sections by status (Done / In Progress / To Do) with row counts
    - Each row: title, assignee, due date, completed-by + completed-at if Done, checklist progress fraction
    - Footer page numbers + "Generated by CrewPoint"
31. **CSV** columns: `id,createdAt,payerId,payerName,amount,currency,isDonation,isPayment,description,receiptPath,splits` where `splits` is a JSON-string-quoted array; full RFC-4180 escaping (commas, quotes, newlines).
32. CSV filename: `{slugify(eventTitle)}-expenses-{yyyy-mm-dd}.csv`. PDF filenames analogous.

**Output handling:**
33. Single helper `lib/app/core/services/file_export_service.dart`:
    - `Future<void> share(Uint8List bytes, String filename, String mimeType)` — `kIsWeb` branch; web calls `Printing.sharePdf` (PDFs) or builds a `Blob` + anchor download (CSV); mobile calls `Printing.sharePdf` (PDFs) and `share_plus.shareXFiles` (CSV).
    - **Wasm-safe interop**: the web Blob + anchor download path **must use `package:web` + `dart:js_interop`** (`Blob`, `URL.createObjectURL`, `HTMLAnchorElement`) — never `dart:html`. This keeps the bundle compatible with `flutter build web --wasm` (dart2wasm), which `dart:html` blocks. The `printing` package already exposes a Wasm-safe surface for the PDF path.
    - All callers go through this seam; tests use a `FakeFileExporter`.

**UI surfaces:**
34. `BudgetScreen` adds an action menu in the AppBar: "Export PDF" (`Key('budget.export.pdf')`), "Export CSV" (`Key('budget.export.csv')`).
35. `EventTasksPage` adds an AppBar action: "Export PDF" (`Key('tasks.export.pdf')`).
36. Both lookup `memberNames` via the existing `usersByIdProvider` (Phase 7) so the reports show display names not UIDs.

**Error Handling:**
37. PDF / CSV builder throws → snackbar "Couldn't generate report" + `dart:developer` log; user never sees a stack trace.
38. Receipt fetch fails inside the PDF builder → embed placeholder + log; never throws.

**Edge Cases:**
39. Event with zero expenses → PDF still generates (empty tables with "No expenses yet"); CSV has only the header row.
40. Event currency != USD → totals and per-row amounts use the event currency symbol from `BudgetScreen._currencySymbol`.
41. Removed-from-event member appears in expenses → name resolves to `"(no longer in event)"` (not the UID).
42. PDF over 5 MB or 200 pages → cap at 200 pages; trailing "Truncated — filter to see more" line; no crash.

## E. Repo polish

**Functional:**
43. `LICENSE` — MIT, copyright `Sookoon Space`, current year (`2026`).
44. `CONTRIBUTING.md` — sections: Code of conduct (link to standard CC), branching (`feat/*`, `fix/*`, `docs/*`), conventional commits (`feat(scope): …`), PR template expectations, testing gates (`flutter analyze`, `flutter test`, `cd functions && npm run build`), link to `ai_specs/setup-guide.md`, link to `docs/web-hosting-guide.md`, link to `docs/cloud-functions-guide.md`. Mention release-drafter labels.
45. `.github/PULL_REQUEST_TEMPLATE.md` — Summary / Changes / Testing / Screenshots-if-UI / Checklist (analyze + tests pass).
46. `.github/workflows/flutter.yml` — runs on PR + push to `main`. Steps: checkout, setup Flutter `stable`, `flutter pub get`, `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze`, `flutter test`. Cache `~/.pub-cache`. Job name: `flutter`. **Tests must not call `Firebase.initializeApp()` / `FirebaseService.initialize()`**; widget and screenshot tests pump screens with Riverpod overrides for the `IAuthService` / `IUserRepository` / `IFcmGateway` seams (the existing pattern). Because `lib/firebase_options*.dart` is committed (not `.gitignore`d in this repo), CI does not need a dummy options file — the rule is "tests do not initialize Firebase", not "fake the options."
46b. `.github/workflows/web-build.yml` — runs only when `lib/**`, `web/**`, `pubspec.yaml`, or `firebase.json` change (`paths:` filter). Steps: checkout, setup Flutter `stable`, `flutter pub get`, `flutter build web --release`. Job name: `web-build`. Kept off the per-PR critical path so mobile-feature PRs don't pay the web-build cost.
47. `.github/workflows/functions.yml` — runs on PR + push to `main` when `functions/**` or `firebase.json` change. Steps: checkout, setup Node 22, `cd functions && npm ci && npm run build`. Cache `functions/node_modules`. Job name: `functions`.
48. `.github/workflows/release-drafter.yml` — runs on push to `main`; uses `release-drafter/release-drafter@v6` with `.github/release-drafter.yml` config (categories: Features / Fixes / Docs / Chores / Breaking).
49. `.github/release-drafter.yml` — config maps PR labels to changelog sections; uses semver auto-resolver based on label.
50. README badges added below the title (in the order): Flutter CI, Web Build CI, Functions CI, License-MIT.

**Screenshots:**
51. New `test/screenshots/` directory with golden-style "screenshot" tests that render real screens at fixed device frames and write PNGs to `screenshots/`. **Every test in this directory is tagged `@Tags(['screenshots'])`** so the default `flutter test` (and CI) does not run them — they only execute under `flutter test --tags screenshots` (the regen script). Tests:
    - `test/screenshots/dashboard_screenshot_test.dart` — pumps `DashboardScreen` with seeded state at iPhone (375×812) + desktop (1280×800)
    - `test/screenshots/budget_screenshot_test.dart` — `BudgetScreen` with sample data
    - `test/screenshots/tasks_screenshot_test.dart` — `TaskListScreen` with sample tasks
    - `test/screenshots/chat_screenshot_test.dart` — `ChatScreen` with mixed-kind messages incl. urgent
52. Each screenshot is a `Container` with a 1px terracotta border + bottom-right red overlay text **"PLACEHOLDER — replace before public launch"** so they can never accidentally ship as marketing material.
53. `scripts/regenerate-screenshots.sh` — `flutter test --update-goldens --tags screenshots test/screenshots/`. Runs locally; **not** part of CI.
54. README's "## Screenshots" section embeds them via relative paths.

**Release notes:**
55. `CHANGELOG.md` — Keep-a-Changelog style; backfilled with the prior tasks-budget-chat plan phases under `[Unreleased]`; instructs maintainers that `release-drafter` updates the draft notes automatically per PR labels and the human approves on GitHub Releases.

## F. Marketing microsite (separate repo: `/Users/googoo/Websites/sookoon_space`)

This section's work lives in the `sookoon_space` Next.js i18n marketing repo, not in `crewpoint_app`. It ships as a **separate PR** in that repo. Listed here so the cross-repo dependency is explicit and so the user-flow CTA URL is documented in one place.

**Functional:**
F1. New `app/[locale]/crewpoint/` route mirroring the existing `app/[locale]/sanctuary/` directory shape: `page.tsx`, `layout.tsx`, plus subroutes `about/`, `how-it-works/`, `download/`, `faq/`, `privacy/`, `terms/`, `guidelines/`, `contact/`. Use the same component primitives, motion, and i18n keys pattern as Sanctuary (see `app/[locale]/sanctuary/page.tsx` and the matching `messages/` translations).
F2. Top-level locale-redirect file `app/crewpoint/page.tsx` mirroring `app/sanctuary/page.tsx`'s `useRouter().replace('/${defaultLocale}/crewpoint')` pattern, so `https://sookoon.space/crewpoint` resolves to the default locale.
F3. Add a CrewPoint entry to the `apps` array in `app/[locale]/apps/page.tsx` (currently Sanctuary-only). Use the existing card layout — accent colors per CrewPoint brand (cream / sage / terracotta), `featured: true` toggle at the user's discretion.
F4. Primary CTA on `app/[locale]/crewpoint/page.tsx` and on `app/[locale]/crewpoint/download/page.tsx`: button labeled **"Open web app"** linking to `https://crewpoint.sookoon.space` with `target="_blank"` and `rel="noopener noreferrer"`. Secondary CTAs (App Store / Google Play badges) added when those listings exist.
F5. Translations added under `messages/{en,es,hi}.json` for keys `crewpointPage.*`, `appsPage.crewpoint.*`, mirroring Sanctuary's keyspace. English ships in V1; ES/HI may stub-fall-back to English copy until translated.
F6. Update `DEPLOY_NAMECHEAP.md` Step 4 ("Test the Site") with the new URLs:
    - `https://sookoon.space/crewpoint/`
    - `https://sookoon.space/crewpoint/about/`
    - `https://sookoon.space/crewpoint/privacy/`
    - …matching the Sanctuary list.

**Cross-repo deliverables (from `crewpoint_app` → `sookoon_space`):**
F7. Crewpoint logo + icon PNGs (reuse `assets/icons/launcher_icon.png` from this repo; resize for marketing card + microsite hero).
F8. Marketing copy strings (tagline, feature bullets matching this spec's `<goal>` sections, FAQ Q&A) — drafted in this spec's PR description, copied into `messages/en.json` keys in the marketing PR.
F9. Privacy + Terms + Community Guidelines text — must be reviewed and approved by the user before publishing publicly because Apple sign-in setup and the App Store / Play Store listings will reference these URLs.
F10. Final web-app URL (`https://crewpoint.sookoon.space`) — provided after the subdomain is provisioned in Stage D.

**Out of scope** (this spec):
- Building the microsite UI itself (it's authored in the marketing repo).
- Translating ES/HI copy (English-only V1 is acceptable; mirror Sanctuary's translation cadence).
- SEO / sitemap updates beyond what Next.js's built-in `sitemap.xml` produces automatically when the new routes are added.

**Validation (cross-cutting):**
56. `flutter analyze` clean on all platforms (`mobile`, `web`).
57. `flutter test` clean (existing 133 tests + the new responsive shell, builder, file-export, and screenshot tests).
58. `cd functions && npm run build` clean.
59. CI workflows green on a smoke PR after merging this spec.
60. The companion PR in `sookoon_space` is merged + deployed to Namecheap (per `DEPLOY_NAMECHEAP.md`); `https://sookoon.space/crewpoint/` is reachable; the "Open web app" CTA navigates to `https://crewpoint.sookoon.space`; `/crewpoint/privacy/` is reachable for Apple sign-in's privacy-URL field.

</requirements>

<boundaries>

**Edge cases**
- **Resize across the breakpoint mid-modal** — modals (e.g., ExpenseModal, DisputeSheet) close cleanly on resize across 720px; if open they remain dismissible, no Riverpod state corruption
- **Keyboard navigation on web** — destinations in the side rail are reachable via Tab; Enter navigates; documented behavior, not a separate test target
- **Right-to-left** — Material's NavigationRail handles RTL automatically; no extra work; not tested but documented in `todo.md` as a future check
- **Slow connection** — PDF builder shows an indeterminate progress dialog while running; bytes are produced before download triggers so partial downloads are impossible
- **Old browsers without `Blob`** — IE/legacy Edge unsupported; documented in `web-hosting-guide.md` as a known limitation; minimum target = last 2 versions of Chrome/Safari/Firefox/Edge

**Error scenarios**
- **CORS not yet applied** — receipts and avatars fall back to placeholders; explicit warning to deploy team in `web-hosting-guide.md` to apply CORS *before* directing users to `crewpoint.sookoon.space`
- **Apple sign-in misconfigured** — manual smoke required pre-launch; document the Apple Developer Console + Firebase Auth provider setup checklist
- **Service worker stuck on old build** — fix is the standard hard-refresh / "Empty Cache and Hard Reload"; documented in CONTRIBUTING.md troubleshooting
- **Auth domain mismatch** — Firebase Auth → "Authorized domains" must include `crewpoint.sookoon.space` (and `crewpoint-prod.firebaseapp.com`, which is the default OAuth `authDomain` for V1); documented as a deploy-time checklist item. The Sookoon marketing apex is **not** in Authorized Domains because it does not host the auth flow.

**Limits**
- **PDF max 200 pages** — beyond that, trailing "Truncated — filter to see more" line
- **CSV row count is unbounded** — yielding generation if > 5,000 rows so the main thread doesn't stall (`compute()`-style pattern via `Stream<String>` builder)
- **CORS allow-list narrow** — production domains only; emulator and local dev not in the prod allow-list (use the dev bucket for local web work)
- **Side rail breakpoint 720px** — single threshold to keep behavior simple; no compact-rail middle state in V1
- **CI minutes** — `flutter` workflow (analyze + test, no web build) caches `~/.pub-cache` to keep PR feedback under 3 minutes on most PRs. `web-build` workflow (release web compile) only fires on web-relevant path changes; it can run longer (5–8 min) without slowing mobile-feature PRs. `functions` workflow caches `node_modules` to keep under 1 minute.

</boundaries>

<implementation>

## Files to create

**Web admin / reporting**
- `lib/app/core/widgets/responsive_shell.dart` — breakpoint switch
- `lib/app/core/services/file_export_service.dart` — `IFileExporter` interface + web/mobile impl
- `lib/app/features/budget/data/expense_pdf_builder.dart` — pure
- `lib/app/features/budget/data/expense_csv_builder.dart` — pure
- `lib/app/features/tasks/data/task_pdf_builder.dart` — pure
- `lib/app/core/constants/app_pdf_theme.dart` — `PdfColor` mirrors of `AppColors`
- `lib/app/features/budget/presentation/widgets/budget_export_menu.dart` — UI binding
- `docs/web-hosting-guide.md` — deploy + Apple-sign-in walkthrough
- `infra/storage-cors.json` — CORS payload
- `scripts/apply-cors.sh` — wraps `gsutil cors set` per flavor
- `web/.well-known/apple-developer-domain-association.txt` — placeholder + replacement comment

**Repo polish**
- `LICENSE` — MIT
- `CONTRIBUTING.md`
- `.github/workflows/flutter.yml`
- `.github/workflows/web-build.yml`
- `.github/workflows/functions.yml`
- `.github/workflows/release-drafter.yml`
- `.github/release-drafter.yml`
- `.github/PULL_REQUEST_TEMPLATE.md`
- `CHANGELOG.md`
- `screenshots/` (output of golden tests)
- `scripts/regenerate-screenshots.sh`
- `test/screenshots/dashboard_screenshot_test.dart`, `budget_screenshot_test.dart`, `tasks_screenshot_test.dart`, `chat_screenshot_test.dart`

## Files to modify

- `pubspec.yaml` — add `pdf`, `printing`, `csv`; verify imports are Wasm-safe (no `dart:html`); audit `sign_in_with_apple` for removal
- `firebase.json` — add `hosting` array with flavor-aware deploy targets and `predeploy` hooks; re-register `web` under prod/stg in `flutter.platforms.dart` (rerun `flutterfire configure`)
- `.firebaserc` — **create** (does not exist); register `projects` aliases + hosting `targets` per flavor
- `lib/firebase_options_prod.dart` — **leave the `web` block alone** (already present); only re-verify against console after `flutterfire configure`
- `web/manifest.json` — rebrand
- `web/index.html` — rebrand + Apple meta tags
- `lib/app/core/router/app_router.dart` — `AppShell` swapped to `ResponsiveShell` (existing `AppShell` becomes the mobile-side internal of the new shell)
- `lib/app/features/auth/data/firebase_auth_service.dart` — extend `_mapFirebaseError` with `auth/popup-blocked`, `auth/popup-closed-by-user`, `auth/cancelled-popup-request` (no `kIsWeb` branch)
- `lib/app/features/budget/presentation/budget_screen.dart` — AppBar export menu
- `lib/app/features/budget/presentation/event_budget_page.dart` — wire export callbacks via `IFileExporter`
- `lib/app/features/tasks/presentation/event_tasks_page.dart` — AppBar export action
- `lib/app/core/providers.dart` — `fileExporterProvider`
- `README.md` — add CI badges, screenshots section
- `docs/cloud-functions-guide.md` — note that hosting deploy is now a sibling concern; cross-link to `web-hosting-guide.md`
- `ai_specs/setup-guide.md` — add a brief "web setup" pointer to `docs/web-hosting-guide.md`
- `ai_specs/todo.md` — remove "Web platform support (CORS, FCM web push)" line item; add follow-ups (FCM web push, RTL audit, rules emulator harness)

## Patterns to follow

- **Pure builders** — PDF and CSV builders have no Flutter / Firebase imports beyond the `pdf` package (which is pure Dart). They take domain models and return bytes / strings. This matches the `PayLinkBuilder` / `BalanceLedger` precedent in the existing codebase.
- **Riverpod test seams** — `IFileExporter` mirrors the `IUrlLauncher` / `IFcmGateway` pattern from Phase 5/8 so widget tests can verify "export was triggered with these bytes" without invoking the real share sheet.
- **`kIsWeb` branching** lives in service-layer adapters (`FileExporterService`) — never inside widgets. **Auth is the exception**: `FirebaseAuthService.signInWithApple` does **not** branch on `kIsWeb` — `firebase_auth`'s `signInWithProvider(AppleAuthProvider)` already handles both targets uniformly.
- **`ResponsiveShell` keeps `StatefulNavigationShell` as a single body child** — only rail/bar siblings swap by width, so branch index, route stack, and scroll position survive the breakpoint transition.
- **Tests do not initialize Firebase** — no test in the suite calls `Firebase.initializeApp()` or `FirebaseService.initialize()`. Pumped widgets use Riverpod overrides on the existing service interfaces (`IAuthService`, `IUserRepository`, `IFcmGateway`, `IFileExporter`, `IUrlLauncher`). This is why CI does not need a dummy `firebase_options.dart` — the real options files are committed and tests never reach them.
- **Branding constants** route through `app_pdf_theme.dart`; do not hardcode colors in builders.

## What to avoid (and why)

- **Do not import `dart:html`** — it is not Wasm-compatible and will block `flutter build web --wasm`. Use `package:web` + `dart:js_interop` for any Blob / anchor / DOM interop in the CSV download path.
- **Do not pull `flutter_pdfview`** — heavyweight, native-only; the `pdf` + `printing` combo is web-compatible and produces lighter bundles
- **Do not generate PDFs server-side** — Firebase Storage + a CF would add deploy complexity for a feature that already runs fine in the browser; revisit only if event sizes grow past the 200-page limit
- **Do not re-introduce a `kIsWeb` branch in `signInWithApple`** — `firebase_auth`'s `signInWithProvider(AppleAuthProvider)` already covers both targets; adding a separate `signInWithPopup` call would diverge code paths for no behavior gain
- **Do not initialize Firebase in tests** — no test calls `FirebaseService.initialize()`. Riverpod-override the service interfaces and the test suite stays platform-channel-free in CI
- **Do not deploy hosting without `predeploy`** — the `flutter build web --release` predeploy hook is non-optional; without it `firebase deploy --only hosting:*` will ship whatever stale bundle is in `build/web`
- **Do not run rules-emulator tests in CI yet** — the harness is the long-deferred chore from prior phases; it deserves its own spec rather than being smuggled into this one
- **Do not ship real screenshots** — placeholders only with "REPLACE BEFORE PUBLIC LAUNCH" overlay until product produces final captures (avoids a public repo carrying preliminary marketing material)
- **Do not let screenshot tests run on default `flutter test`** — they're tagged `screenshots` and gated behind the regen script
- **Do not skip flavor-aware hosting targets** — three flavors must be deployable independently or staging will leak into prod
- **Do not commit the real Apple `.p8` key** — it goes into Firebase Auth via the web console; the repo only carries the public domain-verification file
- **Do not let the Apple `apple-developer-domain-association.txt` placeholder ship to prod** — the post-deploy `curl … | grep PLACEHOLDER` guard in `web-hosting-guide.md` must run before public launch

</implementation>

<validation>

## Baseline coverage outcomes

Each track of this spec ships with three layers of coverage:

1. **Logic / business rules** — pure unit tests for PDF / CSV builders and `IFileExporter` selector logic.
2. **UI behavior** — widget tests for `ResponsiveShell` at multiple sizes, the export menu / button states, the empty-event PDF fallback path.
3. **Critical journeys** — robot-driven tests for the responsive switch + export flow.

## TDD expectations

For every builder + service-layer addition (`expense_pdf_builder`, `expense_csv_builder`, `task_pdf_builder`, `IFileExporter`, and `FirebaseAuthService._mapFirebaseError` extensions), follow strict vertical-slice RED → GREEN → REFACTOR cycles:

- Order behaviors **happy path → empty / boundary → error**; one failing test at a time.
- Required testability seams:
  - `IFileExporter` interface; widget tests use a `RecordingFileExporter` fake.
  - PDF builders return `Uint8List`; tests assert bytes are non-empty + the PDF parses (use `pdf`'s document parser to count pages, never compare bytes byte-for-byte).
  - CSV builder returns `String`; tests assert the header line and that each row's escapes are correct (commas, quotes, newlines).
  - `signInWithApple` web behavior is exercised by unit-testing `_mapFirebaseError` against `auth/popup-blocked`, `auth/popup-closed-by-user`, and `auth/cancelled-popup-request` codes; the `signInWithProvider` call itself is provided by `firebase_auth` and is verified by the manual smoke step in `web-hosting-guide.md` (cannot be unit-tested without a real Apple round-trip).

If any requirement cannot be driven test-first (Apple OAuth web round-trip, real Apple Developer Console state), flag the exception in the implementation PR and document the manual smoke step in `web-hosting-guide.md`.

## Robot journey expectations

Two new journeys ship with this spec, using the project's `flutter-robot-testing` skill conventions (`*Robot` API, deterministic seams, `Key('domain.feature.action')` selectors):

- **Web shell journey** (`test/journeys/web_shell_journey_test.dart`): pump `MyApp` at 1280×800 → assert `NavigationRail` is rendered → tap "Budget" rail destination → assert `BudgetScreen` is on-screen → resize to 600×800 → assert `NavigationBar` is rendered and the active branch is still Budget. Selectors: `Key('shell.rail.{destination}')`, `Key('shell.bar.{destination}')`.
- **Export journey** (`test/journeys/export_journey_test.dart`): seed an event with 3 expenses → open Budget → tap "Export PDF" → assert `RecordingFileExporter.lastShare` has bytes + `application/pdf` mime + filename pattern `*-expenses-*.pdf`. Repeat for CSV. Repeat the PDF case from `EventTasksPage`. Selectors: `Key('budget.export.pdf')`, `Key('budget.export.csv')`, `Key('tasks.export.pdf')`.

Required stable selectors (declared in each robot test alongside the screen-under-test):
- `Key('shell.rail.{dashboard,tasks,chat,budget,profile}')`, `Key('shell.bar.{dashboard,tasks,chat,budget,profile}')`
- `Key('shell.rail.signOut')`
- `Key('budget.export.pdf')`, `Key('budget.export.csv')`, `Key('tasks.export.pdf')`

Default test-type mapping:
- **Robot tests** — the two journeys above
- **Widget tests** — `ResponsiveShell` breakpoint behavior (3 sizes), export menu visibility, empty-event PDF path, `_AuthGateScreen` Apple sign-in tile rendered on web only (`kIsWeb` toggle)
- **Unit tests** — `expense_pdf_builder`, `expense_csv_builder`, `task_pdf_builder` (header / empty / RFC-4180 / page-cap), `IFileExporter` selector logic
- **Screenshot tests** — `test/screenshots/*` produce PNGs in `screenshots/` with the placeholder overlay

## Cross-cutting / repo polish

- `flutter analyze` clean
- `flutter test` clean (all existing tests + the new responsive-shell, builder, file-export tests; screenshot tests excluded by tag)
- `cd functions && npm run build` clean
- A smoke PR after the merge of this spec runs the `flutter`, `web-build` (when the diff touches web-relevant paths), and `functions` workflows green; README badges turn green within a minute of merge
- `flutter build web --release` completes locally and the bundle deploys via `firebase deploy --only hosting:crewpoint-dev` to a working URL (the `predeploy` hook re-runs the build to guarantee freshness)
- No test in the suite calls `Firebase.initializeApp()` / `FirebaseService.initialize()` (verifiable via `grep -r "initializeApp\|FirebaseService.initialize" test/` returning no results)

## Manual verification (required by user before launching `crewpoint.sookoon.space`)

The spec explicitly requires the user to perform these manual smokes since they cannot be unit-tested:

1. **Hosting** — Visit `https://crewpoint.sookoon.space` in incognito on a real desktop browser; sign in with email / Google / Apple; confirm side rail renders; resize the window below 720 and confirm bottom nav appears.
2. **CORS** — Open the Budget screen on a public event with at least one receipt; confirm the receipt thumbnail loads and the browser console shows no CORS error.
3. **Apple sign-in** — Click "Sign in with Apple"; complete the Apple popup; land back on the dashboard. Verify the `users/{uid}` doc was created.
4. **PDF export** — Click "Export PDF" on Budget and Tasks; verify the downloaded files open in a PDF reader and match the spec's content list.
5. **CSV export** — Click "Export CSV"; verify the file opens in Excel/Google Sheets and the splits column contains valid JSON.
6. **CI** — Open a no-op PR; confirm both `flutter` and `functions` workflows go green within 10 minutes; confirm release-drafter creates / updates a draft release.
7. **Service worker** — Deploy a second build; reload `crewpoint.sookoon.space`; confirm the new bundle loads (not stuck on cached old version).

</validation>

<stages>

This spec is best executed in six stages so each ships value independently and the PR can be reviewed in chunks. **Marketing-microsite stage is sequenced before Apple sign-in** so the privacy URL exists publicly when Apple Services ID is configured.

1. **Stage A — Repo polish** (LICENSE, CONTRIBUTING, CI workflows, README badges, CHANGELOG, release-drafter, PR template). No app code changes. Verify: CI workflows green on the merge PR.
2. **Stage B — Responsive shell** (`ResponsiveShell` + breakpoint widget tests + robot web shell journey). Verify: `flutter test` passes; pumping shell at 600/800/1280 widths shows the right control.
3. **Stage C — PDF + CSV reporting** (builders + `IFileExporter` + UI menus + robot export journey). Verify: unit tests for builders pass; export journey test passes; manual export from a real event produces a sane file.
4. **Stage D — Web hosting + CORS** (firebase.json hosting block with predeploy, `.firebaserc`, manifest + index rebrand, `infra/storage-cors.json` + apply script, `docs/web-hosting-guide.md`, custom domain `crewpoint.sookoon.space` provisioned in Firebase Hosting + Namecheap CNAME). Verify: `flutter build web --release` deploys to dev hosting URL; CORS allow-list applied; subdomain resolves with valid SSL. **Apple sign-in setup deferred to Stage F.**
5. **Stage E — Marketing microsite** (cross-repo PR in `sookoon_space`: `/crewpoint/` route mirroring `/sanctuary/`, `/apps/` page card, "Open web app" CTA → `https://crewpoint.sookoon.space`, privacy + terms pages live, `DEPLOY_NAMECHEAP.md` test list updated). Verify: `https://sookoon.space/crewpoint/` and `/crewpoint/privacy/` reachable on the production marketing host.
6. **Stage F — Apple sign-in + screenshots + final docs** (Apple Services ID using the now-public privacy URL from Stage E, return URL `https://crewpoint.sookoon.space/__/auth/handler`, `web/.well-known/apple-developer-domain-association.txt` deployed, `_mapFirebaseError` extended, golden screenshots, README "## Screenshots" section, `docs/web-hosting-guide.md` finalized, `ai_specs/setup-guide.md` + `ai_specs/todo.md` updated). Verify: Apple sign-in round-trip works against staging; `scripts/regenerate-screenshots.sh` produces the 4 placeholder PNGs; README renders them.

</stages>

<done_when>

- All requirements 1–60 are implemented, tested, and observably correct on `https://crewpoint.sookoon.space` (or a flavor equivalent for staging). Section F (60, F1–F10) ships in a companion PR in the `sookoon_space` repo.
- `flutter analyze`, `flutter test` (default tags, screenshot tests excluded), `cd functions && npm run build` all clean.
- CI workflows (Flutter, Web Build, Functions, release-drafter) green on `main`.
- README displays badges (Flutter CI, Web Build CI, Functions CI, License) all in passing state, and a `## Screenshots` section with the 4 placeholder images visible on GitHub.
- `LICENSE`, `CONTRIBUTING.md`, `CHANGELOG.md`, `.github/PULL_REQUEST_TEMPLATE.md` exist and are reachable from the repo's GitHub page.
- `firebase deploy --only hosting:crewpoint-prod` works (prod web app exists in `firebase_options_prod.dart`); `crewpoint.sookoon.space` resolves to the prod build with valid SSL via Firebase Hosting; the marketing apex `https://sookoon.space` continues to resolve via Namecheap unchanged; `https://sookoon.space/crewpoint/` (companion PR) renders the new microsite and the "Open web app" CTA navigates to `https://crewpoint.sookoon.space`.
- Apple sign-in works on web (manual verification by the user).
- Receipts and profile pictures load on `crewpoint.sookoon.space` with no CORS error in the browser console (manual verification).
- "Export PDF" and "Export CSV" produce valid downloadable files on web; share-sheet on mobile.
- `ai_specs/todo.md` reflects what shipped (web platform support no longer listed) and what's still deferred (rules harness, FCM web push, RTL audit, FCM bootstrap from prior plan).
- A demo PR exists showing a green CI run plus a release-drafter draft updated automatically.

</done_when>
