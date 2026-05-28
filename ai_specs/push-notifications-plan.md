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
- [ ] `lib/main.dart` — register top-level `@pragma('vm:entry-point')` background handler; await `FirebaseMessaging.getInitialMessage()` pre-router; subscribe `onMessage` + `onMessageOpenedApp` to `FcmHandler`.
- [ ] `lib/app/core/services/fcm_handler_bootstrap.dart` — new wrapper that wires `FcmHandler` to `MaterialBanner` foreground UI + `GoRouter.go()` for tap-handling. Reads `currentRouteProvider`.
- [ ] `lib/app/features/auth/application/auth_provider.dart` — call `FcmService.attach(uid)` on `Authenticated` transition, `detach(uid)` on sign-out.
- [ ] `lib/app/core/providers.dart` — expose `fcmServiceProvider`, `fcmHandlerProvider`.
- [ ] `ios/Runner/Info.plist` — confirm `aps-environment` entitlement; add `UNUserNotificationCenter` delegate stub in `AppDelegate.swift` for foreground presentation options.
- [ ] `android/app/src/main/AndroidManifest.xml` — declare default channel id `crewpoint_default` + meta-data for `firebase_messaging`.
- [ ] Pre-deploy: upload APNs auth key to Firebase console (dev/stg/prod).
- [ ] TDD: `FcmService.attach` writes token then subscribes refresh stream → token re-write on refresh.
- [ ] TDD: `FcmHandler.handleForegroundMessage` suppresses banner when route already matches `/event/{id}/chat`.
- [ ] TDD: `FcmHandler.handleTap` routes to `data['deepLink']`; falls back to `/dashboard` when absent.
- [ ] TDD: `main.dart` cold-start path consumes `getInitialMessage()` exactly once (no double-nav).
- [ ] Robot: `ChatRobot` urgent-message journey — sender fires urgent message → recipient receives banner → tap → lands on chat. Uses faked `IFcmGateway` + `FcmHandler` invariants (referenced in `todo.md:40`).
- [ ] Verify: `flutter analyze` && `flutter test` && `npm --prefix functions test`.

### Phase 2: V1.1 — opt-out + preferences foundation

