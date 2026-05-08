# V1 Progress Audit

Source spec: [`ai_specs/v1-audit-and-create-event-fix-spec.md`](../ai_specs/v1-audit-and-create-event-fix-spec.md) (commit `9f93273`).

Architecture in force: **Firestore-Write / Drift-Read** — writes go to Firestore (its SDK queues offline), per-repository listeners mirror snapshots into Drift on mobile/desktop, UI reads from Drift (web reads directly from the Firestore stream).

Severity legend: **must-ship** = launch blocker; **should-ship** = ship if cheap, defer if not; **nice-to-have** = post-launch.

---

## Pillar 1 — Offline-First Foundation

**V1 intent:** App loads instantly with no network; writes queue offline and replay on reconnect.

**Done**

- Drift 2.25 wired with conditional `dart:io` / Wasm imports — `lib/app/core/database/app_database.dart`, `lib/app/core/database/connection/native.dart`, `lib/app/core/database/connection/web.dart`.
- Drift schema covers all V1 entities: `Users`, `Events`, `Tasks`, `TaskChecklistItems`, `ChatMessages`, `Expenses`, `ExpenseSplits` — `lib/app/core/database/app_database.dart:6-118`. Schema version 4 with cumulative migrations (`lib/app/core/database/app_database.dart:135-150`).
- DAOs registered: `EventsDao`, `TasksDao`, `TaskChecklistItemsDao`, `ChatMessagesDao`, `ExpensesDao`, `ExpenseSplitsDao`, `UsersDao` — all under `lib/app/core/database/daos/`.
- Per-repository Firestore listener + Drift mirror lifecycle implemented for tasks (`lib/app/features/tasks/data/task_repository.dart:17-117`), expenses (`lib/app/features/budget/data/expense_repository.dart:16-85`), and chat (`lib/app/features/chat/data/chat_repository.dart`). Each registers in `lib/app/core/providers.dart:108-185`.
- Firestore SDK offline persistence is **enabled by default on iOS/Android** (cloud_firestore ≥ 3.x default). No explicit opt-out present.

**Missing / stubbed**

- **Firestore offline persistence on WEB is not enabled.** `lib/app/core/services/firebase_service.dart:9-17` calls only `Firebase.initializeApp(options: options)` — no `FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true)` and no `enableIndexedDbPersistence()` call. Grep across `lib/` for `persistenceEnabled` / `enableIndexedDbPersistence` / `firestoreSettings` returned zero matches. Web builds will lose all queued writes and cached reads on tab close. **must-ship.**
- **`EventRepository` is the odd one out** — `lib/app/features/dashboard/data/event_repository.dart` is Drift-only, no Firestore wiring. Tracked in spec Stage 2. **must-ship.**
- **Dashboard never re-renders from data** — `lib/app/features/dashboard/presentation/dashboard_screen.dart:19` hardcodes `final events = <EventModel>[];` with `// TODO: Wire to event provider...`. **must-ship.**
- **`SyncEngine` is dead code.** `lib/app/core/services/sync_engine.dart` and `lib/app/core/services/i_sync_service.dart` are registered in no provider, called from nowhere. Only external reference is a stale unit test (`test/app/features/profile/profile_test.dart:8`) that exercises the dead implementation. **Recommend deletion** of all three — the architecture moved on to per-repository mirrors. **must-ship cleanup** (low risk).

**Severity:** must-ship.

---

## Pillar 2 — Unified Event Hub

**V1 intent:** Single event surface aggregating Tasks (Kanban/list), Chat (with urgent-bypass-mute), and Budget (greedy settlement).

**Done**

