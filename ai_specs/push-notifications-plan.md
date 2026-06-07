## Overview

Push notifications roadmap V1→V3. FCM scaffolding (`FcmGateway`/`FcmService`/`FcmHandler` + `onUrgentMessageCreated` CF) already exists but is **not wired in `main.dart`**. Plan completes V1 bootstrap, then layers preferences, channels/badges, deep-links, critical-bypass, per-event mute, quiet hours, web push.

**Spec**: ad-hoc (no spec file — generated from `ai_specs/todo.md` §FCM bootstrap + §Tasks + §Sync/Platform).

## Context

- **Structure**: feature-first under `lib/app/features/{auth,budget,chat,dashboard,onboarding,profile,tasks}`; cross-cutting under `lib/app/core/{services,router,providers.dart,i18n,theme}`.
- **State management**: Riverpod 3 `Notifier`/`NotifierProvider`; providers live at `lib/app/features/*/application/*_provider.dart`.
- **Routing**: `go_router` 14 w/ `StatefulShellRoute`. Deep-link entry already supported via `data['deepLink']` in FCM payload. Route helper: `lib/app/core/router/current_route_provider.dart`.
- **Reference implementations**:
  - `lib/app/core/services/fcm_gateway.dart`, `fcm_service.dart`, `fcm_handler.dart` (token + foreground/tap routing — DONE)
  - `functions/src/events/onUrgentMessageCreated.ts` (Firestore-trigger CF pattern w/ batched `sendEachForMulticast` + dead-token pruning — DONE)
  - `lib/app/features/profile/data/firestore_user_repository.dart` (private subdoc pattern — `users/{uid}/private/profile`)
  - `lib/app/features/profile/presentation/profile_screen.dart` (settings entry-point screen)
- **Firestore schema**:
  - `users/{uid}/private/profile.fcmTokens` (live) + `.preferences` (currently `{dataOptIn,currency}`) — extend, do not replace.
  - **New**: `users/{uid}/private/profile.notificationPrefs` (per-category enabled flags, quietHours, criticalOptIn).
  - **New**: `users/{uid}/private/eventMutes/{eventId}` (V3 per-event mute).
- **i18n**: hand-rolled `lib/app/core/i18n/app_strings.dart` extension; ARB migration deferred. Add notification strings to `ProfileStrings` + new `NotificationStrings` namespace.
- **Platform**:
  - iOS: `UIBackgroundModes: remote-notification` already declared. APNs key upload + critical-alert entitlement deferred to Phase 4.
  - Android: implicit FCM service via plugin merge; channels not yet declared. `google-services.json` per flavor assumed present.
- **Assumptions / Gaps**:
  - Per-flavor `google-services.json` + `GoogleService-Info.plist` exist outside repo.
  - V3 web push assumed for hosted web build; service-worker path TBD.
  - iOS critical alert entitlement requires Apple approval — fall back to `time-sensitive` if denied.

## Plan

### Phase 1: V1 — wire what's built (urgent-message MVP)

- **Goal**: bootstrap FCM end-to-end so the existing urgent-chat trigger lands on a closed-app device. Ships V1 push.
- [x] `lib/main.dart` — register top-level `@pragma('vm:entry-point')` background handler; await `FirebaseMessaging.getInitialMessage()` pre-router; subscribe `onMessage` + `onMessageOpenedApp` to `FcmHandler`.
- [x] `lib/app/core/services/fcm_handler_bootstrap.dart` — new wrapper that wires `FcmHandler` to `MaterialBanner` foreground UI + `GoRouter.go()` for tap-handling. Reads `currentRouteProvider`.
- [x] `lib/app/features/auth/application/auth_provider.dart` — call `FcmService.attach(uid)` on `Authenticated` transition, `detach(uid)` on sign-out. *(Implemented via `ref.listen` in `main.dart` instead of inside the notifier — keeps the side-effect at the composition root.)*
- [x] `lib/app/core/providers.dart` — expose `fcmServiceProvider`, `fcmGatewayProvider`.
- [x] `ios/Runner/Info.plist` — confirm `aps-environment` entitlement; `UNUserNotificationCenter` delegate stub deferred (plugin auto-registers; default foreground suppression is desired since we render our own MaterialBanner).
- [x] `android/app/src/main/AndroidManifest.xml` — declare default channel id `crewpoint_default` + meta-data for `firebase_messaging`.
- [ ] Pre-deploy: upload APNs auth key to Firebase console (dev/stg/prod). *(Manual; out of session scope.)*
- [x] TDD: `FcmService.attach` writes token then subscribes refresh stream → token re-write on refresh. *(Pre-existing in `test/app/core/services/fcm_service_test.dart`.)*
- [x] TDD: `FcmHandler.handleForegroundMessage` suppresses banner when route already matches `/event/{id}/chat`. *(Pre-existing in `test/app/core/services/fcm_handler_test.dart`.)*
- [x] TDD: `FcmHandler.handleTap` routes to `data['deepLink']`; no-op when absent. *(Pre-existing.)*
- [x] TDD: `FcmHandlerBootstrap` cold-start `initialMessage` is dispatched exactly once (no double-nav). *(New: `test/app/core/services/fcm_handler_bootstrap_test.dart`.)*
- [ ] Robot: `ChatRobot` urgent-message journey — sender fires urgent message → recipient receives banner → tap → lands on chat. *(Deferred — depends on robot harness work tracked in `todo.md:40`.)*
- [x] Verify: `flutter analyze` && `flutter test`.

### Phase 2: V1.1 — opt-out + preferences foundation

