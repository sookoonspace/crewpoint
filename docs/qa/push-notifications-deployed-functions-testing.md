# Push Notifications — Testing the Deployed Cloud Functions

Step-by-step guide to validating that the deployed Cloud Functions actually send pushes end-to-end against a real Firebase project. Complements `docs/qa/push-notifications-testing-guide.md` (which covers the client-side checklist).

Use this when:

- You've just deployed the CFs to dev / staging / prod and want a confidence check.
- A user reports "I don't get push for X" and you need to know whether the CF fired.
- You're rolling out a new flavor and want to verify each push category individually.

---

## 0. Pre-flight (do this once per environment)

| Check | How |
|---|---|
| All six trigger CFs are deployed | `firebase functions:list --project crewpoint-dev` should show: `onUrgentMessageCreated`, `onTaskAssigned`, `onExpenseCreated`, `onSettlementDisputed`, `onMemberJoined`, `onTaskDueScheduled` |
| APNs key uploaded for that project | Firebase Console → Project Settings → Cloud Messaging → Apple app configuration shows a Key ID + no warning banner |
| Sandbox key in dev/stg, Production key in prod | See `docs/apns-auth-key-setup.md` §5 |
| Pub/Sub API enabled (needed for `onTaskDueScheduled`) | `gcloud services list --project crewpoint-dev --enabled | grep pubsub` returns a row |
| Firestore composite index for tasks | First scheduled-CF run prints an index-creation URL in logs — click it. Until it's clicked, `onTaskDueScheduled` throws `FAILED_PRECONDITION` once per run. |
| Firestore rules deployed | `firebase deploy --only firestore:rules --project crewpoint-dev` — confirm the deploy timestamp matches your last `firestore.rules` edit |
| Per-flavor `google-services.json` / `GoogleService-Info.plist` in place | `ls android/app/src/{dev,stg,prod}/google-services.json` and `ls ios/Runner/{Dev,Stg,Prod}/GoogleService-Info.plist` |

If any row above is missing, fix it before testing — every category below depends on it.

---

## 1. Test accounts + devices

You need two of each:

- **Account A** — the actor (triggers the event)
- **Account B** — the recipient (the device that should buzz)

Devices:

- Real iPhone signed in as B with the matching flavor build installed (e.g. `flutter run --flavor dev` for the dev Firebase project)
- Real Android device (or Pixel emulator on a non-blocked network) signed in as A

Both A and B should be members of the same event. For admin-only categories (`member_joined`) B must also be an event admin.

Pre-test on B:

1. Sign in → permission prompt → grant.
2. Open **Profile → Dev tools → FCM diagnostic** (dev flavor only). Confirm:
   - `Auth status: authorized`
   - `APNs token: <40+ hex chars>` (iOS)
   - `FCM token (live): <FCM token string>` (both)
   - `Firestore fcmTokens: 1 token` (the token was actually written)
3. Background the app. Pushes route differently depending on lifecycle — track which one you're testing:
   - **Foreground** — in-app `MaterialBanner`, no system tray.
   - **Background** — system notification, tap → deep-link.
   - **Closed / cold start** — system notification, tap → cold-launch + deep-link.

---

## 2. Test each category — step by step

For each section: trigger from A, expect on B, confirm in Cloud Logging that the CF actually fired.

### 2.1 `onUrgentMessageCreated` (chat_urgent)

**Trigger** (as A):

1. Open the event chat.
2. Compose a message and tap the **🚨 Urgent** toggle on send.
3. Send.

**Expect on B**:

- System notification, title `🚨 Urgent in {EventTitle}`, body = the message (truncated to 80 chars).
- Tap → `/dashboard/event/{eid}/chat`.
- If B is already on `/dashboard/event/{eid}/chat` foreground, the foreground `MaterialBanner` is **suppressed** (this is intentional).

**Confirm CF fired**:

```bash
firebase functions:log --project crewpoint-dev --only onUrgentMessageCreated
```

Or in the GCP Console:

- Cloud Logging → Logs Explorer → `resource.type="cloud_function" AND resource.labels.function_name="onUrgentMessageCreated"`

Expected log line:

```
Urgent push for {messageId}: N attempted, M skipped
```

`attempted = 0, skipped = N` → recipients exist but every one was filtered (pref off / token absent / sender excluded).
`attempted > 0, skipped = 0` → push was delivered to N tokens.

### 2.2 `onTaskAssigned`

**Trigger** (as A):