- **Tasks**: list + detail + create flows — `lib/app/features/tasks/presentation/`. Repository with Firestore + Drift mirror — `lib/app/features/tasks/data/task_repository.dart`. Markaround-complete via Cloud Function — `functions/src/events/markTaskComplete.ts`.
- **Chat**: real-time messaging via Firestore streams — `lib/app/features/chat/data/firestore_chat_service.dart`. Drift-mirroring repository — `lib/app/features/chat/data/chat_repository.dart`. Message bubble UI — `lib/app/features/chat/presentation/widgets/message_bubble.dart`.
- **Urgent FCM bypass**: producer at `lib/app/features/chat/data/firestore_chat_service.dart:37-45` writes `isHighPriority: true` on the message doc. Consumer at `functions/src/events/onUrgentMessageCreated.ts:22-138` triggers on document create, fans out to recipient FCM tokens (batched 500), prunes dead tokens, deep-links to `/dashboard/event/{id}/chat`. Tested at `functions/test/cloud-functions.test.ts`.
- **Budget greedy settlement**: `lib/app/features/budget/domain/models/balance_ledger.dart:23-134` — `BalanceLedger.calculate(...)` builds net balances; `_simplifyDebts(...)` runs the greedy "match largest creditor with largest debtor" loop. Tested at `test/app/features/budget/balance_ledger_test.dart`.
- **Expenses**: full create/list/detail with receipts — `lib/app/features/budget/presentation/`, repository + mirror at `lib/app/features/budget/data/expense_repository.dart`.

**Missing / stubbed**

- **`CreateTaskScreen` silent-no-op** — same root-cause bug as `CreateEventScreen`: `lib/app/features/tasks/presentation/create_task_screen.dart:73` calls `widget.onSubmit?.call(task)` with no production caller. **must-ship.**
- **`JoinEventSheet`** — has the same `onSubmit?` callback pattern; verify whether the production widget tree threads a handler. Spec flags as launch blocker if unfixed. **must-ship** (verify).
- **Task Kanban view** — only list-style is present (`task_list_screen.dart`); no Kanban board widget. Spec mentions "basic Kanban or list-style" so list-only satisfies V1 intent. **nice-to-have** for V1.x.

**Severity:** must-ship (silent-no-op fixes).

---

## Pillar 3 — Zero-Liability Settlements

**V1 intent:** Generate pre-filled deep links to Venmo/CashApp/Zelle so users settle out-of-band; receipts upload to Storage with silent compression.

**Done**

- **Venmo deep links + HTTPS fallback** — `lib/app/features/budget/data/pay_link_builder.dart:25-61`. `venmo://paycharge?...` scheme + `https://venmo.com/{handle}?...` fallback. Handle validation via regex `^[A-Za-z0-9_-]{1,30}$`; note truncation at 60 chars; amount formatting at 2 dp. Tested at `test/app/features/budget/pay_link_builder_test.dart`.
- **CashApp universal link** — `lib/app/features/budget/data/pay_link_builder.dart:64-71`. `https://cash.app/${handle}/${amount}`.
- **Settlement UI** — `lib/app/features/budget/presentation/widgets/settle_sheet.dart` wires the link builders + `urlLauncherProvider`.
- **Pending settlement notifier + dispute flow** — `lib/app/features/budget/application/pending_settlement_notifier.dart` + `functions/src/events/disputeSettlement.ts`.
- **Receipt picker + silent compression** — `lib/app/core/services/firebase_image_service.dart:46-89`. `image_picker` invoked with `maxWidth: 512`, `maxHeight: 512`, `quality: 85` defaults — that IS the silent compression path. Bytes-based upload via `_storage.ref().child(path).putData(bytes, ...)` works on web + native via the same code path.
- **Receipt storage path** — `firebase_image_service.dart:91-110` uploads to `FirebaseStorage.instance.ref().child(storagePath)`; expense flow at `lib/app/features/budget/data/expense_repository.dart` consumes it.

**Missing / stubbed**