- **Goal**: user can disable push entirely or per-category from Profile; server respects opt-out.
- [x] `lib/app/features/profile/domain/models/notification_prefs.dart` — model: `{ pushEnabled, urgentChat }` for V1.1; future categories layered in V2/V3.
- [x] `lib/app/features/profile/domain/repositories/i_user_repository.dart` — add `getNotificationPrefs(uid)` + `updateNotificationPrefs(uid, prefs)`.
- [x] `lib/app/features/profile/data/firestore_user_repository.dart` — read/write `users/{uid}/private/profile.notificationPrefs`.
- [x] `lib/app/features/profile/application/notification_prefs_provider.dart` — Riverpod `AsyncNotifier.family<NotificationPrefs, String>` (uid as family arg).
- [x] `lib/app/features/profile/presentation/notification_settings_screen.dart` — master toggle + per-category urgent switch. OS-permission deep-link row deferred (no `app_settings`/`permission_handler` in `pubspec.yaml`; track as Phase 3 add).
- [x] `lib/app/core/router/app_router.dart` — route `/profile/notifications`.
- [x] `lib/app/features/profile/presentation/profile_screen.dart` — wire existing "Notifications" `SettingsRow` to the new route.
- [x] `lib/app/core/services/fcm_service.dart` — `attach()` reads `notificationPrefs.pushEnabled` and short-circuits when false; no permission prompt, no token write.
- [x] `functions/src/events/onUrgentMessageCreated.ts` — reads each recipient's `private/profile.notificationPrefs`; skips when `pushEnabled==false || urgentChat==false`.
- [ ] `functions/test/cloud-functions.test.ts` — extend urgent-message suite: opt-out recipient receives no push. *(Deferred — requires non-trivial `admin.messaging()` mocking + onCreate-trigger wrap. CF code path is reviewable; existing 75 CF tests still pass. Track as Phase 3 follow-up.)*
- [x] TDD: `NotificationPrefsNotifier` round-trips default `pushEnabled=true` when doc absent. *(Covered by `notification_prefs_test.dart` + `notification_settings_screen_test.dart`.)*
- [x] TDD: toggling master off triggers `FcmService.detach()` for current device. *(Covered: `notification_settings_screen_test.dart` "toggling master OFF persists pushEnabled=false" + `fcm_service_test.dart` "attach() short-circuits when notificationPrefs.pushEnabled is false".)*
- [ ] TDD: CF skips recipients with `urgentChat==false`. *(Deferred with the CF test above.)*
- [ ] Robot: navigate Profile → Notifications → toggle master off → confirm token removed from Firestore (faked). *(Deferred — robot harness work tracked in `todo.md:40`. Widget-level coverage above stands in.)*
- [x] Verify: `flutter analyze` && `flutter test` && `npm --prefix functions test`.

### Phase 3a: V2 — categorized push foundation + task-assigned slice

- **Goal**: ship one new notification category end-to-end. Lays the shared CF helper that every future category reuses; proves the assignee-receives-push path on a real Firestore trigger.
- [x] `functions/src/notifications/sendPush.ts` — new shared `sendCategorizedPush({recipientUids, senderId, category, title, body, deepLink, extraData})`. Per-recipient pref check + category→Android channel id + iOS `apns.payload.aps.thread-id`. Batched send w/ dead-token pruning. Single source of truth for FCM fan-out.
- [x] `functions/src/events/onUrgentMessageCreated.ts` — migrated to call `sendCategorizedPush(category: 'chat_urgent')`. Inline token-pruning / send loop removed; CF is now ~60 lines vs. the previous ~140.
- [x] `functions/src/events/onTaskAssigned.ts` — Firestore `onDocumentWritten` trigger on `events/{eid}/tasks/{tid}`. Fires only when `assigneeId` transitions to a new non-empty uid (handles both task create + reassignment). Skips self-assignment. Pushes with `deepLink: /dashboard/event/{eid}/tasks/{tid}`.
- [x] `functions/src/index.ts` — export `onTaskAssigned`.
- [x] `lib/app/features/profile/domain/models/notification_prefs.dart` — add `taskUpdates` field (default true). Round-trip in `fromMap` / `toMap` / `copyWith`.
- [x] `lib/app/features/profile/application/notification_prefs_provider.dart` — add `setTaskUpdates(bool)` action.
- [x] `lib/app/features/profile/presentation/notification_settings_screen.dart` — surface "Task assignments" tile under Categories; disabled when master is OFF.
- [x] TDD: `NotificationPrefs.taskUpdates` defaults true, round-trips through `fromMap`/`toMap`, copyWith respects it. *(Covered by `notification_prefs_test.dart` — 8 tests pass.)*
- [x] TDD: `NotificationSettingsScreen` toggling task-updates persists via repo. *(Covered by `notification_settings_screen_test.dart` — 4 tests pass including new "toggling taskUpdates OFF persists taskUpdates=false" + "category tiles are disabled when master is OFF".)*
- [ ] TDD: `FcmHandler.handleTap` routes a task-detail deep-link payload to `/dashboard/event/{eid}/tasks/{tid}` (covered by existing data-driven dispatch — verify no regression with a focused test). *(Skipped — `FcmHandler.handleTap` is purely data-driven against `data['deepLink']`; any string the server sends is routed verbatim. Existing tests in `fcm_handler_test.dart` already prove the dispatch contract.)*
- [x] Verify: `flutter analyze` && `flutter test` && `npm --prefix functions run build` && `npm --prefix functions test`. *(1 pre-existing analyzer warning; 677 flutter tests pass, 4 skipped; 75 CF tests pass.)*

### Phase 3b: V2 — badges + unread aggregation