1. As A, create a new task in the event, set assignee to B (or change an existing task's assignee to B).
2. Save.

**Expect on B**:

- System notification, title `New task in {EventTitle}`, body = task title.
- Tap → `/dashboard/event/{eid}/tasks/{tid}`.
- **No push** if A === B (self-assign suppressed).
- iOS long-press the notification → **Mark Done** button visible → tapping it triggers `markTaskComplete` and the task moves to Done in Firestore.

**Confirm CF fired**:

```bash
firebase functions:log --project crewpoint-dev --only onTaskAssigned
```

Expected: `Task-assigned push for {taskId}: N attempted, M skipped`.

### 2.3 `onTaskDueScheduled`

This one is **batch-driven** (Pub/Sub, runs every 15 minutes). Patience required.

**Trigger** (as A):

1. Assign a task to B with `dueDate` ∈ next 24h. Easiest: set it to ~30 minutes from now.
2. Wait for the next scheduler tick. Typical first ping arrives 5–15 minutes after creation.

**Expect on B**:

- System notification, title `Task due soon`, body = task title.
- Tap → task detail.
- **Idempotent**: after the first ping, `reminderSent: true` is written to the task. Subsequent scheduler runs skip it. To re-test, manually clear `reminderSent` in the Firestore Console.

**Confirm CF fired**:

```bash
firebase functions:log --project crewpoint-dev --only onTaskDueScheduled
```

Expected log line:

```
Task-due scan @ <ISO timestamp>: scanned=N attempted=M skipped=K
```

Force a manual run (skip waiting 15 min):

```bash
gcloud scheduler jobs run firebase-schedule-onTaskDueScheduled --location us-central1 --project crewpoint-dev
```

(Job name may differ — `gcloud scheduler jobs list --project crewpoint-dev` to find the exact name.)

### 2.4 `onExpenseCreated`

**Trigger** (as A):

1. Open the event budget.
2. Add a new expense (any category / amount).

**Expect on B** (and every other event member except A):

- System notification, title `New expense in {EventTitle}`, body `{description} (${amount})`.
- Tap → `/dashboard/event/{eid}/budget`.
- **A does not get a push** (payer excluded).

**Confirm CF fired**:

```bash
firebase functions:log --project crewpoint-dev --only onExpenseCreated
```

Expected: `Expense-added push for {expenseId}: N attempted, M skipped`.

### 2.5 `onSettlementDisputed`

**Setup**: A and B must have an outstanding settlement between them (one paid via the budget → settle-up flow).

**Trigger** (as the disputer — typically the recipient of the settlement):

1. Open the settlement-receipt chat message.
2. Tap **Dispute** in the overflow.

**Expect on the counterparty (the non-disputing party)**:

- System notification, title `Settlement disputed in {EventTitle}`, body `Tap to review the budget.`
- Tap → `/dashboard/event/{eid}/budget`.
- **Disputer does not get a push** (they made the change).

**Confirm CF fired**:

```bash
firebase functions:log --project crewpoint-dev --only onSettlementDisputed
```

Expected: `Settlement-disputed push for {messageId}: N attempted, M skipped`.

### 2.6 `onMemberJoined`

**Setup**: A is an event admin. B is **not** yet in the event.

**Trigger** (as B):

1. B joins the event via invite code (or the `joinEvent` deep-link).

**Expect on A** (and every other event admin except B):

- System notification, title `New member in {EventTitle}`, body `Tap to review the member list.`
- Tap → `/dashboard/event/{eid}/members`.
- **Event creation does NOT fire this** — the creator isn't a "joiner" of their own event. Only deltas to `memberIds` post-creation count.

**Confirm CF fired**:

```bash
firebase functions:log --project crewpoint-dev --only onMemberJoined
```

Expected: `Member-joined push for {joinerId} in {eventId}: N attempted, M skipped`.

---

## 3. Verifying server-side pref enforcement

Each CF reads recipient `notificationPrefs` and skips silently when the relevant flag is off. Validate one master-toggle case and one per-category case to confirm.

### 3.1 Master toggle

1. On B, **Profile → Notifications → Push notifications → OFF**.
2. As A, trigger any category from §2.
3. **Expect**: nothing on B. In CF logs: `attempted=0 skipped=N` (every recipient filtered).

### 3.2 Per-category toggle

| Toggle off on B | Should silence |
|---|---|
| Urgent chat alerts | `chat_urgent` only |
| Task assignments | `task_assigned` + `task_due` |
| Payments | `expense_added` + `settlement_disputed` |
| Event updates | `member_joined` |

For each: turn off → trigger → confirm silence + CF log `skipped` count includes B.

---

## 4. Reading Cloud Logging effectively

Universal filter to see push activity across all six CFs:

```bash
firebase functions:log --project crewpoint-dev
```

Or in the GCP Console with this query:

```
resource.type="cloud_function"
resource.labels.function_name=~"^(onUrgentMessageCreated|onTaskAssigned|onTaskDueScheduled|onExpenseCreated|onSettlementDisputed|onMemberJoined)$"
severity>=INFO
```

Useful sub-filters:

- **Find a single trigger event** — `textPayload:"push for <id>"` (substitute the eventId / messageId / taskId you're tracking).
- **Find dead-token pruning** — `textPayload:"Pruned"` shows token cleanup events.
- **Find skipped recipients** — `textPayload:"Skipping" AND textPayload:"push for"` — the `sendCategorizedPush` per-recipient skip log.
- **Find failures** — `severity>=WARNING` — surfaces the rare event-doc-missing / Firestore retry log lines.

For deeper FCM-side debugging:

```
resource.type="fcm"
```

This shows the FCM service's own delivery decisions (whether tokens were valid, rejected, etc) — useful when a CF says "attempted: 5" but recipients see nothing.

---

## 5. Manually invoking a CF for fast iteration

You can't HTTP-invoke Firestore-trigger CFs directly, but you can trigger them by writing the exact doc shape they listen for. Useful for testing without going through the full UI.

### Example: force `onTaskAssigned` from the Firebase Console

1. Firebase Console → Firestore → navigate to `events/{eid}/tasks/{tid}` (or create a new doc here).
2. Edit → set `assigneeId` to B's uid → set `createdBy` to A's uid → set `title` to "Smoke test task" → set `eventId` to `{eid}` → Save.
3. Within a few seconds, B's device should receive a push.

### Example: force `onSettlementDisputed`

1. Create a doc at `events/{eid}/messages/{anyId}` with these fields:
   ```json
   {
     "senderId": "<disputerUid>",
     "kind": "settlement_disputed",
     "payerId": "<payerUid>",
     "payeeId": "<payeeUid>",
     "text": "Settlement disputed",
     "isHighPriority": false,
     "timestamp": <serverTimestamp>
   }
   ```
2. Save → the counterparty (`payeeUid` if disputer is payer, else `payerUid`) should get the push.

These shortcuts bypass any client-side bugs and verify only the CF + FCM path.

---

## 6. Troubleshooting

| Symptom | Look at | Likely cause |
|---|---|---|
| CF log shows `attempted: 0 skipped: N` | The skipped log lines | Recipient `notificationPrefs.pushEnabled=false` or the category-specific pref is off |
| CF log shows attempts but device gets nothing | FCM logs (`resource.type="fcm"`) | Token rejected by APNs (wrong env), or token is stale (dead-token pruning should fix on next run) |
| Push arrives in dev but not in stg | Compare key-id under each Firebase project | Wrong APNs key uploaded to the wrong project |
| Push arrives in stg but not on TestFlight | Re-check `aps-environment` in the archive | TestFlight builds are signed with `aps-environment=production` — need the production key in `crewpoint-prod` |
| CF doesn't appear in logs at all | `firebase functions:list` | CF not deployed (or deployed but disabled). Re-deploy. |
| `onTaskDueScheduled` throws `FAILED_PRECONDITION` once per 15m | Firestore Console → Indexes | Composite index not created yet. Click the auto-generated URL in the first error log. |
| `BadDeviceToken` from FCM | `aps-environment` vs uploaded key environment | Sandbox key + prod build (or vice versa). Verify mapping in `docs/apns-auth-key-setup.md` §5.2. |
| `Pruned N dead FCM tokens` shows up | Expected, not a bug | Stale tokens (reinstall / sign-out) being cleaned. |
| All categories silent after deploy | APNs key still configured for old team? | Verify Team ID + Key ID in Firebase Cloud Messaging settings. |

---

## 7. Per-environment quick smoke (5 minutes total)

For a fast confidence check after a deploy, run only these:

1. **Sign in B on real device for the matching flavor** (dev / stg / prod).
2. **Open Dev tools** → confirm tokens populated, Firestore `fcmTokens` = 1.
3. **A assigns a task to B** → B's device buzzes within ~5 seconds. (Covers `task_assigned` → covers FCM auth + recipient gating + tokens → covers ~80% of the push stack.)
4. **A adds an expense** → B's device buzzes. (Covers `expense_added` → covers a different category + channel.)
5. **Open CF logs** for the two CFs → confirm `attempted >= 1`.

If all five pass, push is healthy in that environment. If any fail, drill in with §2 + §6.