- **Goal**: user can disable push entirely or per-category from Profile; server respects opt-out.
- [ ] `lib/app/features/profile/domain/models/notification_prefs.dart` — model: `{ pushEnabled, urgentChat, taskUpdates, eventUpdates, payments, criticalOptIn, quietHoursStart, quietHoursEnd }` (only `pushEnabled` + `urgentChat` consumed in V1; others reserved for V2/V3).
- [ ] `lib/app/features/profile/domain/repositories/i_user_repository.dart` — add `getNotificationPrefs(uid)` + `updateNotificationPrefs(uid, prefs)`.
- [ ] `lib/app/features/profile/data/firestore_user_repository.dart` — read/write `users/{uid}/private/profile.notificationPrefs`.
- [ ] `lib/app/features/profile/application/notification_prefs_provider.dart` — Riverpod `Notifier<AsyncValue<NotificationPrefs>>`.
- [ ] `lib/app/features/profile/presentation/notification_settings_screen.dart` — new screen: master toggle + per-category switches + "system permission" status row w/ deep-link to OS settings via `app_settings`/`permission_handler` (pick whichever's already in `pubspec.yaml`; else add `app_settings`).
- [ ] `lib/app/core/router/app_router.dart` — route `/profile/notifications`.
- [ ] `lib/app/features/profile/presentation/profile_screen.dart` — add "Notifications" `SettingsRow` entry.
- [ ] `lib/app/core/services/fcm_service.dart` — when `attach()` runs, gate on `notificationPrefs.pushEnabled`; if false, skip `requestPermission` and `addFcmToken` (don't store a token they've disabled).
- [ ] `functions/src/events/onUrgentMessageCreated.ts` — before sending, read each recipient's `private/profile.notificationPrefs`; skip if `pushEnabled==false || urgentChat==false`.
- [ ] `functions/test/cloud-functions.test.ts` — extend urgent-message suite: opt-out recipient receives no push.
- [ ] TDD: `NotificationPrefsNotifier` round-trips default `pushEnabled=true` when doc absent.
- [ ] TDD: toggling master off triggers `FcmService.detach()` for current device.
- [ ] TDD: CF skips recipients with `urgentChat==false`.
- [ ] Robot: navigate Profile → Notifications → toggle master off → confirm token removed from Firestore (faked).
- [ ] Verify: `flutter analyze` && `flutter test` && `npm --prefix functions test`.

### Phase 3: V2 — categories, channels, badges, deep-link map

- **Goal**: expand to task/event/payment notifications; correct Android channels + iOS categories; in-app badge counts.
- [ ] `lib/app/core/services/notification_channels.dart` — declare Android channels: `crewpoint_chat_urgent`, `crewpoint_chat_general`, `crewpoint_tasks`, `crewpoint_events`, `crewpoint_payments`. Importance ladder. Register via platform channel call in `FcmService.attach()`.
- [ ] `ios/Runner/AppDelegate.swift` — register `UNNotificationCategory` set matching server payload `category` field. Action buttons for `MARK_DONE` (tasks), `VIEW_EXPENSE` (payments).
- [ ] `functions/src/notifications/sendPush.ts` — extract shared `sendCategorizedPush(recipientUids, category, payload)` helper. Per-recipient pref check + per-channel `android.notification.channelId` + iOS `apns.payload.aps.category` + `apns.payload.aps.thread-id` for grouping.
- [ ] `functions/src/events/onTaskAssigned.ts` — Firestore trigger on `events/{eid}/tasks/{tid}.assignedTo` change → push to assignee.
- [ ] `functions/src/events/onTaskDueScheduled.ts` — scheduled (Pub/Sub `every 15 minutes`) — scan tasks w/ `dueAt within next 24h && !reminderSent`, push, set `reminderSent=true`.
- [ ] `functions/src/events/onExpenseCreated.ts` — push to event members except payer; deep-link `/dashboard/event/{eid}/budget`.
- [ ] `functions/src/events/onSettlementDisputed.ts` — push to debtor/creditor; deep-link `/dashboard/event/{eid}/budget`.
- [ ] `functions/src/events/onMemberJoined.ts` — push to admins (event invite acceptance).
- [ ] `lib/app/features/dashboard/application/unread_badge_provider.dart` — aggregate provider: sums per-event unread counts (chat) + open task assignments + pending settlement requests → exposes total + per-tab counts.
- [ ] `lib/app/core/widgets/bottom_nav_badge.dart` — extend bottom-nav shell to render `Badge` on Tasks/Chat/Budget tabs from `unreadBadgeProvider`.
- [ ] `lib/app/core/services/app_badge_service.dart` — wrap `flutter_app_badger` (or equivalent); update OS badge from `unreadBadgeProvider` listen. Clear on app foreground + on relevant screen view.
- [ ] `lib/app/core/services/fcm_handler.dart` — extend deep-link table: `/dashboard/event/{eid}/tasks`, `/.../tasks/{tid}`, `/.../budget`, `/.../budget/disputes/{settlementId}`, `/dashboard` (invite).
- [ ] `lib/app/features/profile/presentation/notification_settings_screen.dart` — surface remaining category toggles wired to V2 categories.
- [ ] TDD: `unreadBadgeProvider` re-emits when task assignment / unread message stream updates.
- [ ] TDD: `sendCategorizedPush` writes correct `android.notification.channelId` per category.
- [ ] TDD: `onTaskDueScheduled` marks `reminderSent` exactly once (idempotency).
- [ ] TDD: `FcmHandler.handleTap` routes each category's deep-link to the right go_router path.
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
