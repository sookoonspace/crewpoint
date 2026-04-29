# Dev-first rollout checklist

This doc captures every action that should run **only after dev is
fully validated** so a single fix can ripple across stg and prod
together — instead of repeating the same fix three times across
flavors.

**The rule**: dev hosting must serve a working build to a real browser
with side-rail rendering, sign-in working, and PDF/CSV export
downloading before any stg or prod step on this list runs.

## Gating signal — "dev is validated"

All of these must be true on `https://crewpoint-dev.web.app` (or
whatever Firebase default URL the dev Hosting site exposes):

- [ ] Page loads in incognito Chrome with valid SSL.
- [ ] Side rail renders at width ≥ 720px; bottom bar at < 720.
- [ ] Email + Google sign-in round-trip works on web; lands on
      Dashboard.
- [ ] Dashboard event list renders for the signed-in user.
- [ ] Open Budget on a public event with one receipt: thumbnail
      loads, browser console shows zero CORS errors *(requires*
      `scripts/apply-cors.sh dev` *to have run once)*.
- [ ] "Export PDF" on Budget downloads a slugified `.pdf` that opens
      in a PDF reader.
- [ ] "Export CSV" on Budget downloads a slugified `.csv` that opens
      in Excel / Google Sheets with the documented columns.
- [ ] "Export PDF" on Tasks downloads a slugified `.pdf`.
- [ ] No regressions on iOS or Android dev flavor.

Once all of the above hold, treat dev as the source of truth and run
the staging-and-production tasks below in order.

## Staging — once dev is validated

Run each step against the **`crewpoint-stg`** project. Confirm it
matches dev's behavior before moving on to prod.

- [ ] **Web app config**: `flutterfire configure --project=crewpoint-stg`
      OR Path A hand-edit per `docs/flutterfire-reconfigure.md` so
      `firebase.json`'s `flutter.platforms.dart` map registers `web`
      under stg. (The `web` block in `lib/firebase_options_stg.dart`
      already exists — don't regenerate the file blindly.)
- [ ] **Hosting site**: `firebase hosting:sites:list --project=crewpoint-stg`;
      if empty, `firebase hosting:sites:create crewpoint-stg --project=crewpoint-stg`.
- [ ] **Hosting target**: `firebase target:apply hosting crewpoint-stg crewpoint-stg --project=crewpoint-stg`
      (single line — see `web-hosting-guide.md` Stage 2 warning).
- [ ] **CORS**: `gcloud config set project crewpoint-stg && scripts/apply-cors.sh stg`.
- [ ] **Deploy**: `firebase deploy --only hosting:crewpoint-stg --project=crewpoint-stg`.
      Predeploy auto-runs `flutter build web --release --dart-define=FLAVOR=stg`.
- [ ] **Smoke**: open `https://crewpoint-stg.web.app` in incognito; run
      the same gating-signal list above; confirm zero CORS errors.

If any smoke step fails on stg, fix it on dev first, re-deploy dev,
re-run dev smoke, then re-attempt stg. **Don't band-aid stg only.**

## Production — once stg is validated

Only proceed when stg matches dev's behavior end-to-end.

- [ ] **Web app config**: same `flutterfire configure` / Path A hand-edit
      step for `crewpoint-prod` (its `web` block also already exists).
- [ ] **Hosting site**: `firebase hosting:sites:list --project=crewpoint-prod`;
      create if missing.
- [ ] **Hosting target**: `firebase target:apply hosting crewpoint-prod crewpoint-prod --project=crewpoint-prod`.
- [ ] **CORS**: `gcloud config set project crewpoint-prod && scripts/apply-cors.sh prod`.
- [ ] **Custom domain (`crewpoint.sookoon.space`)**:
      Firebase Console → Hosting → custom domain wizard. Apple /
      Namecheap CNAME at the subdomain only — apex stays untouched.
      See `web-hosting-guide.md` Stage 4.
- [ ] **DNS propagation + SSL**: wait for "Connected" in the Firebase
      console. Verify with `curl -I https://crewpoint.sookoon.space/`.
- [ ] **Apex unchanged**: `curl -I https://sookoon.space/` still
      returns the Namecheap-served marketing site.
- [ ] **Deploy**: `firebase deploy --only hosting:crewpoint-prod --project=crewpoint-prod`.
- [ ] **Marketing microsite live**: the cross-repo `sookoon_space` PR
      with `/crewpoint/` routes is merged and deployed via Namecheap
      FTP per `DEPLOY_NAMECHEAP.md`.
- [ ] **Privacy + terms reachable**: `curl https://sookoon.space/crewpoint/privacy/`
      returns the live policy page (gates Apple sign-in setup).
- [ ] **Apple Services ID + domain verification** (Phase 6 of the
      web-admin-reporting plan): replace
      `web/.well-known/apple-developer-domain-association.txt`
      placeholder with the Apple-issued payload, deploy, verify in
      Apple console.
- [ ] **Apple sign-in round-trip**: incognito → "Sign in with Apple"
      → completes → returns to dashboard with a fresh `users/{uid}`
      Firestore doc.
- [ ] **Post-deploy guard**: `curl -fsSL https://crewpoint.sookoon.space/.well-known/apple-developer-domain-association.txt | grep -q PLACEHOLDER`
      should fail (exit 1).

## Why this order

- A bug found on dev costs one fix and one redeploy.
- The same bug discovered after stg + prod are both shipped costs
  three fixes and three redeploys, plus possibly a customer-visible
  outage on prod.
- Apex DNS is shared with the Sookoon marketing site — touching it in
  the wrong order can break unrelated traffic.
- Apple sign-in domain verification is sticky (Apple caches results);
  redoing it after a typo in the Services ID is painful.

## Cross-references

- `docs/web-hosting-guide.md` — full hosting reference.
- `docs/firebase-hosting-dev-deploy.md` — dev-only deploy loop.
- `docs/flutterfire-reconfigure.md` — safe `firebase_options_*.dart`
  refresh.
- `ai_specs/web-admin-reporting-plan.md` — phased plan that this
  checklist follows from the rollout side.
