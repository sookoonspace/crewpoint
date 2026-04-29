# CrewPoint web hosting guide

End-to-end walkthrough for shipping the Flutter web build to Firebase
Hosting on the **`crewpoint.sookoon.space`** subdomain (prod) — and the
parallel dev / staging subdomains for pre-production smokes — without
disturbing the Sookoon LLC marketing site that lives at the apex on
Namecheap.

> **Hosting topology.** This guide owns the Firebase-hosted subdomain
> only. The apex `https://sookoon.space` (Next.js + Namecheap shared
> hosting via FTP/cPanel; see `/Users/googoo/Websites/sookoon_space`)
> is **not** changed by anything in this guide. The `/crewpoint/`
> microsite that links into the web app lives in the marketing repo
> and ships separately (Phase 5 of `ai_specs/web-admin-reporting-spec.md`).

For the dev-only loop (faster iteration, no custom domain) see
**[firebase-hosting-dev-deploy.md](./firebase-hosting-dev-deploy.md)**.
This guide builds on top of that and adds the production/custom-domain
steps.

## Subdomain map

| Flavor | Firebase project   | Hosting site ID  | Public URL                          |
| ------ | ------------------ | ---------------- | ----------------------------------- |
| dev    | `crewpoint-dev`    | `crewpoint-dev`  | `crewpoint-dev.web.app` (default)   |
| stg    | `crewpoint-stg`    | `crewpoint-stg`  | `crewpoint-stg.web.app` (default)   |
| prod   | `crewpoint-prod`   | `crewpoint-prod` | **`crewpoint.sookoon.space`** (custom) |

Production is the only flavor with a custom domain in V1; dev and stg
ship on Firebase's `*.web.app` defaults to keep DNS simple.

## Stage 0 — Prerequisites

- Firebase CLI authenticated: `firebase login`.
- `flutterfire configure` has populated `lib/firebase_options_*.dart` for
  all three flavors. The `web` block is already present in each;
  re-running interactively is documented in
  **[flutterfire-reconfigure.md](./flutterfire-reconfigure.md)** (Path A
  is the safer default).
- `firebase.json` `hosting` array (this PR) already lists all three
  targets with flavor-aware predeploy hooks.
- `.firebaserc` registers the project aliases and target mappings.
- Local `flutter build web --release --dart-define=FLAVOR=<flavor>`
  succeeds.

## Stage 1 — Provision the Hosting site

Each Firebase project comes with a default Hosting site named after
the project ID. Confirm it exists for each flavor; create it if it
doesn't.

```bash
firebase hosting:sites:list --project=crewpoint-prod    # similarly for stg
# Expect a row with Site ID = crewpoint-prod.

# If the table is empty:
firebase hosting:sites:create crewpoint-prod --project=crewpoint-prod
```

## Stage 2 — Bind the hosting target

The plan's `.firebaserc` already maps the logical target name to the
site ID. Idempotently re-apply on every fresh checkout:

```bash
firebase target:apply hosting crewpoint-prod crewpoint-prod \
  --project=crewpoint-prod
firebase target:apply hosting crewpoint-stg  crewpoint-stg  \
  --project=crewpoint-stg
firebase target:apply hosting crewpoint-dev  crewpoint-dev  \
  --project=crewpoint-dev
```

> ⚠️ **Run each `target:apply` on a single line.** Backslash-continued
> multi-line invocations get mangled by some shells and bind a
> non-existent "site name" of ` --project=<flavor>` to the target.
> `.firebaserc` ends up with two entries under one target and
> `firebase deploy` refuses to ship.

## Stage 3 — Deploy

For dev (no custom domain), the predeploy hook handles the build:

```bash
firebase deploy --only hosting:crewpoint-dev --project=crewpoint-dev
```

For stg (no custom domain yet, default Firebase URL):

```bash
firebase deploy --only hosting:crewpoint-stg --project=crewpoint-stg
```

For prod, the same command + the custom-domain configuration in
Stage 4 below resolves to `https://crewpoint.sookoon.space` once DNS
propagates.

```bash
firebase deploy --only hosting:crewpoint-prod --project=crewpoint-prod
```

## Stage 4 — Custom domain (`crewpoint.sookoon.space`)

Done once per environment. Production only in V1.

### Stage 4a — Connect in Firebase Console

1. Firebase Console → `crewpoint-prod` → **Hosting** → site
   `crewpoint-prod` → **Add custom domain**.
2. Enter `crewpoint.sookoon.space`. Skip the "redirect" / "advanced"
   options — we're not going through `www.` and we're not redirecting
   between subdomains.
3. Firebase will display either:
   - a **CNAME** record pointing at `crewpoint-prod.web.app` (most
     common), or
   - a pair of **A** records pointing at Google's IPs.

### Stage 4b — Add the DNS record at Namecheap

The Sookoon LLC apex DNS lives at Namecheap. We add a record for the
subdomain only — the apex `sookoon.space` A/AAAA records are
unchanged.

1. Namecheap dashboard → Domain List → `sookoon.space` → **Manage** →
   **Advanced DNS**.
2. **Add new record**:
   - Type: **CNAME** (or **A** if Firebase asked for that)
   - Host: `crewpoint`
   - Value: the value Firebase gave you (e.g. `crewpoint-prod.web.app.`)
   - TTL: **Automatic** is fine.
