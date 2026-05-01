# CrewPoint — Deferred Features Backlog

Tracks ideas and partial implementations explicitly out of V1 scope. Promote into a spec when prioritized.

## Tasks
- Kanban board view (3 columns, drag-to-move) — alternative to current list view
- Task attachments file storage (model has `TaskAttachment`, no Drift/Storage wiring)
- Due-date reminders + push notifications
- Recurring tasks
- Task templates per event type

## Budget
- Multi-currency display with FX conversion
- Real settlement reconciliation (Plaid / Venmo webhook)
- Per-expense currency override (event-level currency only in V1)
- Expense categories + reporting
- CSV / PDF export
- Receipt OCR

## Chat
- Message reactions
- Message edit / delete-for-everyone
- Message search
- E2EE chat (noted in `firestore_chat_service.dart`)
- Typing indicators
- Read receipts

## Sync / Platform
- Full offline-first last-write-wins sync engine for events / tasks / expenses
- FCM web push (web platform support landed in `web-admin-reporting-spec.md`; FCM web push remains)
- Background message archival job
- Refactor `EventRepository` to Firestore-stream + Drift-mirror (currently Drift-only — write path doesn't reach Firestore for events)
- RTL audit on web (Material's NavigationRail handles RTL natively; verify the rest of the responsive shell + Budget / Tasks / Chat behave correctly under `Directionality.rtl`)
- White-label `authDomain` from `crewpoint-prod.firebaseapp.com` to `crewpoint.sookoon.space` (V2; OAuth popup currently shows the firebaseapp.com hostname — see `docs/web-hosting-guide.md` Stage 6 for the upgrade path)
- Real receipt thumbnails embedded in expense PDFs (the `receiptLoader` parameter is plumbed; `EventBudgetPage` just passes `null` today — wire an `http`-based loader when receipt embedding becomes a priority)

## Test Infrastructure
- ~~Firebase emulator harness (`functions/test/`) for Cloud Function integration tests + `firestore.rules` access-matrix tests~~ — **shipped** in `sookoon-security-privacy-audit-plan` Phase 1. `npm --prefix functions test` covers 15 rules tests + 40 CF integration tests via `@firebase/rules-unit-testing` + `firebase-functions-test` v3.
- BudgetRobot settle-via-Venmo journey test (Phase 5) — requires Riverpod overrides for `IUrlLauncher`, `AppLifecycleSource`, faked Firestore + fake auth, and stable per-payee settle-row keys
- ChatRobot urgent-message journey test (Phase 8) — requires faked `IFcmGateway` + `FcmHandler` invariants pumped through a two-session widget harness
- CI integration of `npm --prefix functions test` — currently a manual-run-only suite. Wire into GitHub Actions (or whichever CI ships first) so PRs that touch `firestore.rules` or `functions/src/` automatically gate on the emulator-driven test suite.
- `PrivacyDashboardRobot` + `AuthGateRobot` robot-class abstractions for the legal-surface flows. Equivalent coverage exists in widget tests (`privacy_dashboard_screen_test.dart`, `markdown_render_screen_test.dart`, `legal_footer_test.dart`); robot-class wrappers would be ergonomic sugar for cross-screen journeys when more legal-surface flows land.

## FCM bootstrap (Phase 8 → Phase 9 manual smoke)
- `main.dart`: register `FirebaseMessaging.onBackgroundMessage` (top-level fn with `@pragma('vm:entry-point')`)
- Subscribe `FirebaseMessaging.onMessage` and `onMessageOpenedApp` to `FcmHandler`
- Await `FirebaseMessaging.getInitialMessage()` before first router build (cold-start tap)
- Call `FcmService.attach(uid)` from the auth state listener; `detach(uid)` on sign-out
- Ship the foreground banner UI (`MaterialBanner` with View action that calls `context.go(deepLink)`)
- Pre-deploy: upload APNs key to Firebase console (iOS); verify "🚨 Urgent in {EventName}" push lands on a closed-app device

## Chat polish followups
- "Unknown member" coalescing for removed senders (currently shows UID label)

## Auth polish followups
- "Linked sign-in methods" UI under Profile — read-only V1 listing of attached providers (`AppUser.providerIds`) so users can see which sign-in methods own their account; V2 link/unlink actions. Phase 2/3 of `auth-google-mobile-fix-plan` left this for a separate spec.
- Explicit account-linking ceremony — when a user is OAuth-only and wants to add an email/password credential, offer an in-app flow (currently they have to use Forgot password as a side-channel). Tracked alongside the linked-methods UI.
- Hard-block the dashboard on `emailVerified` for password-only accounts? Currently the verification banner is non-blocking. Revisit if abuse / support-cost data warrants it.
- Switch web Apple sign-in to `signInWithRedirect()` for Safari users where third-party-cookie blocks break the popup flow.
- Audit prep: drop the deprecation warning on `fetchSignInMethodsForEmail` once Firebase ships a non-deprecated equivalent.
- Migrate strings in remaining features (dashboard, events, tasks, budget, chat, profile) to `context.strings.<feature>.*`. ~226 of the 276 `Text(...)` call sites in `lib/` remain after the auth-feature proving slice in `ui-polish-i18n-foundation-plan` Phase 3.
- Wire `flutter_localizations` + `gen-l10n` ARB pipeline. Add `lib/l10n/app_en.arb` mirroring the shape in `lib/app/core/i18n/app_strings.dart`; later add `app_es.arb`, `app_hi.arb`, `app_fr.arb`. Migration is one file: replace the body of `extension StringsX on BuildContext { ... }` in `app_strings.dart` with an `AppLocalizations` adapter. Zero UI call-site changes.
- Add a `MaterialApp.locale` switcher to Profile so QA can preview non-English locales without changing system settings.

## Security & privacy followups (post sookoon-security-privacy-audit)
- **DPDP Act (India) compliance clauses** — Hindi is on the localization roadmap; India-residency compliance is a separate spec. Likely additions: Indian data principal definitions, grievance officer contact, consent-manager integration, breach-notification timeline.
- **E2EE chat** — `firestore_chat_service.dart` documents this gap. Privacy Policy explicitly states V1 messaging is not E2EE. Separate large spec when prioritized.
- **Automated retention purge** for anonymized records — V1 is on-request manual via support. Revisit if compliance posture demands automation (scheduled CF that purges anonymized records past N years from account deletion).
- **Per-uid rate limiting** for callable Cloud Functions — Firebase's default per-project quotas stand for V1. Revisit `joinEvent` and `generateInviteCode` if abuse data warrants per-uid quotas (App Check + Firestore counter pattern).
- **Audit-trail logging** for membership changes (`promoteToAdmin`, `demoteAdmin`, `removeEventMember`). Currently only written to Cloud Logging. A dedicated Firestore `events/{eventId}/audit/{timestamp}` collection is a separate spec.
- **Write-shape allow-listing** on `events`, `tasks`, `expenses` create + update rules. Per-feature schema audit required so backward-compat client writes don't break — flagged as out-of-scope in `docs/security/firestore-rules-audit.md`.
- **`anonymizeUserInEvent` streaming refactor** — `functions/src/account/deleteUserAccount.ts` keeps the anonymize path as upfront fetch because per-user-per-event docs are bounded by user activity. Revisit if a user with thousands of messages in a single event surfaces.