- **Zelle deep links are NOT implemented.** `pay_link_builder.dart` covers Venmo + CashApp only. Spec lists Zelle as a V1 target. Note: Zelle has no public deep-link scheme — typical workaround is a web-banking redirect with the recipient's email/phone, or just copy-to-clipboard with instructions. **should-ship** (decide UX path before launch).
- **No payment-handle picker on first-tap UX** verified — confirm during user testing that the `paymentHandle` / `venmoHandle` / `cashappHandle` fields on `Users` (Drift schema lines 12-14) are reachable from profile editing. Cited; not deeply audited here.

**Severity:** should-ship (Zelle decision + verify handle entry).

---

## Pillar 4 — Professional Web Parity

**V1 intent:** Fully responsive web dashboard at `crewpoint.sookoon.space`; client-side CSV/PDF exports.

**Done**

- **Responsive shell** — `lib/app/core/widgets/responsive_shell.dart` switches between rail (≥840) and bottom nav (<840). Breakpoints centralised at `lib/app/core/constants/breakpoints.dart`.
- **ContentMaxWidth clamping** — `lib/app/core/widgets/content_max_width.dart` + `lib/app/core/widgets/form_card_shell.dart`. Applied to dashboard (720), forms (480), detail (960), chat bubble (540).
- **Web hosting target** — `crewpoint-prod` and `crewpoint-dev` Firebase Hosting sites configured in `firebase.json`. Setup guide at `docs/crewpoint-web-app-setup-guide.md`.
- **PDF + CSV exports**:
  - Expense PDF — `lib/app/features/budget/data/expense_pdf_builder.dart` + tests at `test/app/features/budget/expense_pdf_builder_test.dart`.
  - Expense CSV (RFC-4180) — `lib/app/features/budget/data/expense_csv_builder.dart` + tests at `test/app/features/budget/expense_csv_builder_test.dart`.
  - Task PDF — `lib/app/features/tasks/data/task_pdf_builder.dart` + tests at `test/app/features/tasks/task_pdf_builder_test.dart`.
  - Platform-aware exporter seam — `lib/app/core/services/file_export_service.dart` + `_native.dart` / `_web.dart` (web uses Wasm-safe `package:web` Blob + anchor; native uses `Printing.sharePdf` / `share_plus`). Tests at `test/journeys/export_journey_test.dart`.
- **Apple `.well-known` association file** — `web/.well-known/apple-developer-domain-association.txt`.
- **Branded favicon + manifest** — `web/favicon.png`, `web/manifest.json`.
- **Privacy + Terms hosted HTML** — `web/legal/privacy.html`, `web/legal/terms.html`, generated by `scripts/build_legal_html.dart`.

**Missing / stubbed**

- **Drift on web is in-memory Wasm** — confirmed by comment at `lib/app/core/providers.dart:76-79`. Web reads from the Firestore stream directly; cold-start UX has no Drift cache to hydrate. Acceptable per spec; flag if any V1 feature depends on it. **nice-to-have** to revisit (OPFS persistence for Drift on web is a V1.x enhancement).
- **Custom domain DNS** — setup guide exists (`docs/crewpoint-web-app-setup-guide.md`) but the Namecheap DNS records and Firebase domain verification have not been audited as live. Out-of-scope for code audit; flag for launch checklist.

**Severity:** must-ship (the code surface is complete; remaining work is launch operations).

---

## Pillar 5 — Minimum Viable Data Security

**V1 intent:** Auto-create Firestore user docs on auth; ironclad account deletion (wipe solitary events, anonymise shared records, drop the auth user).

**Done**