3. Save.
4. **Do not touch** the existing apex `@` records or any record for
   `www`, `sanctuary`, `mail`, etc. — those belong to the Sookoon
   marketing site.

Propagation: usually under 10 minutes; up to a few hours worst case.
Refresh the Firebase Hosting custom-domain page until both
**Pending DNS verification** and **Pending SSL** flip to **Connected**.
SSL provisioning is automatic via Let's Encrypt.

### Stage 4c — Smoke

```bash
curl -I https://crewpoint.sookoon.space/   # 200 + valid SSL
curl -I https://sookoon.space/             # apex unchanged, served by Namecheap
```

Open `https://crewpoint.sookoon.space` in incognito Chrome at width
≥ 720 px and confirm the side rail renders.

## Stage 5 — Storage CORS allow-list

Cloud Storage cross-origin reads (receipt thumbnails, profile pictures)
fail by default from any origin that isn't the Firebase web app's
own. Apply the narrow allow-list once per flavor:

```bash
gcloud auth login
gcloud config set project crewpoint-prod   # one of dev / stg / prod
scripts/apply-cors.sh prod                 # or: dev / stg / all
```

The payload is `infra/storage-cors.json`:

```json
[
  {
    "origin": ["https://crewpoint.sookoon.space"],
    "method": ["GET", "HEAD"],
    "responseHeader": ["Content-Type", "Cache-Control", "Content-Length"],
    "maxAgeSeconds": 3600
  }
]
```

Key decisions:

- **Subdomain only.** The Sookoon marketing apex isn't in the list —
  it never fetches Storage assets directly, only deep-links into the
  web app.
- **No `localhost` entry.** Local dev runs against the Firebase
  emulator suite which is permissive by default; adding `localhost`
  here would expose the dev bucket more than necessary.
- **Re-run after edits.** Editing the JSON requires re-running the
  script. `gsutil cors get gs://crewpoint-<flavor>.firebasestorage.app`
  shows the active rules.

The script is idempotent — re-running with the same payload is safe.

## Stage 6 — `authDomain` decision (V1)

`lib/firebase_options_prod.dart`'s `authDomain` field controls the
hostname the OAuth popup shows and the redirect target after
authentication. V1 leaves this at the default
`crewpoint-prod.firebaseapp.com`. Trade-offs:

| Choice | OAuth popup shows | Setup complexity |
| --- | --- | --- |
| **`crewpoint-prod.firebaseapp.com`** (default, V1) | `firebaseapp.com` hostname | None — works out of the box. |
| `crewpoint.sookoon.space` (V2 white-label) | matches your brand domain | Requires the subdomain to be a Firebase Hosting site **first**, plus adding it to Firebase Auth → Authorized Domains. Apple sign-in's Services ID return URL must match. |

The white-label upgrade is tracked under "future enhancements" — not
in scope for this spec. Leaving the default keeps Apple Services ID
configuration simpler in Phase 6.

## Stage 7 — Apple sign-in domain verification

Phase 6 adds Apple sign-in. The Apple Developer Console requires
Apple to fetch a verification file Apple itself issues. The placeholder
is committed at:

```
web/.well-known/apple-developer-domain-association.txt
```

When you reach Phase 6:

1. Create the Services ID `com.sookoonspace.crewpoint.web` in the Apple
   Developer Console.
2. Configure → Sign in with Apple → Domain Verification → add
   `crewpoint.sookoon.space`.
3. Apple provides a text payload. Replace the placeholder file's
   contents with that payload.
4. `firebase deploy --only hosting:crewpoint-prod`.
5. Apple console verification flips to **Verified**.

**Post-deploy guard** (run before public launch):

```bash
curl -fsSL \
  https://crewpoint.sookoon.space/.well-known/apple-developer-domain-association.txt \
  | grep -q PLACEHOLDER \
  && echo 'NOT REPLACED — block public launch'
```

The grep should fail (exit 1) once the real payload is in place. If it
succeeds, the placeholder shipped and Apple sign-in won't round-trip.

## Stage 8 — Rollback

Firebase Hosting keeps every release. To roll back:

1. Firebase Console → Hosting → site `crewpoint-prod` → **Release
   history**.
2. Find the last known-good release.
3. **Rollback** (three-dot menu).

CLI equivalent:

```bash
firebase hosting:clone \
  crewpoint-prod:<good-version-id> \
  crewpoint-prod:live \
  --project=crewpoint-prod
```

The custom domain follows the active release automatically — no DNS
change needed.

## Cross-references

- `firebase.json` — `hosting[]` array (all three flavors).
- `.firebaserc` — project aliases + target bindings.
- `infra/storage-cors.json` — allow-list payload.
- `scripts/apply-cors.sh` — flavor-aware CORS apply wrapper.
- `web/.well-known/apple-developer-domain-association.txt` — Apple
  domain-verification placeholder.
- `docs/firebase-hosting-dev-deploy.md` — dev-only deploy loop.
- `docs/flutterfire-reconfigure.md` — when (and how) to refresh
  `firebase_options_*.dart` without breaking iOS/Android.
- `docs/cloud-functions-guide.md` — Cloud Functions deploy lifecycle
  (sibling concern; deploys are independent of hosting).
- `ai_specs/web-admin-reporting-plan.md` — Phase 4 (this work),
  Phase 5 (marketing microsite), Phase 6 (Apple sign-in).