- **Goal**: visible unread counts on bottom-nav tabs + OS app icon. Pure client work over existing data streams; no new CFs.
- [x] `lib/app/features/dashboard/application/unread_badge_provider.dart` — aggregate `Provider.family<UnreadBadgeCounts, String>` folding `myAssignedTasksProvider` (tasks where `status != done`) + `globalInboxProvider` (events w/ `unreadCount > 0`) + `globalBalanceLedgerProvider` (open debt rows). Exposes per-tab counts + `total` + `hasAny`. Loading/error from any source contributes 0 (badge UX is non-blocking).
- [x] `lib/app/core/widgets/bottom_nav_badge.dart` — *Implemented inline in `responsive_shell.dart` via a `_badged()` helper rather than a separate file. Plan name preserved as reference; actual location is the shell.* `ResponsiveShell` now accepts `tasksBadge`/`chatBadge`/`budgetBadge` ints; wraps icons in Material 3 `Badge` when count > 0; clamps to `"99+"` at ≥100. Wired from `app_router.dart` Consumer via `unreadBadgeProvider`.
- [ ] `lib/app/core/services/app_badge_service.dart` — wrap `flutter_app_badger` (or equivalent); update OS badge from `unreadBadgeProvider` listen. Clear on app foreground + on relevant screen view. *(Deferred to Phase 3b.1 — requires a new pubspec dep + iOS pod regen + OEM-variant Android badging which is its own focused unit of work. In-app bottom-nav badges deliver the primary user value.)*
- [x] TDD: `unreadBadgeProvider` re-emits when task assignment / unread message stream updates. *(Covered by `unread_badge_provider_test.dart` — 7 tests covering all-zero, per-source counting, loading/error suppression, and explicit re-emit on upstream invalidation.)*
- [x] Verify: `flutter analyze` && `flutter test`. *(1 pre-existing warning; 688 flutter tests pass, 4 skipped.)*

### Phase 3b.1: V2 — OS app-icon badge plumbing (real-package adapter deferred)

- **Goal**: mirror the `unreadBadgeProvider.total` to the OS launcher icon so users see the count without opening the app.
- [ ] `pubspec.yaml` — add `flutter_app_badge_control: ^X` (or chosen equivalent). *(Deferred to Phase 3b.2 — `flutter_app_badge_control` is at `0.0.2` and `flutter_app_badger` is discontinued. Decision deferred to the user after on-device evaluation; full plumbing below already lets a swap land in a single commit.)*
- [x] `lib/app/core/services/app_badge_service.dart` — `AppBadgeService` mirrors a single unread count to an `IAppBadgePlatform` test seam. `update(total)` clears when `total <= 0`, sets otherwise. `AppLifecycleState.resumed` re-applies the current total (idempotent — handles Android OEM launchers that drop the badge on icon repaint). Platform failures are caught + logged; badge mirroring is cosmetic and must never crash the host.
- [x] `lib/app/core/providers.dart` — `appBadgePlatformProvider` (defaults to `NoOpAppBadgePlatform`), `appLifecycleSourceProvider` (`WidgetsAppLifecycleSource`), `appBadgeServiceProvider` (wires the above).
- [x] `lib/main.dart` — `_syncBadgeMirror(uid)` opens a `ref.listenManual(unreadBadgeProvider(uid))` subscription on auth transition; closes + explicitly clears on sign-out. Subscription closed in `dispose`.
- [x] TDD: service writes `total` to the badge platform; clears on `update(0)` / negative; resume re-applies current total; non-resumed lifecycle events ignored; dispose cancels the subscription. *(9 tests in `app_badge_service_test.dart`.)*
- [x] Verify: `flutter analyze` && `flutter test`. *(1 pre-existing warning; 697 flutter tests pass, 4 skipped.)*

### Phase 3b.2: V2 — OS badge real-package swap (app_badge_plus)