- **Auto user-doc creation** — `lib/app/features/auth/application/auth_provider.dart:80-109` (`AuthNotifier._ensureUserDoc`). Fires on every authenticated emission, calls `userRepository.createUserIfNotExists(uid, email, displayName, photoUrl, providerIds)`. Failures logged + swallowed so auth state never blocks on transient Firestore errors.
- **Display-name derivation** — `lib/app/features/auth/domain/display_name_helper.dart` derives a name from email when none provided.
- **Firestore user-doc projection split** — public `users/{uid}` for display fields, `users/{uid}/private/profile` for PII (email, providerIds, fcmTokens, preferences). Enforced by `firestore.rules:135-143`. Implementation at `lib/app/features/profile/data/firestore_user_repository.dart`.
- **Account deletion Cloud Function** — `functions/src/account/deleteUserAccount.ts:193-334`. Three stages, structured logging, typed `HttpsError` on failure:
  - Stage 1 (Firestore): query `events.where('memberIds', array-contains, uid)`; for each event, `memberIds.length <= 1` → `deleteEventCompletely` (paged streaming-delete of `messages`/`expenses`/`tasks` subcollections via `streamDeleteSubcollection`); else → `anonymizeUserInEvent` (transfer `creatorId` to first remaining admin/member; `arrayRemove(uid)` from `memberIds`/`adminIds`; rewrite `senderId`/`payerId` → `'deleted_user'`; null out `assigneeId`). Then delete `users/{uid}/private/profile` and `users/{uid}`.
  - Stage 2 (Storage): `bucket.getFiles({prefix: 'users/${uid}/'})` + bulk delete. Non-fatal — logs and continues.
  - Stage 3 (Auth): `admin.auth().deleteUser(uid)` with bounded retry (3 attempts × 250 ms backoff).
  - Tested at `functions/test/account/deleteUserAccount.test.ts`.
- **Client-side delete flow** — `lib/app/core/services/account_deletion_service.dart` maps typed `FirebaseFunctions` exceptions to user-readable copy. Dialog at `lib/app/features/profile/presentation/widgets/delete_account_dialog.dart` with retry-friendly UX.
- **Firestore rules with field-level guards** — `firestore.rules:22-33` blocks client writes to `memberIds`/`adminIds`/`creatorId`; gatekeeping enforced via Cloud Functions only.
- **Cloud Function CF-hardening pass** — `docs/security/cloud-functions-audit.md` + `firestore.rules` Fixes 1.A–1.D.
- **Privacy Policy + Terms** — drafts at `assets/legal/privacy-policy.md`, `assets/legal/terms-of-service.md`; hosted HTML at `web/legal/`. Linked from auth gate, profile, privacy dashboard.

**Missing / stubbed**

- **Pre-launch checklist** — `docs/security/pre-launch-checklist.md` exists; not all line items have been ticked off (review separately before public launch).
- No outstanding code-level gaps in this pillar.

**Severity:** must-ship (code complete; verify ops).

---

## Recommended deletions (dead code)

- `lib/app/core/services/sync_engine.dart` — stub; not registered as a provider; not called.
- `lib/app/core/services/i_sync_service.dart` — interface for the stub above; no other implementers.
- `test/app/features/profile/profile_test.dart` — only references SyncEngine; remove together.

The architecture moved to per-repository Firestore listeners + Drift mirrors. Keeping the stub around invites the next contributor to "finish the SyncEngine" and re-introduces a parallel architecture.

---

## V1 launch blockers

1. **`CreateEventScreen` silent no-op** — `lib/app/features/dashboard/presentation/create_event_screen.dart:64-82` calls `widget.onSubmit?.call(event)` with no production caller. Tracked in spec Stage 2. *Pillar 2.*
2. **`DashboardScreen` hardcoded empty list** — `lib/app/features/dashboard/presentation/dashboard_screen.dart:19`. Even if create persists, the dashboard will not show it. Tracked in spec Stage 2. *Pillar 2.*
3. **`CreateTaskScreen` silent no-op** — `lib/app/features/tasks/presentation/create_task_screen.dart:73`, identical pattern. Needs a separate fix spec. *Pillar 2.*
4. **`JoinEventSheet` callback wiring** — verify production wiring; if absent, same root cause. *Pillar 2.*
5. **`MemberManagementScreen` placeholder uid** — `lib/app/core/router/app_router.dart:158` passes `currentUserId: ''`. Tracked in spec Stage 2 via `currentUserIdProvider`. *Pillar 5 trust integrity.*
6. **Firestore offline persistence on web is not enabled** — `lib/app/core/services/firebase_service.dart`. Without `Settings(persistenceEnabled: true)` (or `enableIndexedDbPersistence`), the offline-first pillar is broken on web — every reload re-fetches and offline writes are lost. *Pillar 1.*
7. **Zelle settlement UX decision pending** — `pay_link_builder.dart` covers only Venmo + CashApp. Either implement a Zelle web-banking fallback or carve Zelle out of V1 scope. *Pillar 3.*
8. **`SyncEngine` + `i_sync_service` deletion** — low risk, high signal. Removes architectural ambiguity for the next contributor. *Pillar 1 cleanup.*

