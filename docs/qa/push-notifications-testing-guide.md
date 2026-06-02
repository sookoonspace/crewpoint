# Push Notifications — Tester's Guide

End-to-end smoke + regression checklist for everything shipped under the push-notifications roadmap (Phases 1, 2, 3a, 3b, 3b.1, 3b.2, 3c.1–3c.6). Use this whenever you cut a new build, change the FCM config, or want to confirm a category still fires end-to-end.

> If you're testing on simulators only, **skip anything tagged `[real device]`** — APNs + OS-launcher badges + iOS action buttons don't work on simulators.

---

## 1. What's shipped

| Category | Trigger | Channel (Android) | iOS thread | iOS action |
|---|---|---|---|---|
| `chat_urgent` | New chat message with `isHighPriority: true` | `crewpoint_chat_urgent` | `chat` | — |
| `task_assigned` | New / re-assigned task | `crewpoint_tasks` | `tasks` | `MARK_DONE` |
| `task_due` | Pub/Sub every 15 min, 24h window | `crewpoint_tasks` | `tasks` | `MARK_DONE` |
| `expense_added` | New expense in event | `crewpoint_payments` | `payments` | `VIEW_EXPENSE` |
| `settlement_disputed` | Settlement dispute via callable | `crewpoint_payments` | `payments` | `VIEW_EXPENSE` |
| `member_joined` | `events/{id}.memberIds` grew | `crewpoint_events` | `events` | — |

Per-recipient prefs gate every send (server-side) — disable a category from **Profile → Notifications** and the CF skips the user even if the token is alive.

---

## 2. Prerequisites (one-time setup per environment)

These manual steps must be done before any push will actually deliver. Verify them up front — most "push not working" reports trace back to one of these.

### 2.1 APNs auth key uploaded to Firebase

iOS will fetch a token from Firebase, but Firebase can't reach APNs until you've uploaded the auth key.

1. Apple Developer → **Keys** → create or download an `.p8` with the **Apple Push Notifications service (APNs)** capability.
2. Firebase Console → your project → **Project settings** → **Cloud Messaging** → **Apple app configuration** → upload the `.p8` along with your **Key ID** and **Team ID**.
3. Repeat for dev / staging / prod Firebase projects.

### 2.2 Pub/Sub API enabled (required for `onTaskDueScheduled`)

See `docs/gcp_budget_settings.md`. TL;DR: `gcloud services enable pubsub.googleapis.com` in each project + set a budget alert.

### 2.3 Firestore composite index for `task_due`

The first deploy of `onTaskDueScheduled` will print a URL in the logs to one-click create the index. Until you click it, the CF will throw `FAILED_PRECONDITION` once per run:

- **Collection group**: `tasks`
- **Field**: `dueDate` (ascending)

### 2.4 google-services / GoogleService-Info per flavor

`android/app/src/{dev,stg,prod}/google-services.json` and `ios/Runner/{Dev,Stg,Prod}/GoogleService-Info.plist` must be present. These live outside the repo by design.

### 2.5 Cloud Functions deployed

```bash
cd functions
npm run build
firebase deploy --only functions --project <env>
```

You should see these in the deploy list (Phase 3c category set + Phase 1/3a originals):

- `onUrgentMessageCreated`
- `onTaskAssigned`
- `onExpenseCreated`
- `onSettlementDisputed`
- `onMemberJoined`
- `onTaskDueScheduled` *(scheduled — not invokable on demand)*

If any are missing, your `functions/src/index.ts` exports got dropped.

---

## 3. Test setup

You need **two accounts** and **one event**:

- **Account A** — the actor (sender of the action that triggers the push)
- **Account B** — the recipient (the user whose device should buzz)

Both accounts should be members of the same event. For admin-only categories (`member_joined`) make sure B is also an admin.

Recommended:

