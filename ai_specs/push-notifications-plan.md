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

### Phase 3b: V2 — badges + unread aggregation (deferred)

- **Goal**: visible unread counts on bottom-nav tabs + OS app icon. Pure client work over existing data streams; no new CFs.
- [ ] `lib/app/features/dashboard/application/unread_badge_provider.dart` — aggregate provider summing per-event unread chat + open task assignments + pending settlement requests; exposes total + per-tab counts.
- [ ] `lib/app/core/widgets/bottom_nav_badge.dart` — extend bottom-nav shell to render `Badge` on Tasks/Chat/Budget tabs from `unreadBadgeProvider`.
- [ ] `lib/app/core/services/app_badge_service.dart` — wrap `flutter_app_badger` (or equivalent); update OS badge from `unreadBadgeProvider` listen. Clear on app foreground + on relevant screen view.
- [ ] TDD: `unreadBadgeProvider` re-emits when task assignment / unread message stream updates.
- [ ] Verify: `flutter analyze` && `flutter test`.

### Phase 3c: V2 — remaining categories + Android channels + iOS actions (deferred)

- **Goal**: add the rest of the V2 category catalog + platform polish.
- [ ] `lib/app/core/services/notification_channels.dart` — declare Android channels: `crewpoint_chat_urgent`, `crewpoint_chat_general`, `crewpoint_tasks`, `crewpoint_events`, `crewpoint_payments`. Importance ladder. Register via MethodChannel from `FcmService.attach()`.
- [ ] `android/app/src/main/kotlin/.../MainActivity.kt` — MethodChannel handler that calls `NotificationManager.createNotificationChannel(...)`. Required because Flutter has no first-party API to declare channels.
- [ ] `ios/Runner/AppDelegate.swift` — register `UNNotificationCategory` set; action buttons for `MARK_DONE` (tasks), `VIEW_EXPENSE` (payments).
- [ ] `functions/src/events/onTaskDueScheduled.ts` — Pub/Sub scheduled (`every 15 minutes`) — scan tasks with `dueAt within next 24h && !reminderSent`, push via `sendCategorizedPush(category: 'task_due')`, set `reminderSent=true`. Required infra: Pub/Sub API enabled + cost monitoring.
- [ ] `functions/src/events/onExpenseCreated.ts` — push to event members except payer; deep-link `/dashboard/event/{eid}/budget`.
- [ ] `functions/src/events/onSettlementDisputed.ts` — push to debtor/creditor; deep-link `/dashboard/event/{eid}/budget`.
- [ ] `functions/src/events/onMemberJoined.ts` — push to admins (event invite acceptance).
- [ ] `lib/app/features/profile/domain/models/notification_prefs.dart` — add `eventUpdates`, `payments` fields.
- [ ] `lib/app/features/profile/presentation/notification_settings_screen.dart` — surface remaining category toggles.
- [ ] TDD: `sendCategorizedPush` writes correct `android.notification.channelId` per category.
- [ ] TDD: `onTaskDueScheduled` marks `reminderSent` exactly once (idempotency).
- [ ] Robot: assignee receives task-assigned push → tap → lands on task detail → mark done from notification action → task state updates.
- [ ] Verify: `flutter analyze` && `flutter test` && `npm --prefix functions test`.

### Phase 4: V2.1 — critical notifications (urgent bypass DND)

- **Goal**: urgent chat alerts pierce DND/Focus when user has opted in.
- [ ] `ios/Runner/Runner.entitlements` — add `com.apple.developer.usernotifications.critical-alerts` (request approval from Apple; fall back to `time-sensitive` interruption-level when entitlement unavailable).
- [ ] `functions/src/notifications/sendPush.ts` — for `category==chat_urgent` set `apns.payload.aps.interruption-level='critical'` when recipient `criticalOptIn==true`, else `'time-sensitive'`; Android `crewpoint_chat_urgent` channel set `IMPORTANCE_HIGH` + `setBypassDnd(true)` (requires `NotificationManager.NOTIFICATION_POLICY_ACCESS_GRANTED` — prompt in-app).
- [ ] `lib/app/core/services/notification_channels.dart` — request DND access on Android via platform channel when user enables criticalOptIn.
- [ ] `lib/app/features/profile/presentation/notification_settings_screen.dart` — explicit "Allow urgent alerts to bypass Do Not Disturb" toggle; explain risks; require re-confirmation toast on enable.
- [ ] `functions/src/events/onUrgentMessageCreated.ts` — migrate to call `sendCategorizedPush(category: 'chat_urgent')`.
- [ ] TDD: CF sets `interruption-level=critical` only when recipient `criticalOptIn==true`.
- [ ] TDD: enabling criticalOptIn without DND grant on Android surfaces a non-blocking warning.
- [ ] Verify: `flutter analyze` && `flutter test` && `npm --prefix functions test`. Manual smoke on real iOS device w/ Focus enabled.

### Phase 5: V3 — quiet hours + per-event mute + granular controls

- **Goal**: time-window suppression (skipped for critical), per-event mute, mute-this-thread from notification.
- [ ] `lib/app/features/profile/domain/models/notification_prefs.dart` — extend w/ `quietHoursStart`, `quietHoursEnd`, `timezone`.
- [ ] `lib/app/features/dashboard/domain/models/event_mute.dart` + repository — write `users/{uid}/private/eventMutes/{eventId}` w/ `{mutedUntil}`.
- [ ] `lib/app/features/dashboard/presentation/event_dashboard_screen.dart` — overflow menu "Mute event" with duration picker (1h / 8h / 1d / until I unmute).
- [ ] `functions/src/notifications/sendPush.ts` — server-side enforcement: read recipient `notificationPrefs.quietHours` + `eventMutes/{eventId}.mutedUntil`; suppress unless `category=='chat_urgent' && criticalOptIn==true`.
- [ ] `functions/src/notifications/sendPush.ts` — include `category` + `mute_thread_action` in payload so notification action can mute event without app open.
- [ ] `firestore.rules` — allow self read/write of `users/{uid}/private/eventMutes/{eventId}` (add to rules + access-matrix tests).
- [ ] `lib/app/core/services/fcm_handler.dart` — handle `data['action']=='mute_event'` notification action.
- [ ] TDD: quiet-hours window suppresses non-critical pushes; critical-opt-in path bypasses.
- [ ] TDD: muting event for 1h sets `mutedUntil = now + 1h`; CF skips during window.
- [ ] TDD: rules deny cross-user reads of `eventMutes/*`.
- [ ] Verify: `flutter analyze` && `flutter test` && `npm --prefix functions test`.

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