---

## V1.x follow-ups

- **OPFS or IndexedDB persistence for Drift on web** — currently Wasm-in-memory; cold-start has no local cache.
- **Task Kanban view** — list-only ships V1; column board is a should-ship for V1.x.
- **Listener-fan-out cost monitoring** — `events.where('memberIds', arrayContains: uid)` returns every event the user belongs to. Acceptable for V1; revisit if read costs spike.
- **Custom-domain DNS verification** — operationalise `docs/crewpoint-web-app-setup-guide.md` line items.
- **Pre-launch security checklist** — walk every line of `docs/security/pre-launch-checklist.md` before public.
- **CreateEvent / CreateTask submission patterns** — once `CreateEventScreen` is fixed, codify the loading/error/SnackBar pattern as a shared `FormSubmissionController` so future forms don't repeat the silent-no-op trap.

---

## Event Lifecycle Deep Dive

> Deepens **Pillar 2 — Unified Event Hub** above. Walks each step a user can take with an event, from creation through deletion, with the surface that backs it and any remaining gap. Single source of truth for "what works on events today."

| # | Step | Status | File refs | Follow-up |
| --- | --- | --- | --- | --- |
| 1 | **Create event** | ✅ Done | `lib/app/features/dashboard/presentation/create_event_screen.dart` (Riverpod-aware, captures messenger before pop, inline error); `lib/app/features/dashboard/data/event_repository.dart` (Firestore write + Drift mirror); `test/app/features/dashboard/create_event_screen_test.dart` (happy/failure/loading/sign-out); `test/journeys/create_event_journey_test.dart` (full slice). Shipped in PR #3. | none |
| 2 | **View list** | ✅ Done | `lib/app/features/dashboard/presentation/dashboard_screen.dart` (consumes `dashboardEventsProvider` via `AsyncValue.when`); `dashboard.events.list` key. Shipped in PR #3. | none |
| 3 | **Open detail (tap tile)** | 🔄 Resolved in this PR | `lib/app/core/widgets/event_guard.dart` (resolve-by-ID + 750ms grace); `lib/app/core/router/app_router.dart` (`_resolveEventId` helper + 6 route rewrites); `test/app/core/widgets/event_guard_test.dart` (9 tests including dispose-cancels-timer contract); parameterized router test in `test/app/core/router/app_router_test.dart`; journey extension in `test/journeys/create_event_journey_test.dart`. | none |
| 4 | **Edit event info (title / description / dates / type)** | ❌ Missing | `event_dashboard_screen.dart` settings `IconButton` has empty `onPressed`. No `EditEventScreen`. | `event-edit-screen-spec.md` (V1.x). Currency stays immutable. |
| 5 | **Members — view / promote / demote / remove** | ✅ Done | UI: `lib/app/features/dashboard/presentation/member_management_screen.dart`. Cloud Functions: `functions/src/events/promoteToAdmin.ts`, `demoteAdmin.ts`, `removeEventMember.ts`. Auth-rules guard at `firestore.rules:22-33`. uid threading wired in `app_router.dart:155-162`. | none (verify CFs end-to-end during manual smoke) |
| 6 | **Members — invite / join via code** | ✅ Done | `lib/app/features/dashboard/presentation/widgets/join_event_sheet.dart` (6-char code input, typed FCF errors); `functions/src/events/joinEvent.ts`, `generateInviteCode.ts`. | none (verify end-to-end during manual smoke) |
| 7 | **Tasks (within event)** | ⚠️ Wired-but-broken | List + detail render: `lib/app/features/tasks/presentation/event_tasks_page.dart`, `event_task_detail_page.dart`. **`CreateTaskScreen` has the same silent-no-op pattern that this PR closes for events** (`lib/app/features/tasks/presentation/create_task_screen.dart:73`). Mark-complete CF: `functions/src/events/markTaskComplete.ts`. | Same fix pattern as Stage 2 of the V1 audit + create-event fix; tracked in V1 launch blockers list above. |
| 8 | **Chat (within event)** | ✅ Done | `lib/app/features/chat/data/firestore_chat_service.dart` (write path); `lib/app/features/chat/presentation/event_chat_page.dart` (UI); urgent-message FCM at `functions/src/events/onUrgentMessageCreated.ts`. | none |
| 9 | **Budget (within event)** | ⚠️ Wired-but-broken | Repository + UI: `lib/app/features/budget/`. Greedy settlement: `balance_ledger.dart`. Pay-link: `pay_link_builder.dart` covers Venmo + CashApp; **Zelle missing**. | `event-zelle-uxnavigation-spec.md` or scope-cut decision. Tracked in V1 launch blockers. |
| 10 | **Archive event** | ⚠️ Wired-but-broken | UI toggle exists in `event_dashboard_screen.dart` `_EventActions`; `onChanged` body is `// TODO: Update event status via Firestore`. The switch flips visually but nothing persists. | `event-archive-toggle-spec.md` (V1 should-ship). |
| 11 | **Leave event (non-owner)** | 🔄 Resolved in this PR | `event_dashboard_screen.dart` `_EventActions._leaveEvent` calls `removeEventMember` CF. Now wraps in a `Consumer` reading `currentUserIdProvider` so `event.isOwner(uid)` / `isAdmin(uid)` branches evaluate correctly. Tested in `test/app/features/dashboard/event_actions_uid_wrap_test.dart`. | none |
| 12 | **Delete event (owner only)** | 🔄 Resolved in this PR | `event_dashboard_screen.dart` `_EventActions._deleteEvent` two-step confirm → `deleteEvent` CF. The CF call already worked for the owner; this PR fixes the visibility branch via the uid Consumer wrap. CF: `functions/src/events/deleteEvent.ts`. | none |

