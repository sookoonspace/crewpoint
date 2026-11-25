# App Check and the public event page (#240)

The public event page (`/e/:eventSlug`) is open to anyone, so its callable,
`getEventPage`, requires Firebase App Check and limits each address to
about 60 opens a minute (Spec #233 Req 13a). The emulators skip App Check,
so no test needs a token.

## Before the first deploy to a project

Do these once per project (dev first). Until they are done, deployed
`getEventPage` refuses every call and the event page shows its error.

1. **Web (reCAPTCHA Enterprise).** In the Google Cloud console for the
   project, create a reCAPTCHA Enterprise *website* key for the Hosting
   domains (`crewpoint-dev.web.app`, `crewpoint-dev.firebaseapp.com`, and
   any custom domain). In the Firebase console, App Check → Apps → the web
   app, register it with that key. Put the site key in `.env.<flavor>`:

   ```
   APP_CHECK_WEB_KEY=<site key>
   ```

   It is not a secret; every browser receives it. Without it the app does
   not start App Check on the web (`AppCheckStarter`).
2. **Android (Play Integrity).** App Check → Apps → the Android app →
   Play Integrity, with the app's SHA-256 fingerprint.
3. **iOS (App Attest, falling back to DeviceCheck).** App Check → Apps →
   the iOS app → App Attest, and add the App Attest capability to the
   Runner target.
4. **Debug builds** use the debug providers. Each device prints a debug
   token on first run; add it under App Check → Apps → Manage debug tokens.
5. **Do not turn on enforcement for other products** (Firestore, Storage)
   here. Only `getEventPage` enforces App Check, in its own options.

## Rate-limit counts

Counts live in `rateLimits/{bucket}_{hash}_{window}` (no client access; the
address is hashed, never stored). Each has `expiresAt`, and the TTL policy
that deletes old counts is a field override in `firestore.indexes.json`
(`rateLimits.expiresAt`, `"ttl": true`, not indexed), so it goes live on
each project with `firebase deploy --only firestore:indexes`. Don't set it
with gcloud instead: an index deploy would then find a setting the file
doesn't list. Check it with:

```
gcloud firestore fields ttls list --project=crewpoint-dev
```

## The server-rendered first page

Hosting sends `/e/**` to the `eventPageHtml` function (`firebase.json`,
before the catch-all rewrite), so **deploy functions before Hosting**: a
Hosting rewrite to a function that does not exist yet fails the deploy.

- `/e/:slug` returns a small page with the title, dates, place, a Register
  link and link-preview tags (`og:title`, `og:description`, `og:image`),
  then loads `flutter_bootstrap.js`. The app removes the `#cp-ssr` block
  once it shows the event. A draft, an unknown name or a busy address gets
  the plain app shell with `noindex`.
- `/e/:slug/cover.jpg` serves the event's cover photo for link previews,
  never a draft's.
- Pages are cached at the edge for 60 seconds (`s-maxage=60`), covers for
  an hour.
