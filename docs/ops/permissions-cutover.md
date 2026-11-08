# Permissions cutover runbook (#66)

Moves a project from the `memberIds` and `adminIds` arrays to member documents and permissions (Req 34). Run it on `crewpoint-dev` first, then `crewpoint-stg`.

**Prod waits for the lawyer's approval of the privacy policy (Req 39). Do not run any step against `crewpoint-prod`.**

The arrays are kept throughout. Removing them is a separate, later step, listed in `ai_specs/todo.md`.

## Before you start

- You need Application Default Credentials for the project: `gcloud auth application-default login`.
- Billing must be linked. Callables and deploys fail without it.
- The local router sometimes returns SERVFAIL for `*.googleapis.com`. If `firebase` or `gcloud` reports "Failed to make request" or `ENOTFOUND`, check with `dig` and run the step again.

```bash
export PROJECT=crewpoint-dev   # then crewpoint-stg
cd functions
```

## Steps

### 1. Confirm a fresh backup

Daily backups are on (see `backups-and-alerts.md`). Confirm one exists from today, or take one now, and write down its name:

```bash
gcloud firestore backups list --project="$PROJECT" --format='value(name,snapshotTime)'
```

### 2. Dry run, then the migration

The migration keeps the arrays, and is safe to run again.

```bash
npx tsx scripts/migrateToMembers.ts --project="$PROJECT"           # dry run
npx tsx scripts/migrateToMembers.ts --project="$PROJECT" --write   # migrate
```

The report gives counts for each change:

| Field | Meaning |
|---|---|
| `memberDocs` | Member documents created |
| `statuses` | Older `active` statuses mapped |
| `memberCounts` | `memberCount` corrected |
| `involvedUids` | Older expenses given `involvedUids` |
| `dates` | Event dates converted to date-only |
| `unknownZones` | Events whose dates were left alone because no zone was known |
| `taskBudgets` | Task budget figures moved to `taskBudgets` (#71) |
| `profiles` | Names and payment handles copied into each event's `profiles`, with names only for people who left (#71) |

A project migrated before #71 needs the script run again before the #71 rules go out. Until then, budget figures stay on tasks, and the rules that close `users/{uid}` would leave names blank.

Check each `unknownZones` event's dates by hand.

### 3. Deploy functions and rules together

Functions first, then rules and indexes, so the callables exist before the rules depend on them:

```bash
cd ..
firebase deploy --only functions --project "$PROJECT"
firebase deploy --only firestore:rules,firestore:indexes --project "$PROJECT"
```

The `members.uid` collection-group index can take a few minutes to build. Until it's ready, "My events" fails to load.

### 4. Release the app and raise the minimum version

Release the app build that includes #66. Then set `config/app.minVersion` to its version in the Firebase console, so older builds show the upgrade screen. Optionally set `storeUrls.ios` and `storeUrls.android` too.

### 5. Run the verification script

```bash
cd functions
npx tsx scripts/verifyMembers.ts --project="$PROJECT"
```

It exits with 1 and lists every mismatch it finds. Running the migration again creates any missing member documents. Other mismatches need a look by hand.

### 6. Record the result

Add a row to the log below, with the date, the project, the backup's name, both reports and the verification result.

## Rollback

This works until the arrays are removed, because every membership change still writes them.

1. Redeploy the previous functions and rules:

   ```bash
   git checkout <commit before #117>
   firebase deploy --only functions --project "$PROJECT"
   firebase deploy --only firestore:rules --project "$PROJECT"
   ```

2. Lower `config/app.minVersion` back to the earlier build.

Member documents can stay, since the previous rules ignore them. `functions/test/scripts/rollback.test.ts` checks that the previous rules, saved in `functions/test/fixtures/firestore.pre-cutover.rules`, still give everyone the same access after the migration.

## Log

| Date | Project | Backup | Migration report | Verification | By |
|---|---|---|---|---|---|
| 2026-11-06 | crewpoint-dev | `6b14dc14-7fd6-47cb-b27d-2119732bb278` (daily, 13:33 UTC that day) | 4 events: 7 member documents, 4 statuses, 4 counts, 3 `involvedUids`, 0 dates; 3 `unknownZones` (`447b2540`, `7d0029d6`, `abfab18f`, dates at midnight US Central, left as they are). A second dry run found nothing left. | Every event matches, before and after deploying. Functions (commit `588377f`) then rules and indexes deployed; `onTaskAssigned` needed one retry after a Google 500. Minimum version not raised yet. | Claude, approved by the owner |