### Cross-references to the V1 audit above

- **Pillar 2 — Unified Event Hub** row already names the silent-no-op pattern as a launch blocker; rows 3 + 11 + 12 in the matrix here are the events-specific resolution. The CreateTaskScreen blocker (row 7) remains open.
- **Pillar 3 — Zero-Liability Settlements** row already flags the Zelle gap (row 9 here).
- **Pillar 5 — Minimum Viable Data Security** row covers the underlying Firestore rules + delete CF that rows 5, 6, 12 lean on.

### Follow-up specs (from this section)

1. `event-archive-toggle-spec.md` — persist `status` to Firestore from the archive switch via a new `EventRepository.archiveEvent(eventId, archived)` method (admins/creator only per `firestore.rules:28-33`). **V1 should-ship.**
2. `event-edit-screen-spec.md` — `EditEventScreen` for title / description / eventType / startDate / endDate. Currency stays immutable. **V1.x follow-up.**

The `event-actions-uid-wiring-spec.md` follow-up that earlier audit drafts named is **dropped** — Phase 1 of the navigation-fix PR resolved it inline (rows 11 + 12 above).

---

*Section appended as Phase 2 of the event-navigation-fix work (PR following PR #3). The original V1 audit was generated as Phase 1 of the V1-audit + create-event-fix work; PR #3 implemented blockers 1, 2, and 5 from that audit. Web Firestore offline persistence (blocker 6) and Zelle (blocker 7) still need separate small specs before public launch.*