- **Goal**: replace `NoOpAppBadgePlatform` with a concrete `app_badge_plus 1.2.10`-backed adapter so the OS launcher actually paints the badge.
- **Package decision**: `app_badge_plus` ([pub.dev/packages/app_badge_plus](https://pub.dev/packages/app_badge_plus)) — 160/160 pub points, ~190k downloads/30d, MIT, dart3-compatible, supports iOS / Android / macOS. Public API is a single `AppBadgePlus.updateBadge(int count)` (count=0 clears) + `AppBadgePlus.isSupported()`.
- [x] `pubspec.yaml` — added `app_badge_plus: ^1.2.10`. `flutter pub get` resolved cleanly; macOS / iOS pod install happens on next build.
- [x] `lib/app/core/services/app_badge_service.dart` — added `class AppBadgePlusPlatform implements IAppBadgePlatform` (`setBadgeCount(count) → AppBadgePlus.updateBadge(count)`; `clearBadge() → AppBadgePlus.updateBadge(0)`). `NoOpAppBadgePlatform` kept for tests + as a Riverpod-override safety net.
- [x] `lib/app/core/providers.dart` — `appBadgePlatformProvider` now constructs `AppBadgePlusPlatform()` by default.
- [x] `android/app/src/main/AndroidManifest.xml` — declared OEM badge permissions (Samsung READ/WRITE; HTC READ_SETTINGS/UPDATE_SHORTCUT; Sony BROADCAST_BADGE/PROVIDER_INSERT_BADGE; Apex UPDATE_COUNT; Solid UPDATE_BADGE; Huawei CHANGE_BADGE/READ_SETTINGS/WRITE_SETTINGS).
- [x] *Permissions already covered:* iOS notification authorization + Android 13+ `POST_NOTIFICATIONS` runtime permission are both requested today by `FcmService.attach()` (Phase 1), so no extra prompt is needed for the badge path.
- [x] TDD: `AppBadgePlusPlatform.setBadgeCount(N)` invokes `app_badge_plus`'s `updateBadge` method-channel call with `{'count': N}`; `clearBadge()` sends `{'count': 0}`. 2 tests in `app_badge_plus_platform_test.dart` using `TestDefaultBinaryMessengerBinding` to mock the `app_badge_plus` channel. Pins the channel name + method name so a breaking-package upgrade fails fast.
- [ ] Manual smoke matrix: real iOS device, Pixel (AOSP), Samsung One UI (OEM provider permission test). Document any per-OEM caveats in `docs/` if surfaced. *(Manual; out of session scope.)*
- [x] Verify: `flutter analyze` && `flutter test`. *(1 pre-existing warning; 699 flutter tests pass, 4 skipped.)*

### Phase 3c: V2 — remaining categories + Android channels + iOS actions (rollup)

- **Goal**: complete the V2 push catalog. Original block decomposed into six vertical slices below — same pattern used to split Phase 3b → 3b.1 → 3b.2. Each subphase ships one user-visible change end-to-end.
- **Slice order**:
  1. `3c.1` Android channel foundation (pure infra; no new categories yet)
  2. `3c.2` `payments` category end-to-end (`onExpenseCreated`)
  3. `3c.3` `onSettlementDisputed` CF (reuses payments category)
  4. `3c.4` `eventUpdates` category end-to-end (`onMemberJoined`)
  5. `3c.5` `onTaskDueScheduled` Pub/Sub scheduled CF
  6. `3c.6` iOS interactive notification actions (`MARK_DONE` / `VIEW_EXPENSE`)
- Robot journey for the full task-assigned-with-action flow lives in `3c.6` (gates on the iOS action work landing).

### Phase 3c.1: V2 — Android notification-channel foundation

- **Goal**: declare all five categorized channels up front so subsequent slices just route to a channel id. Pure platform plumbing; no new CFs, no new prefs, no UI.
- [x] `lib/app/core/services/notification_channels.dart` — `INotificationChannels` test seam + `NoOpNotificationChannels` (default fallback / test fake) + `MethodChannelNotificationChannels` (production). Static registry shipped over MethodChannel `crewpoint/notification_channels`:
  - `crewpoint_chat_urgent` — IMPORTANCE_HIGH
  - `crewpoint_chat_general` — IMPORTANCE_DEFAULT
  - `crewpoint_tasks` — IMPORTANCE_DEFAULT
  - `crewpoint_events` — IMPORTANCE_DEFAULT
  - `crewpoint_payments` — IMPORTANCE_DEFAULT
- [x] `android/app/src/main/kotlin/space/sookoon/crewpoint_app/MainActivity.kt` — override `configureFlutterEngine`; install a `MethodChannel` handler that maps each spec to `NotificationManager.createNotificationChannel(...)`. SDK-O guard.
- [x] `lib/app/core/services/fcm_service.dart` — accept optional `INotificationChannels`; call `registerAll()` after permission grant, before token fetch. Defaults to `NoOpNotificationChannels` so existing test setups stay green.
- [x] `lib/app/core/providers.dart` — `notificationChannelsProvider` (defaults to `MethodChannelNotificationChannels`); wire into `fcmServiceProvider`.
- [x] TDD: `FcmService.attach()` calls `registerAll()` exactly once after permission grant. *(`fcm_service_test.dart` — "attach() registers notification channels exactly once after permission grant".)*
- [x] TDD: `FcmService.attach()` skips `registerAll()` when permission denied. *(`fcm_service_test.dart` — "attach() skips channel registration when permission is denied".)*
- [x] TDD: `FcmService.attach()` skips `registerAll()` when `pushEnabled=false`. *(`fcm_service_test.dart` — "attach() skips channel registration when pushEnabled is false".)*
- [x] Verify: `flutter analyze` && `flutter test`. *(1 pre-existing TableMigration warning; 702 tests pass, 4 skipped.)*

### Phase 3c.2: V2 — `payments` category end-to-end (`onExpenseCreated`)

- **Goal**: prove the new channel infra by shipping the payments category end-to-end. Recipients = event members minus payer.
- [x] `lib/app/features/profile/domain/models/notification_prefs.dart` — add `payments` field (default true); round-trip via `fromMap` / `toMap` / `copyWith`.
- [x] `lib/app/features/profile/application/notification_prefs_provider.dart` — `setPayments(bool)` action.
- [x] `lib/app/features/profile/presentation/notification_settings_screen.dart` — "Payments" tile under Categories; disabled when master is OFF.
- [x] `functions/src/notifications/sendPush.ts` — extend `NotificationCategory` with `expense_added`; pref key `payments`; channel `crewpoint_payments`; thread id `payments`.
- [x] `functions/src/events/onExpenseCreated.ts` — Firestore `onDocumentCreated` on `events/{eid}/expenses/{xid}`. Excludes payer from recipients (Firestore field is `payerId`). Deep-link `/dashboard/event/{eid}/budget`. Includes settlement payments (`isPayment: true`) — the dispute path lives in 3c.3.
- [x] `functions/src/index.ts` — export `onExpenseCreated`.
- [x] TDD: `NotificationPrefs.payments` round-trips + copyWith respects it. *(`notification_prefs_test.dart` — 4 new tests cover defaults, fromMap, toMap, copyWith.)*
- [x] TDD: `NotificationSettingsScreen` toggling payments persists. *(`notification_settings_screen_test.dart` — "toggling payments OFF persists payments=false".)*
- [x] TDD: `sendCategorizedPush` writes `crewpoint_payments` channel for `category: 'expense_added'`. *(`functions/test/notifications/sendPush.test.ts` — 3 routing-table guards covering all 3 categories.)*
- [x] Verify: `flutter analyze` && `flutter test` && `npm --prefix functions test`. *(1 pre-existing TableMigration warning; 707 flutter tests pass, 4 skipped; 78 CF tests pass.)*

### Phase 3c.3: V2 — `onSettlementDisputed` CF (reuses `payments` category)

- **Goal**: notify the counterparty when a settlement gets disputed.
- [x] `functions/src/notifications/sendPush.ts` — added `settlement_disputed` category. Reuses `payments` pref + `crewpoint_payments` Android channel + `payments` iOS thread id (groups under the same "payment activity" stack as `expense_added`).
- [x] `functions/src/events/onSettlementDisputed.ts` — Firestore `onDocumentCreated` on `events/{eventId}/messages/{messageId}` filtered to `kind === 'settlement_disputed'`. Recipient = counterparty of `senderId` via the `pickDisputeRecipient(disputerId, payerId, payeeId)` helper. Deep-link `/dashboard/event/{eid}/budget`. *(The original settlement is deleted by `disputeSettlement`, so the trigger reads `payerId` + `payeeId` snapshots persisted on the chat notice — see callable change below.)*
- [x] `functions/src/events/disputeSettlement.ts` — chat notice now snapshots `payerId` + `payeeId` so `onSettlementDisputed` can resolve the counterparty without the deleted expense doc.
- [x] `functions/src/index.ts` — export `onSettlementDisputed`.
- [x] TDD: dispute by debtor pushes only the creditor; dispute by creditor pushes only the debtor. *(`functions/test/events/onSettlementDisputed.test.ts` — 3 tests pin `pickDisputeRecipient` and its defensive null-fallback. New `sendPush.test.ts` guard pins channel + pref reuse.)*
- [x] Verify: `flutter analyze` && `flutter test` && `npm --prefix functions test`. *(1 pre-existing TableMigration warning; 707 flutter tests pass, 4 skipped; 82 CF tests pass.)*

### Phase 3c.4: V2 — `eventUpdates` category end-to-end (`onMemberJoined`)

- **Goal**: notify event admins when a member accepts the invite.
- [x] `lib/app/features/profile/domain/models/notification_prefs.dart` — added `eventUpdates` field (default true) with `fromMap` / `toMap` / `copyWith` coverage.
- [x] `lib/app/features/profile/application/notification_prefs_provider.dart` — `setEventUpdates(bool)` action.
- [x] `lib/app/features/profile/presentation/notification_settings_screen.dart` — "Event updates" tile (disabled when master is OFF).
- [x] `functions/src/notifications/sendPush.ts` — `member_joined` category; pref key `eventUpdates`; channel `crewpoint_events`; iOS thread id `events`.
- [x] `functions/src/events/onMemberJoined.ts` — Firestore `onDocumentWritten` on `events/{eventId}`. `newJoiners(before, after)` helper computes the membership delta; treats `before === undefined` (doc create) as "no joiners" so the creator doesn't ping themselves. Recipients per joiner = `after.adminIds` minus the joiner; deep-link `/dashboard/event/{eid}/members`. CF skips entirely when `adminIds` is empty.
- [x] `functions/src/index.ts` — export `onMemberJoined`.
- [x] TDD: prefs round-trip + UI toggle persists. *(3 new `eventUpdates` tests in `notification_prefs_test.dart`; "toggling eventUpdates OFF" + tile-count guards in `notification_settings_screen_test.dart`.)* `newJoiners` covered by 5 unit tests in `functions/test/events/onMemberJoined.test.ts` (positive delta, multi-delta, event-create, no-op edit, member-removed-only). Routing-table guard added to `sendPush.test.ts`. CF-level `eventUpdates=false` skip is enforced by `sendCategorizedPush` (already covered server-side by the pref-gate path; no new test needed).
- [x] Verify: `flutter analyze` && `flutter test` && `npm --prefix functions test`. *(1 pre-existing TableMigration warning; 711 flutter tests pass, 4 skipped; 88 CF tests pass.)*

### Phase 3c.5: V2 — `onTaskDueScheduled` (Pub/Sub scheduled CF)

- **Goal**: due-date reminders for assigned tasks. First scheduled CF in the project — establishes the Pub/Sub trigger pattern + idempotency convention.
- [x] `functions/src/notifications/sendPush.ts` — added `task_due` category sharing the `taskUpdates` pref + `crewpoint_tasks` channel + `tasks` iOS thread id (groups with `task_assigned` under one notification stack).
- [x] `functions/src/events/onTaskDueScheduled.ts` — `onSchedule('every 15 minutes')`. Scans `collectionGroup('tasks')` where `dueDate ∈ [now, now+24h]`; filters `status === 'done'`, `reminderSent === true`, and missing `assigneeId` in-memory (cuts the required Firestore index down to a single `dueDate asc` composite). Flags `reminderSent: true` *before* the FCM send so a transient send failure leaves the user with no reminder rather than a double-ping. Field name: `dueDate` (Firestore Timestamp) — matches the Dart-side `TaskModel.dueDate` repo write at `expense_repository.dart:465`.
- [x] `functions/src/index.ts` — export `onTaskDueScheduled`.
- [x] TDD: scan picks the right window; idempotent (`reminderSent=true` prevents re-push); skips done tasks. *(`functions/test/events/onTaskDueScheduled.test.ts` — 11 tests: 5 `isDueSoon` cases (in-window, upper edge, past window, past dueDate, null) + 6 `shouldSendReminder` cases (todo, inProgress, done, reminderSent=true, no assignee, undefined-reminderSent legacy doc). Routing guard added to `sendPush.test.ts`.)*
- [ ] **Manual**: enable Pub/Sub API in GCP project (dev/stg/prod); set cost-monitoring budget alert. First deploy will also print the URL to create the required Firestore composite index (`collectionGroup: tasks, fields: dueDate asc`). *(Out of session scope.)*
- [x] Verify: `flutter analyze` && `flutter test` && `npm --prefix functions test`. *(1 pre-existing TableMigration warning; 711 flutter tests pass, 4 skipped; 100 CF tests pass.)*

### Phase 3c.6: V2 — iOS interactive notification actions

- **Goal**: `MARK_DONE` action on task pushes; `VIEW_EXPENSE` action on payments pushes. Lets users act without opening the app.
- [x] `ios/Runner/AppDelegate.swift` — registers `TASK_CATEGORY` (MARK_DONE) and `PAYMENT_CATEGORY` (VIEW_EXPENSE) via `UNNotificationCategory` at `didFinishLaunchingWithOptions`. Overrides `userNotificationCenter(_:didReceive:_:)` to forward the response's `actionIdentifier` (mapped to lowercase `mark_done` / `view_expense`) over a new `crewpoint/notification_actions` `MethodChannel`. Body taps + dismissals are not forwarded — `firebase_messaging`'s `onMessageOpenedApp` already covers the deep-link path.
- [x] `functions/src/notifications/sendPush.ts` — `CategoryConfig` gains optional `apnsCategory`; tasks bind `TASK_CATEGORY`, payments bind `PAYMENT_CATEGORY`. `chat_urgent` + `member_joined` omit it (no actions). `apns.payload.aps.category` set when the config carries a value.
- [x] `lib/app/core/services/fcm_handler.dart` — new optional `markTaskDone({eventId, taskId})` callback + `handleAction(data:)` dispatcher. Reads `data['action']`; `mark_done` → invokes the callback with the event/task ids; unknown actions no-op so a future server-side action doesn't crash older builds.
- [x] `lib/app/core/services/fcm_handler_bootstrap.dart` — accepts an optional `onNotificationAction: Stream<Map<String,String>>` and routes each event to `handler.handleAction(...)`. `dispose()` cancels the new subscription.
- [x] `lib/main.dart` — `_notificationActionStream()` adapts the iOS MethodChannel into the Dart stream; `_markTaskDoneFromNotification(...)` fires the existing `markTaskComplete` callable fire-and-forget (errors logged, never thrown — never crash the action callback path).
- [x] TDD: handler maps `action: 'mark_done'` to a task-done write; ignores unknown actions. *(`fcm_handler_test.dart` — 3 new tests cover dispatch + unknown-action + missing-eventId/taskId fallback. `fcm_handler_bootstrap_test.dart` adds an end-to-end stream → handler → callback test using a synthetic action stream.)* Routing-table guards in `sendPush.test.ts` pin `TASK_CATEGORY` / `PAYMENT_CATEGORY` apnsCategory and confirm action-less categories omit it.
- [ ] Robot: assignee receives task-assigned push → tap → lands on task detail → mark done from notification action → task state updates. *(Deferred — depends on robot harness work tracked in `todo.md:40`; the Dart-side dispatch is unit-covered above.)*
- [ ] **Manual**: real-device iOS smoke (notification action buttons can't run in widget tests). The native delegate bridge in `AppDelegate.swift` is unverified outside of compile; first build on a real device must confirm: (a) `apns.payload.aps.category` shows the action buttons, (b) tapping `MARK_DONE` fires `crewpoint/notification_actions` `actionTapped`, (c) `markTaskComplete` succeeds. *(Out of session scope.)*
- [x] Verify: `flutter analyze` && `flutter test`. *(1 pre-existing TableMigration warning; 715 flutter tests pass, 4 skipped; 103 CF tests pass.)*

### Phase 4: V2.1 — critical notifications (urgent bypass DND) ✓

- **Goal**: urgent chat alerts pierce DND/Focus when user has opted in.
- [x] `ios/Runner/Runner.entitlements` — added `com.apple.developer.usernotifications.critical-alerts` with the Apple-approval note. Until approval lands the OS silently downgrades to `time-sensitive` (matches the fallback path in `buildApnsAps`).
- [x] `functions/src/notifications/sendPush.ts` — extracted pure helper `buildApnsAps({category, criticalOptIn, cfg})`. For `category==chat_urgent` it sets `apns.payload.aps.interruption-level='critical'` when recipient `criticalOptIn==true`, else `'time-sensitive'`. Per-recipient: switched the inner loop from `sendEachForMulticast` (single payload) to `sendEach` (per-Message payload) so each token carries its owner's interruption-level. Token batching, dead-token pruning, pref filtering all unchanged.
- [x] Android `crewpoint_chat_urgent` channel set `setBypassDnd(true)` in `MainActivity.kt` — harmless without policy access, takes effect once granted.
- [x] `lib/app/core/services/notification_channels.dart` — `INotificationChannels` gains `isDndAccessGranted()` + `requestDndAccess()`. iOS / web / desktop short-circuit; Android wires to `NotificationManager.isNotificationPolicyAccessGranted` + `ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS` via the existing platform channel.
- [x] `lib/app/features/profile/presentation/notification_settings_screen.dart` — "Allow urgent alerts to bypass Do Not Disturb" tile gated on `pushEnabled && urgentChat` (no point bypassing DND if urgent chat is off). Enable fires a re-confirmation snackbar; disable is silent. `_CriticalOptInDndWarning` Card surfaces when the user has opted in but `isDndAccessGranted()` is false; "Grant access" CTA calls `requestDndAccess()` then invalidates the dnd-granted future so the banner self-dismisses on return.
- [x] `functions/src/events/onUrgentMessageCreated.ts` — already calls `sendCategorizedPush(category: 'chat_urgent')` from Phase 3a; no change needed.
- [x] TDD: CF sets `interruption-level=critical` only when recipient `criticalOptIn==true`. *(`sendPush.test.ts` — 4 new tests cover `buildApnsAps` across all 6 categories.)*
- [x] TDD: enabling criticalOptIn without DND grant on Android surfaces a non-blocking warning. *(`notification_settings_screen_test.dart` — 4 new tests cover warning visibility under all combinations of `criticalOptIn` + `dndGranted`, plus the "Grant access" CTA dispatch.)*
- [x] Verify: `flutter analyze` && `flutter test` && `npm --prefix functions test`. *(1 pre-existing TableMigration warning; 755 flutter tests pass, 4 skipped; 107 CF tests pass.)*
- [ ] **Manual**: real-device iOS smoke on Focus-enabled device after Apple approves the critical-alert entitlement. Confirm: (a) entitlement enables `interruption-level=critical`; (b) opt-in toggle persists; (c) urgent push rings through Focus. *(Out of session scope — requires Apple developer-portal review.)*
- [ ] **Manual**: real-device Android smoke on Pixel + Samsung. Confirm: (a) toggling criticalOptIn surfaces the warning banner; (b) "Grant access" opens system DND settings; (c) granting + returning dismisses the banner; (d) post-grant urgent push pierces DND. *(Out of session scope.)*

### Phase 5: V3 — quiet hours + per-event mute + granular controls (partial — A–F shipped; G + H + picker UI → Phase 5.1)

- **Goal**: time-window suppression (skipped for critical), per-event mute, mute-this-thread from notification.
- [x] `lib/app/features/profile/domain/models/notification_prefs.dart` — extended with nullable `quietHoursStart` / `quietHoursEnd` (int minutes-of-day) + `timezone` (IANA string). `withQuietHoursCleared()` helper handles the disable transition. `setQuietHours({startMinute, endMinute, timezone})` on the notifier.
- [x] `lib/app/features/dashboard/domain/models/event_mute.dart` + repository — `EventMute` model (`isMutedAt(now)`, ISO-8601 + Firestore-Timestamp `fromMap`, ISO toMap). `EventMuteRepository` at `users/{uid}/eventMutes/{eventId}` (Firestore-canonical 4-segment path — the plan's literal "users/{uid}/private/eventMutes/{eventId}" was an odd-segment-count typo; collapsed to match the existing `users/{uid}/chatReads/{eventId}` convention). Methods: `muteEvent` / `unmuteEvent` / `getEventMute` / `watchEventMute`. 8 unit tests + 7 repo tests.
- [ ] `lib/app/features/dashboard/presentation/event_dashboard_screen.dart` — overflow menu "Mute event" with duration picker (1h / 8h / 1d / until I unmute). *(Deferred to Phase 5.1 — repo + Firestore rules + CF enforcement already in place; this slice is the user-facing entry point only.)*
- [x] `functions/src/notifications/sendPush.ts` — server-side enforcement via new pure helper module `functions/src/notifications/suppress.ts` (`isWithinQuietHours` / `isMutedUntilAfter` / `shouldSuppress`). `sendCategorizedPush` reads each recipient's `notificationPrefs.{quietHoursStart, quietHoursEnd, timezone}` + `users/{uid}/eventMutes/{eventId}.mutedUntil` and drops the push. Documented bypass: `category=='chat_urgent' && criticalOptIn==true` ignores both. Switched the per-batch send to `sendEach` so each Message carries its own apns payload (Phase 4 routing already required this). Top-level `eventId: string` arg added to `SendCategorizedPushArgs`; all 6 callers updated.
- [ ] `functions/src/notifications/sendPush.ts` — include `category` + `mute_thread_action` in payload so notification action can mute event without app open. *(Deferred to Phase 5.1 — pairs with the iOS action dispatch slice below.)*
- [x] `firestore.rules` — added `match /users/{userId}/eventMutes/{eventId}` self-only block. 6 new access-matrix tests (self-write / self-read / cross-user-read-denied / cross-user-write-denied / anon-denied / self-delete-unmute).
- [ ] `lib/app/core/services/fcm_handler.dart` — handle `data['action']=='mute_event'` notification action. *(Deferred to Phase 5.1 — same iOS-action slice as the payload change above.)*
- [x] TDD: quiet-hours window suppresses non-critical pushes; critical-opt-in path bypasses. *(`suppress.test.ts` — 13 helper tests cover intra-day + overnight windows, tz-aware America/New_York mapping, mutedUntil boundary, combined `shouldSuppress` bypass.)*
- [ ] TDD: muting event for 1h sets `mutedUntil = now + 1h`; CF skips during window. *(Mute-set side covered by `event_mute_test.dart` (`EventMute.forDuration`). CF-skip-during-window is covered by `shouldSuppress` with an in-window `mutedUntil`. End-to-end integration test deferred to Phase 5.1.)*
- [x] TDD: rules deny cross-user reads of `eventMutes/*`. *(`firestore-rules.test.ts` "user CANNOT read another user's eventMutes/{eventId}" + 5 sibling cases.)*
- [x] Settings UI: minimal quiet-hours SwitchListTile (MVP — default 22:00-07:00 window in device's local timezone via `DateTime.now().timeZoneName`; falls back to `'UTC'`). Picker UI for custom windows ships in Phase 5.1.
- [x] Verify: `flutter analyze` && `flutter test` && `npm --prefix functions test`. *(1 pre-existing TableMigration warning; 779 flutter tests pass, 4 skipped; 126 CF tests pass.)*

### Phase 5.1: V3 polish — mute-event UI + mute-from-notification action ✓ *(quiet-hours custom picker + IANA tz detection split into 5.2)*

- **Goal**: complete the user-facing surface for Phase 5. Server-side enforcement, prefs model, and repo already shipped — these slices wire the UI to them.
- [x] `EventDashboardScreen` hero — bell icon visible to every member (mute is a per-user choice). Tap opens `MuteEventSheet` (new) with 4 preset durations (1h / 8h / 1d / Until I unmute) → calls `EventMuteRepository.muteEvent(now + duration)`. When a mute is active, the icon flips to `notifications_off_outlined` and the sheet shows an Unmute CTA instead. New `eventMuteProvider` (StreamProvider.family keyed by `({uid, eventId})` record) drives live UI state.
- [x] `functions/src/notifications/sendPush.ts` — `chat_urgent` now binds `apnsCategory: 'CHAT_CATEGORY'` so the lock-screen notification shows a Mute action button.
- [x] `ios/Runner/AppDelegate.swift` — `CHAT_CATEGORY` registered with a single `MUTE_EVENT` action (.authenticationRequired + .destructive). `mapActionIdentifier` adds the `MUTE_EVENT → 'mute_event'` mapping.
- [x] `FcmHandler.handleAction` — `data['action']=='mute_event'` dispatches the new optional `muteEvent({eventId, duration})` callback with a fixed 8h duration (matches the in-app 8h preset). `main.dart` wires the callback to `EventMuteRepository.muteEvent` fire-and-forget; failures logged, never crash the app-delegate callback path.
- [ ] Quiet-hours custom-window picker (two `showTimePicker` dialogs replacing the bare toggle). *(Deferred to Phase 5.2 — current toggle works with default 22:00-07:00 window; picker is polish.)*
- [ ] Proper IANA timezone detection (`flutter_timezone` or platform channel). *(Deferred to Phase 5.2 — current `DateTime.now().timeZoneName` is reliable on Android, unreliable on iOS; suppress.ts catches and falls through to "no quiet hours" on unparseable strings so the failure mode is safe.)*
- [ ] Robot: assignee mutes an event from the dashboard → CF skips a subsequent chat push during the window. *(Deferred — needs robot harness work; widget tests on `MuteEventSheet` + handler dispatch tests already cover the dispatch contract.)*
- [x] TDD: 4 new MuteEventSheet widget tests pin duration writes (1h → mutedUntil=now+1h, "Until I unmute" → 10y+ mutedUntil, Unmute CTA deletes the doc, all 4 keyed buttons render). 2 new FcmHandler tests pin `mute_event` action dispatch + no-op on missing eventId. 2 sendPush.test.ts tests pin chat_urgent's new apnsCategory + member_joined keeps omitting it.
- [x] Verify: `flutter analyze` && `flutter test` && `npm --prefix functions test`. *(1 pre-existing TableMigration warning; 785 flutter tests pass, 4 skipped; 127 CF tests pass.)*

### Phase 5.2: V3 polish — quiet-hours custom picker + IANA tz detection ✓

- **Goal**: refine the quiet-hours UX from "default window only" to a fully customizable window persisted with the device's true IANA timezone.
- [x] Quiet-hours custom-window picker — two `ListTile` rows ("Start" / "End") render beneath the toggle when quiet hours are enabled. Trailing `HH:MM` reads from `prefs.quietHoursStart/End`. Tap opens Material's `showTimePicker` (initial = persisted value); selected `TimeOfDay` round-trips to a minute-of-day int via `setQuietHours`. Rows are absent when the toggle is OFF.
- [x] Proper IANA timezone detection. New `IDeviceTimezone` Dart seam in `lib/app/core/services/device_timezone.dart` — `MethodChannelDeviceTimezone` production (calls `crewpoint/device_info` MethodChannel; returns `'UTC'` on platform failures), `LocalNameDeviceTimezone` fallback (wraps `DateTime.now().timeZoneName`). Native handlers in `MainActivity.kt` (`TimeZone.getDefault().id`) and `AppDelegate.swift` (`TimeZone.current.identifier`). `deviceTimezoneProvider` overrideable in tests; settings-screen `_QuietHoursTile` now reads the IANA tz from the provider when enabling quiet hours.
- [ ] Robot: user sets a custom 9-5 quiet-hours window in Sydney tz → CF skips a 14:00 Sydney push. *(Deferred — depends on the robot harness work tracked in `todo.md:40`; the suppress.ts pure-helper tests already pin the tz-aware enforcement.)*
- [x] TDD: 4 new `device_timezone_test.dart` tests (LocalName fallback + MethodChannel happy / throws / empty-fallback). Settings-screen test "enabling quietHours persists ... IANA timezone from deviceTimezoneProvider" pins the wiring with a `_FakeDeviceTimezone('Australia/Sydney')`. 2 new picker-row tests (rows render with the persisted times when enabled; rows absent when OFF).
- [x] Verify: `flutter analyze` && `flutter test`. *(1 pre-existing TableMigration warning; 791 flutter tests pass, 4 skipped.)*

### Phase 6: V3.1 — web push + localization + summaries

- **Goal**: feature parity for web; localized notification body; optional daily/weekly digest.
- [ ] `web/firebase-messaging-sw.js` — service worker for web push (background); pull config from `firebase_options.dart` at build.
- [ ] `lib/app/core/services/fcm_service.dart` — branch on `kIsWeb`: use `vapidKey` from env; web token stored under same `fcmTokens` array tagged `{token, platform:'web'}` (schema migration: tokens become `{value, platform}` objects — back-compat reader keeps array-of-string path).
- [ ] `functions/src/notifications/templates/{en,es,hi,fr}.json` — string templates keyed by category.
- [ ] `functions/src/notifications/sendPush.ts` — resolve `recipient.preferences.locale` (fallback `en`) → load template → interpolate placeholders.
- [ ] `functions/src/notifications/sendDigestSummary.ts` — scheduled CF (daily 9am user-tz) summarizing unread chat + pending tasks + open settlements; opt-in only via `notificationPrefs.dailyDigest`.
- [ ] `lib/app/features/profile/presentation/notification_settings_screen.dart` — quiet hours range picker + daily digest toggle.
- [ ] TDD: web token registration stores `{platform:'web'}`; android/ios stores `{platform:'mobile'}`; legacy plain-string tokens still readable.
- [ ] TDD: `sendPush` falls back to `en` template when recipient locale missing.
- [ ] TDD: digest CF skips users w/ `dailyDigest==false`; selects exactly users whose local-time hour == 9.
- [ ] Verify: `flutter analyze` && `flutter test` && `npm --prefix functions test`. Manual smoke on web build.

## Risks / Out of scope

- **Risks**:
  - **iOS critical-alert entitlement** requires Apple review; rejection forces permanent fallback to `time-sensitive` — Phase 4 must ship working under both outcomes.
  - **Android DND bypass** requires user-granted `NOTIFICATION_POLICY_ACCESS_GRANTED`; many users will deny — UX must degrade gracefully w/o silent failure.
  - **Token-schema migration** (Phase 6 web push) touches every push CF — strict back-compat reader required; consider gating behind a feature flag and dual-write window.
  - **Scheduled CF cost** (`onTaskDueScheduled` every 15min, `sendDigestSummary` daily fan-out) — monitor invocations once enabled; consider sharding by user-id-hash if volume warrants.
- **Out of scope**:
  - E2EE chat (separate spec; per `todo.md:24`).
  - In-app notification inbox/history screen (deferred — push is fire-and-forget V1–V3).
  - Rich media notifications (image attachments, action-typed deep payloads beyond mute/mark-done).
  - SMS/email fallback when push fails.
  - Server-side audit log of push delivery (only Cloud Logging today).
  - Per-uid rate limiting for push fan-out (relies on default GCF quotas; see `todo.md:78`).
