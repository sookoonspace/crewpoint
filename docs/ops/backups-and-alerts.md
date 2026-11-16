# Backups and alerts

Set up on Nov 3, 2026, after a billing lapse took down every Cloud Function on Nov 2 with nobody told, and when deleted Firestore data could not have been recovered.

## Current state

| Protection | dev | stg | prod |
|---|---|---|---|
| Daily backups, kept 14 days | On | On | On |
| Point-in-time recovery | On | Off | On |
| `joinEvent` uptime check with email alert | On | Off | On |
| Crash reporting (Sentry, app builds with a `SENTRY_DSN`) | On | Off | Off |
| Backend error alerts, emailing both addresses | On | Off | On |
| Outside billing check (GitHub Actions, hourly) | On | On | On |

Monthly budgets on the billing account, covering all three projects:

- **CrewPoint monthly, $5:** emails derodian@gmail.com and admin@sookoon.space through the dev notification channels.
- **$15 Monthly Budget Alert:** emails the billing account's admins.

Budgets only send alerts; they do not cap spending.

**Still to do:**

- [x] Rehearse a restore. Done on dev on Nov 12, 2026; see [Restore rehearsals](#restore-rehearsals).
- [ ] Rehearse a restore again on prod data before the convention, when prod holds real events.
- [ ] Write and rehearse a script that copies lost documents from a restored copy back into `(default)`.
- [x] Run an outside billing check (#93). Hourly from GitHub Actions; see [Outside billing check](#outside-billing-check).
- [ ] Confirm an alert actually reaches both inboxes.
- [x] Add crash reporting on dev (#92). Confirmed on Nov 16, 2026; see [Checking that reports arrive](#checking-that-reports-arrive).
- [ ] Turn crash reporting on for stg and prod by adding the same `SENTRY_DSN` to `.env.stg` and `.env.prod`.
- [x] Add backend error alerts on dev and prod (#93); see [Error alert](#error-alert).
- [ ] Look into the `onTaskDueScheduled` scheduler run on prod that failed with `INTERNAL` on Nov 6, 2026, found while testing the error alert's filter.

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

Monitoring lives in the same projects that can lose billing, so it may not alert during the very failure it is meant to catch. So `.github/workflows/billing-check.yml` checks from GitHub Actions, every hour at 17 past, that billing is on for dev, stg and prod. If any project has billing off, or the check cannot sign in or read it, the run fails and emails derodian@gmail.com and admin@sookoon.space through Gmail.

How it is set up:

- **Service account:** `billing-check@crewpoint-dev.iam.gserviceaccount.com`, with only the Browser role (`roles/browser`) on each of the three projects. That is enough to read whether billing is on and nothing more.
- **Sign-in without a key:** GitHub Actions signs in through Workload Identity Federation: pool `github`, provider `crewpoint-repo` in crewpoint-dev. The provider accepts only tokens from `sookoonspace/crewpoint` on `refs/heads/main`, so a fork or another branch cannot use it.
- **Email:** the repo secrets `ALERT_GMAIL_ADDRESS` (a Gmail address) and `ALERT_GMAIL_APP_PASSWORD` (an app password for it, from Google Account → Security → App passwords). The workflow sends the mail with `curl`, so the password is not handed to third-party action code. Without both secrets the run still fails, and GitHub emails the repo owner instead.

To set the secrets, run these yourself; each prompts for the value:

```bash
gh secret set ALERT_GMAIL_ADDRESS
gh secret set ALERT_GMAIL_APP_PASSWORD
```

To test the email, run the workflow by hand from main with **simulate_failure** ticked. It still checks the real projects, then fails on purpose and sends an email whose subject says it is a test:

```bash
gh workflow run billing-check.yml -f simulate_failure=true
```

Things to know:

- GitHub turns off scheduled workflows in a public repo after 60 days with no commits. If the repo goes quiet, re-enable it under Actions → Billing check.
- GitHub may start a scheduled run several minutes late.
- The same check by hand:

  ```bash
  gcloud billing projects describe "$PROJECT" --format='value(billingEnabled)'
  ```

How the service account and sign-in were made (on crewpoint-dev, project number 711822236757):

```bash
gcloud iam service-accounts create billing-check --project=crewpoint-dev
for P in crewpoint-dev crewpoint-stg crewpoint-prod; do
  gcloud projects add-iam-policy-binding "$P" --condition=None \
    --member=serviceAccount:billing-check@crewpoint-dev.iam.gserviceaccount.com \
    --role=roles/browser
done
gcloud services enable sts.googleapis.com --project=crewpoint-dev
gcloud iam workload-identity-pools create github \
  --project=crewpoint-dev --location=global
gcloud iam workload-identity-pools providers create-oidc crewpoint-repo \
  --project=crewpoint-dev --location=global --workload-identity-pool=github \
  --issuer-uri=https://token.actions.githubusercontent.com \
  --attribute-mapping='google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.ref=assertion.ref' \
  --attribute-condition="assertion.repository=='sookoonspace/crewpoint' && assertion.ref=='refs/heads/main'"
gcloud iam service-accounts add-iam-policy-binding \
  billing-check@crewpoint-dev.iam.gserviceaccount.com --project=crewpoint-dev \
  --role=roles/iam.workloadIdentityUser \
  --member=principalSet://iam.googleapis.com/projects/711822236757/locations/global/workloadIdentityPools/github/attribute.repository/sookoonspace/crewpoint
```

### Error alert

Dev and prod each have the alert policy **CrewPoint backend errors**, emailing derodian@gmail.com and admin@sookoon.space through the project's existing email channels. It fires when a Cloud Function or scheduled job logs an error, at most one email an hour, and closes itself after 30 minutes without another:

```text
severity>=ERROR
AND resource.type=("cloud_run_revision" OR "cloud_function" OR "cloud_scheduler_job")
AND NOT textPayload:"Invalid request, unable to process."
```

The last line skips what a callable logs when something other than the app calls it, such as a browser `GET` on its URL. Those made up most errors in the logs. Checked against the 30 days before Nov 16, 2026, the filter matched only real failures: the Nov 2 billing outage on both projects, two test failures and an `onTaskAssigned` crash on dev, and a failed `onTaskDueScheduled` run on prod.

The policies were created through the Monitoring API (`POST https://monitoring.googleapis.com/v3/projects/$PROJECT/alertPolicies`) with a `conditionMatchedLog` condition, `notificationRateLimit` of 3600s and `autoClose` of 1800s. To list them:

```bash
gcloud monitoring policies list --project="$PROJECT" \
  --format='table(displayName,enabled)'
```

To test one, write a clearly marked error into the project's logs; the email arrives within a few minutes:

```bash
curl -X POST -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "x-goog-user-project: $PROJECT" -H 'Content-Type: application/json' \
  https://logging.googleapis.com/v2/entries:write -d '{
    "logName": "projects/'"$PROJECT"'/logs/alert-test",
    "resource": {"type": "cloud_run_revision", "labels": {"project_id": "'"$PROJECT"'",
      "service_name": "alert-test", "revision_name": "alert-test-00001",
      "location": "us-central1", "configuration_name": "alert-test"}},
    "entries": [{"severity": "ERROR", "textPayload": "TEST of the backend error alert. Nothing is wrong."}]}'
```

### Alert tests

| Date | Alert | Result |
|---|---|---|

## Crash reporting

The app reports crashes to Sentry on iOS, Android and web (Req 68), through `ICrashReporter` (`lib/app/core/services/crash_reporter.dart`). The Sentry organisation is `sookoon-llc` and the project `desk`. One project serves all three flavors, told apart by environment (`dev`, `stg`, `prod`). Sentry 9 is used, not 10, because 10 needs Android 8.0 and CrewPoint supports Android 7.0.

Reports carry no user identity: no user ID, email, name, IP address, location, per-device ID (`device_app_hash`) or device name, no screenshots or screen content, no request data and no printed logs. Error text and breadcrumbs have emails, phone numbers and long IDs masked, and the screen is sent as a route with IDs replaced (`/dashboard/event/:id/tasks`). The rules are in `crash_scrub.dart` and `scrubEvent`, with tests.

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

On web, Sentry 9 loads its JavaScript SDK from `browser.sentry-cdn.com` and sends every report through it. That SDK also reports uncaught browser errors on its own, without the app's scrubbing. So on web `main` runs inside a zone (`runWithCrashReporting`) that catches uncaught Dart errors and reports them through the scrubbing, and `dropUnscrubbedWebReports` makes the JavaScript SDK drop anything it catches itself. Errors raised outside Dart, in the browser or its scripts, are therefore not reported on web.

Sentry works out a sender's town from their connection whenever a report has no IP address, even with IP storage turned off. So every report carries the placeholder IP `0.0.0.0`, which leaves nothing to look up, and the project's IP setting then discards it.

| Date | Build | Result |
|---|---|---|
| Nov 16, 2026 | dev, iOS simulator, debug with `SENTRY_DEBUG=true` | A handled report and an uncaught error both arrived under `dev`. Error text read `<email>`, `<phone>` and `<id>`, the route `/dashboard/event/:id/people/:id`, with 0 users. The first round still carried a town worked out from the connection and the per-device ID; both were removed, and a third round showed no location, no device ID and no IP. |
| Nov 16, 2026 | dev, Android emulator (Pixel 7 Pro), debug | Both arrived scrubbed, with no location or device ID. |
| Nov 16, 2026 | dev, web release in Chrome | The handled report arrived scrubbed, but the uncaught error arrived **unscrubbed**, with the test email and a town in it: on web, Sentry's JavaScript SDK reports uncaught browser errors itself, skipping the app's scrubbing. Fixed (see below), and the next run sent both scrubbed, with no location, and nothing from the JavaScript SDK. |

Debug symbol uploads, which make release stack traces readable, are not set up yet.

## During the event

Name a primary and a backup person. During Jul 16–19, 2027, alerts should reach someone at the event by phone.
