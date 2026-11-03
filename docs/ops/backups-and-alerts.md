# Backups and alerts: proposed setup

**Status: proposal, nothing here has been run.** Each step changes a live project or costs money, so the owner approves it first. Try each one on `crewpoint-dev`, then repeat on stg and prod.

## Why

Checked on Nov 2–3, 2026:

| Protection | dev | prod |
|---|---|---|
| Firestore backup schedules | None | None |
| Point-in-time recovery | Off | Off |
| Monitoring alert policies | None | None |

Budgets could not be checked, because the login used has no access to the billing account.

Deleted or corrupted Firestore data cannot be recovered today. Billing was also disabled on all three projects until Nov 2, and every Cloud Function failed without anyone being told.

## 1. Backups

Set the project first:

```bash
PROJECT=crewpoint-dev
```

**Daily backups, kept for 14 days:**

```bash
gcloud firestore backups schedules create \
  --project="$PROJECT" --database='(default)' \
  --recurrence=daily --retention=14d
```

**Point-in-time recovery** lets you restore to a recent moment, which helps after a bad deploy or accidental delete:

```bash
gcloud firestore databases update \
  --project="$PROJECT" --database='(default)' --enable-pitr
```

Both add storage cost, so check current Firestore pricing first. For stg, backups alone are probably enough.

### Rehearse a restore

A backup that has never been restored is unproven. Restore into a **new** database, so live data is untouched:

```bash
gcloud firestore backups list --project="$PROJECT" --format='value(name)'

gcloud firestore databases restore \
  --project="$PROJECT" \
  --source-backup=<backup name from the list above> \
  --destination-database=restore-test
```

Check that events and expenses are there, then delete `restore-test`. Repeat before the convention.

## 2. Budget alerts

Find the account ID in the Cloud Console under Billing. The login needs billing access.

```bash
gcloud billing budgets create \
  --billing-account=<ACCOUNT_ID> \
  --display-name="CrewPoint monthly" \
  --budget-amount=<AMOUNT>USD \
  --threshold-rule=percent=0.5 \
  --threshold-rule=percent=0.9 \
  --threshold-rule=percent=1.0,basis=forecasted-spend
```

Budgets only send alerts; they do not cap spending. By default they email the billing account's admins, so confirm those people read that inbox.

## 3. Alert when the backend is down

A budget alert will not fire when billing is disabled, because spending just stops. Use two independent checks.

**Uptime check.** A healthy `joinEvent` answers an unauthenticated request with 401, while the billing outage returned 500 and 503:

```bash
gcloud monitoring uptime create "crewpoint-joinEvent" \
  --project="$PROJECT" \
  --resource-type=uptime-url \
  --resource-labels=host=us-central1-$PROJECT.cloudfunctions.net,project_id=$PROJECT \
  --protocol=https --path=/joinEvent \
  --request-method=post --period=5 \
  --status-codes=401
```

Then add an alert policy on the check, with an email or SMS channel, in the Cloud Console under Monitoring → Alerting.

**Outside check.** Monitoring lives in the same project that lost billing, so it may not alert during the very failure it is meant to catch. Run this on a schedule from somewhere outside Google Cloud, such as GitHub Actions, and fail loudly on `False`:

```bash
gcloud billing projects describe "$PROJECT" --format='value(billingEnabled)'
```

**Error alert.** In Monitoring → Alerting, add a log-based policy with this filter, rate limited to one notification per hour:

```text
resource.type="cloud_run_revision" AND severity>=ERROR
```

## 4. Who gets alerted

Name a primary and a backup person before turning these on. During Jul 16–19, 2027, alerts should reach someone at the event by phone.

## Decisions needed

- [ ] Backup retention: 14 days proposed
- [ ] Point-in-time recovery on prod and dev: proposed yes; stg no
- [ ] Monthly budget amount
- [ ] Alert recipients, primary and backup
- [ ] Where the outside billing check runs: GitHub Actions proposed, which needs a read-only service account
