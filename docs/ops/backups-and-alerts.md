# Backups and alerts

Set up on Nov 3, 2026, after a billing lapse took down every Cloud Function on Nov 2 with nobody told, and when deleted Firestore data could not have been recovered.

## Current state

| Protection | dev | stg | prod |
|---|---|---|---|
| Daily backups, kept 14 days | On | On | On |
| Point-in-time recovery | On | Off | On |
| `joinEvent` uptime check with email alert | On | Off | On |
| Crash reporting and backend error alerts | Off | Off | Off |

Monthly budgets on the billing account, covering all three projects:

- **CrewPoint monthly, $5:** emails derodian@gmail.com and admin@sookoon.space through the dev notification channels.
- **$15 Monthly Budget Alert:** emails the billing account's admins.

Budgets only send alerts; they do not cap spending.

**Still to do:**

- [ ] Rehearse a restore. No backup has been restored yet.
- [ ] Run an outside billing check, as described below.
- [ ] Confirm an alert actually reaches both inboxes.
- [ ] Add crash reporting and backend error alerts.

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
gcloud firestore backups list --project="$PROJECT" --format='value(name)'

gcloud firestore databases restore \
  --project="$PROJECT" \
  --source-backup=<backup name from the list above> \
  --destination-database=restore-test
```

Check that events and expenses are there, then delete `restore-test`. Repeat before the convention.

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

## During the event

Name a primary and a backup person. During Jul 16–19, 2027, alerts should reach someone at the event by phone.
