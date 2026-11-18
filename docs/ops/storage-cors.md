# Storage CORS for the web app

The web app reads Storage files from the browser: receipt thumbnails, profile pictures and, since Spec #186 (#198), event cover photos. These reads use the Firebase SDK's `getData`, so they need the bucket to allow the app's own origin. Without it, covers show the fallback icon on the web, while phones are unaffected.

This is a one-time setting per Firebase project. Re-run it only after editing an allow-list or recreating a bucket.

| Flavor | Bucket | Allowed origins (`infra/storage-cors.<flavor>.json`) |
|---|---|---|
| dev | `gs://crewpoint-dev.firebasestorage.app` | `https://crewpoint-dev.web.app`, `https://crewpoint-dev.firebaseapp.com` |
| stg | `gs://crewpoint-stg.firebasestorage.app` | `https://crewpoint-stg.web.app`, `https://crewpoint-stg.firebaseapp.com` |
| prod | `gs://crewpoint-prod.firebasestorage.app` | `https://crewpoint.sookoon.space` |

All three allow only `GET` and `HEAD`. Writes go through the SDK's upload, which the Storage rules check.

## Applying

```bash
gcloud auth login
scripts/apply-cors.sh dev        # or stg, prod, all
gsutil cors get gs://crewpoint-dev.firebasestorage.app   # shows what is set
```

The script is idempotent.

## Checking on dev

1. Apply the allow-list to dev, as above.
2. Open `https://crewpoint-dev.web.app`, sign in as someone with `event.manage`, open an event's settings, and choose a cover photo.
3. Reload the event home. The photo shows, with no CORS error in the browser console.
4. Sign in as a plain member of the same event. The photo shows for them too.

## Record

| Flavor | Applied | Checked | By |
|---|---|---|---|
| dev | not yet | not yet | |
| stg | not yet (waits for stg) | | |
| prod | not yet (waits for prod) | | |