1. Sign in as A on Device 1, B on Device 2.
2. Create an event from A; invite B.
3. On B: open **Profile → Notifications**, confirm master is **ON**, all 4 categories are **ON**.
4. On B: background the app (don't force-quit) — push delivery flows differ between foreground / background / closed.

> **App lifecycle matters.** Always note which of these you tested:
> - **Foreground** (app open + visible) → in-app `MaterialBanner`, no system notification.
> - **Background** (app open but not foregrounded) → system notification, tap → deep-link.
> - **Closed / cold start** (force-quit) → system notification, tap → cold-launch + deep-link.

---

## 4. Functional tests — one category at a time

For each category below: trigger on A, expect a push on B, tap it, verify the deep-link landing screen.

### 4.1 `chat_urgent` — Phase 1

**Trigger**: send a message in the event chat with the **🚨 Urgent** toggle on (long-press the send button or use the urgent affordance — depends on chat UI build).

**Expect on B**:

- Background / closed: system notification, title `🚨 Urgent in {EventTitle}`, body = the message (truncated to 80 chars).
- Foreground: `MaterialBanner` instead of a system notification, **unless** B is already on `/dashboard/event/{eid}/chat` for the same event — then it's suppressed.
- Tap → lands on `/dashboard/event/{eid}/chat`.

### 4.2 `task_assigned` — Phase 3a

**Trigger**: as A, create a new task in the event and set the assignee to B (or change an existing task's assignee to B).

**Expect on B**:

- System notification, title `New task in {EventTitle}`, body = the task title.
- Tap → lands on `/dashboard/event/{eid}/tasks/{tid}`.
- **No push** if A === B (self-assign is suppressed server-side).

### 4.3 `task_due` — Phase 3c.5 (scheduled CF)

This one is slower because it's batch-driven.

**Trigger**: as A, assign a task to B with `dueDate` set somewhere in the next 24h (e.g. 30 minutes from now). Then wait — the scheduler runs every 15 min.

**Expect on B**:

- Within ~15 minutes of crossing into the 24h window: system notification, title `Task due soon`, body = task title.
- Tap → lands on the task detail.
- **Idempotency**: after the first ping, the task's `reminderSent` field is `true`. Re-running the scheduler should NOT send a second push for the same task. To re-test: manually delete the `reminderSent` field (or set it to `false`) in the Firestore console.

> If you see a `FAILED_PRECONDITION` log on the first scheduled run, the Firestore composite index from §2.3 isn't created yet.

### 4.4 `expense_added` — Phase 3c.2

**Trigger**: as A, add a new expense in the event (any category, any amount).

**Expect on B**:

- System notification, title `New expense in {EventTitle}`, body = `{description} ($amount.tofixed(2))`.
- Tap → lands on `/dashboard/event/{eid}/budget`.
- **No push to A** (payer is excluded from recipients).

### 4.5 `settlement_disputed` — Phase 3c.3

**Setup**: A and B must have an outstanding settlement (e.g. A paid for the group; B owes A; one party "settled up" via the budget screen).

**Trigger**: as the disputer (whoever just got "paid" or just "paid"), open the settlement message and **Dispute** it.

**Expect on the counterparty**:

- System notification, title `Settlement disputed in {EventTitle}`, body `Tap to review the budget.`
- Tap → lands on `/dashboard/event/{eid}/budget`.
- **Disputer does NOT get a push** (they made the change).

### 4.6 `member_joined` — Phase 3c.4 (admin-only)

**Setup**: A is the event admin (default for the creator). B should NOT yet be in the event.

**Trigger**: B joins the event via invite code.

**Expect on A** (the admin):

- System notification, title `New member in {EventTitle}`, body `Tap to review the member list.`
- Tap → lands on `/dashboard/event/{eid}/members`.
- **Important**: event creation does NOT fire this (the creator isn't a "joiner" of their own event). Only deltas to `memberIds` post-creation.
- If B joins and is themselves an admin, B is filtered out of the recipient set.

---

## 5. Preferences / opt-out tests

These verify the server-side pref gate on `sendCategorizedPush`.

**On B, in Profile → Notifications**:

| Toggle | Effect |
|---|---|
| **Push notifications** (master) OFF | Token detached locally; **no category** delivers, even for already-running CFs. Re-enable → permission prompt may re-appear; a new token is registered. |
| **Urgent chat alerts** OFF | `chat_urgent` only — other categories still arrive. |
| **Task assignments** OFF | `task_assigned` + `task_due` — both task categories share this pref. |
| **Payments** OFF | `expense_added` + `settlement_disputed` — both payment categories share this pref. |
| **Event updates** OFF | `member_joined` — silenced. |

**Quick regression**: turn master OFF on B, have A trigger each category once. B should receive nothing.

---

## 6. Badges

### 6.1 Bottom-nav badges — Phase 3b

Aggregate unread counts on the bottom nav:

- **Tasks tab** — count of B's assigned tasks where `status != done`.
- **Chat tab** — count of events with `unreadCount > 0`.
- **Budget tab** — count of open debt rows for B.

**Verify**:

1. As A, assign 3 tasks to B → B's **Tasks** tab badge shows `3`.
2. B marks one done → badge drops to `2`.
3. At ≥100, badge displays `99+`.

### 6.2 OS launcher icon badge — Phase 3b.1 / 3b.2 `[real device]`

Mirrors `unreadBadgeProvider.total` to the OS app-icon badge via `app_badge_plus`.

**Verify**:

1. Background the app with at least 1 unread item.
2. Look at the home screen icon — badge count should match the total of all three bottom-nav badges.
3. Foreground the app, clear all unread → badge clears.
4. **Android OEM check**: some launchers (especially Samsung One UI) drop the badge when the icon repaints. The service re-applies the badge on `AppLifecycleState.resumed` — verify by force-quitting + relaunching with unread items.

> Simulator note: iOS Simulator can show numeric badges but does not actually invoke `app_badge_plus`'s native code in the same way as a real device. Real device required for honest verification.

---

## 7. iOS action buttons — Phase 3c.6 `[real device]`

The native UNNotificationCategory + delegate bridge can't be exercised on a simulator. You need a real iPhone with the build installed.

### 7.1 Setup

The action buttons appear when the user **long-presses** (or pulls down on the lock screen / Notification Center) a delivered notification. They do **not** show on the initial banner.

### 7.2 `MARK_DONE` action

**Trigger**: have A assign a task to B (Phase 4.2 path) OR wait for a `task_due` reminder (Phase 4.3 path).

**On B's device**:

1. Background the app.
2. Wait for the notification.
3. Long-press the notification → tap **Mark Done**.
4. The notification dismisses; no app open.
5. Open the app — the task should now be in **Done** status.

**Under the hood**: iOS calls `userNotificationCenter:didReceive:`; AppDelegate fires `crewpoint/notification_actions` → `actionTapped` with `{action: 'mark_done', eventId, taskId, deepLink}`; Dart side calls the `markTaskComplete` callable. Failures are logged but don't crash.

### 7.3 `VIEW_EXPENSE` action

**Trigger**: as A, add an expense OR dispute a settlement (Phase 4.4 / 4.5).

**On B's device**:

1. Long-press the notification → tap **View Expense**.
2. App should open to `/dashboard/event/{eid}/budget` (foregrounded — the action carries `.foreground` option).

### 7.4 Action button verification checklist

For each action:

- [ ] Action button is visible under the notification
- [ ] Tapping it dismisses the notification
- [ ] (MARK_DONE) Task transitions to done in Firestore + the UI
- [ ] (VIEW_EXPENSE) App foregrounds to the budget screen
- [ ] No crash in `AppDelegate`

---

## 8. Edge cases

### 8.1 Cold-start tap

1. Force-quit the app on B.
2. Trigger a push from A.
3. B taps the notification.
4. App should cold-launch directly to the deep-link target screen — not the dashboard.

Backed by the `FcmHandlerBootstrap.getInitialMessage()` path.

### 8.2 Foreground banner suppression for chat

1. B opens the app and navigates to `/dashboard/event/{eid}/chat`.
2. A sends an **urgent** message in the same event.
3. **Expect**: no `MaterialBanner` (B is already looking at the thread).

Other categories don't have this suppression — they banner regardless.

### 8.3 Token detach on sign-out

1. Have B sign out.
2. Have A trigger any category targeting B.
3. **Expect**: no push (B's token was removed from `users/{uid}/private/profile.fcmTokens` before sign-out completed).

### 8.4 Dead token pruning

1. Reinstall the app on B (this typically rotates the token).
2. Have A trigger a push targeting B.
3. The CF will get `messaging/registration-token-not-registered` for the stale token, prune it, and (if a new token has been written via re-attach) succeed for the live one. Check Cloud Logging for `Pruned N dead FCM tokens`.

### 8.5 Notification channel propagation `[Android]`

1. Settings → Apps → CrewPoint → Notifications.
2. Verify the 5 channels appear with their declared importance:
   - **Urgent chat** (High)
   - **Chat** (Default)
   - **Tasks** (Default)
   - **Event updates** (Default)
   - **Payments** (Default)
3. Channels are declared by `FcmService.attach()` → MethodChannel → Kotlin `MainActivity`. If they don't show, attach didn't run (typically: master push toggle is OFF, or permission was denied).

---

## 9. Troubleshooting quick reference

| Symptom | First place to look |
|---|---|
| No push on any category | APNs key uploaded (§2.1)? Master toggle ON? Permission granted? FCM token written to Firestore? |
| Push works in dev but not staging/prod | Per-flavor `GoogleService-Info.plist` / `google-services.json` in place. APNs key uploaded **per Firebase project**. |
| `task_due` never fires | Pub/Sub API enabled (§2.2)? Firestore composite index created (§2.3)? Task `dueDate` actually in the 24h window? `reminderSent` not already `true`? |
| `member_joined` doesn't fire on event creation | Working as designed — creator is not a "joiner". Try having someone else join. |
| iOS action buttons missing | Long-press the notification (they don't show on the banner). `apns.payload.aps.category` in the FCM payload matches a registered category (`TASK_CATEGORY` / `PAYMENT_CATEGORY`)? |
| OS launcher badge stuck after reading all messages | App was force-quit before the resume-listener could clear it. Open the app once. |
| Notification arrived but tap deep-link wrong | `data['deepLink']` field on the FCM payload. Check Cloud Logging for the CF that fired. |

---

## 10. Reporting issues

When filing a bug, include:

- **Phase / category** (e.g. "Phase 3c.4 / `member_joined`")
- **Lifecycle state** (foreground / background / cold start)
- **Platform + device** (iOS 17 on iPhone 14; Android 14 on Pixel 7; Android 14 on Samsung S24)
- **Permission state** (Settings → Notifications → CrewPoint)
- **Sender + recipient uids**
- **Cloud Logging URL** for the most recent invocation of the relevant CF
- **Firestore path** of the doc that should have triggered (e.g. `events/{eid}/tasks/{tid}`)
