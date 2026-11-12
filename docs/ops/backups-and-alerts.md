# Backups and alerts

Set up on Nov 3, 2026, after a billing lapse took down every Cloud Function on Nov 2 with nobody told, and when deleted Firestore data could not have been recovered.

## Current state

| Protection | dev | stg | prod |
|---|---|---|---|
| Daily backups, kept 14 days | On | On | On |
| Point-in-time recovery | On | Off | On |
| `joinEvent` uptime check with email alert | On | Off | On |
| Crash reporting (Sentry, app builds with a `SENTRY_DSN`) | Waiting for DSN | Off | Off |
| Backend error alerts | Off | Off | Off |

Monthly budgets on the billing account, covering all three projects:

- **CrewPoint monthly, $5:** emails derodian@gmail.com and admin@sookoon.space through the dev notification channels.
- **$15 Monthly Budget Alert:** emails the billing account's admins.

Budgets only send alerts; they do not cap spending.

**Still to do:**

- [x] Rehearse a restore. Done on dev on Nov 12, 2026; see [Restore rehearsals](#restore-rehearsals).
- [ ] Rehearse a restore again on prod data before the convention, when prod holds real events.
- [ ] Write and rehearse a script that copies lost documents from a restored copy back into `(default)`.
- [ ] Run an outside billing check, as described below.
- [ ] Confirm an alert actually reaches both inboxes.
- [ ] Add crash reporting: built into the app (#92); on once `.env.dev` has a `SENTRY_DSN` and a test crash is confirmed. Then stg and prod.
- [ ] Add backend error alerts.

## Commands

Set the project first:

```bash
PROJECT=crewpoint-dev
```

### Backups

```bash
gcloud firestore backups schedules create \
  --project="$PROJECT" --database='(default)' \
  --recurrence=daily --retention=14d

gcloud firestore databases update \
  --project="$PROJECT" --database='(default)' --enable-pitr
```

### Rehearse a restore

Restore into a **new** database, so live data is untouched:

```bash
gcloud firestore backups list --project="$PROJECT" \
  --format='table(name,snapshotTime,state)'

gcloud firestore databases restore \
  --project="$PROJECT" \
  --source-backup=<backup name from the list above> \
  --destination-database=restore-test
```

The restore command returns at once, while the copy is still being made. Wait until the operation it prints reports `done: true`:

```bash
gcloud firestore operations describe <operation name it printed> \
  --format='value(done,metadata.operationState)'
```

Then compare the copy with live. The script only reads, from both, and refuses `(default)` as the copy. It counts the main collections in each, and checks that every event, expense and member document in the copy matches live exactly, unless live changed it after the backup. It needs application-default credentials (`gcloud auth application-default login`).

```bash
cd functions
npx tsx scripts/checkRestore.ts --project="$PROJECT" \
  --database=restore-test --snapshot=<the backup's snapshotTime>
```

Delete the copy straight after, since it is billed while it exists, and check that only `(default)` is left:

```bash
gcloud firestore databases delete --project="$PROJECT" \
  --database=restore-test --quiet
gcloud firestore databases list --project="$PROJECT" --format='value(name)'
```

Repeat before the convention.

### Restore rehearsals

| Date | Project | Backup taken | Restore time | Result |
|---|---|---|---|---|
| Nov 12, 2026 | dev | Nov 12, 14:22 UTC (newest of 9 daily backups, Nov 4–12) | 8 min 33 s | Passed. Counts matched live in every collection (4 events, 3 users, 3 invites, 7 members, 3 expenses, 8 tasks, 15 messages). All 4 events, 3 expenses and 7 members were identical to live, none changed since. No event newer than the backup. `restore-test` was deleted at 19:00 UTC, leaving only `(default)`. |

What the dev rehearsal shows and does not show:

- Restoring is safe for live data: it only ever creates a new database.
- Even a database this small took over 8 minutes, so expect at least that on a full convention.
- The app only reads `(default)`, so a restored copy does not bring the app back by itself. After a real loss, the lost documents have to be copied from the copy into `(default)` with a script. That step has not been written or rehearsed, and should be before the convention. For recent mistakes, point-in-time recovery (on for dev and prod) can read data as it was at any minute of the last 7 days, without a restore.
- Dev holds very little data, so the next rehearsal should use prod once it holds real events.

### Budgets

Budget commands need `--billing-project`. Without it, the error wrongly reads like a permissions problem.

```bash
gcloud billing budgets list \
  --billing-account=01E063-9723F4-06253E --billing-project="$PROJECT"
```

### Uptime check

A healthy `joinEvent` answers an unauthenticated request with 401, and the billing outage returned 500 and 503. The check must send a JSON body, because a POST with no body gets a 400 and would raise false alarms.

```bash
gcloud monitoring uptime create "crewpoint-joinEvent" \
  --project="$PROJECT" \
  --resource-type=uptime-url \
  --resource-labels=host=us-central1-$PROJECT.cloudfunctions.net,project_id=$PROJECT \
  --protocol=https --path=/joinEvent \
  --request-method=post --period=5 \
  --status-codes=401 \
  --content-type=user-provided --custom-content-type=application/json \
  --body='{"data":{}}'
```

Then add an alert policy on the `uptime_check/check_passed` metric, with an email channel, under Monitoring → Alerting.

### Outside billing check

Monitoring lives in the same project that can lose billing, so it may not alert during the very failure it is meant to catch. This check is not set up yet. Run it on a schedule from outside Google Cloud, such as GitHub Actions with a read-only service account, and fail loudly on `False`:

```bash
gcloud billing projects describe "$PROJECT" --format='value(billingEnabled)'
```

### Error alert

Not set up yet. In Monitoring → Alerting, add a log-based policy with this filter, rate limited to one notification per hour:

```text
resource.type="cloud_run_revision" AND severity>=ERROR
```

## Crash reporting

The app reports crashes to Sentry on iOS, Android and web (Req 68), through `ICrashReporter` (`lib/app/core/services/crash_reporter.dart`). One Sentry project serves all three flavors, told apart by environment (`dev`, `stg`, `prod`). Sentry 9 is used, not 10, because 10 needs Android 8.0 and CrewPoint supports Android 7.0.

Reports carry no user identity: no user ID, email, name, IP address or device name, no screenshots or screen content, no request data and no printed logs. Error text and breadcrumbs have emails, phone numbers and long IDs masked, and the screen is sent as a route with IDs replaced (`/dashboard/event/:id/tasks`). The rules are in `crash_scrub.dart` and `scrubEvent`, with tests.

### Setting it up

1. Create a free Sentry organisation and a **Flutter** project.
2. In the project's **Settings → Security & Privacy**, turn on **Data Scrubber**, **Use Default Scrubbers** and **Prevent Storing of IP Addresses**. Crashes inside the iOS and Android native code are sent by Sentry's native SDKs and do not pass through the app's scrubbing, so these settings cover them.
3. Copy the DSN from **Settings → Client Keys (DSN)** into `.env.dev` (and later `.env.stg`, `.env.prod`):

   ```bash
   SENTRY_DSN=https://<key>@<org>.ingest.sentry.io/<project>
   ```

   The DSN only allows sending reports, so it is not a secret, but `.env.*` files stay out of git.
4. Builds pick it up through `--dart-define-from-file=.env.dev`. With no DSN, nothing is sent.

### Checking that reports arrive

Debug builds send nothing unless `--dart-define=SENTRY_DEBUG=true` is added, so everyday development does not fill the dashboard. On a dev build, open **Profile → Dev Tools → Crash reporting**:

- **Send test report** sends a handled `StateError` and shows its ID.
- **Throw test error** throws an uncaught error, which tests the automatic capture.

```bash
flutter run --flavor dev -t lib/main.dart --dart-define-from-file=.env.dev \
  --dart-define=FLAVOR=dev --dart-define=SENTRY_DEBUG=true
```

Then find the report in Sentry under the `dev` environment, and check that it shows no user and no email.

Debug symbol uploads, which make release stack traces readable, are not set up yet.

## During the event

Name a primary and a backup person. During Jul 16–19, 2027, alerts should reach someone at the event by phone.
