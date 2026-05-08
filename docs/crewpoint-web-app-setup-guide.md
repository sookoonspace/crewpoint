so crewpoint.sookoon.space is what we need to setup in namecheap right? if so can i get step by step instruction please, if its of any
   use i also have crewpoint.app domain registered on namecheap, did it long time ago when i was not sure about sookoon llc but i had
  rough idea about crewpoint

⏺ Yes — crewpoint.sookoon.space is the custom domain for your Firebase-hosted Flutter web app (crewpoint-prod target). Setup is
  two-sided: Firebase Console tells you what records to add, then you add them in Namecheap DNS.

  Prereq

  Before you start, deploy the prod build at least once so the Firebase site exists:

  cd /Users/googoo/StudioProjects/CrewPoint/crewpoint_app
  flutter build web --release --dart-define=FLAVOR=prod
  firebase deploy --only hosting:crewpoint-prod

  After that, https://crewpoint-prod.web.app should serve the app. Confirm in a browser.

  Step 1 — Add the custom domain in Firebase Console

  1. Go to console.firebase.google.com, select the crewpoint-prod project.
  2. Left nav → Hosting.
  3. Find the crewpoint-prod site → click Add custom domain.
  4. Enter: crewpoint.sookoon.space.
  5. Leave "Redirect" unchecked (you want it to serve content, not redirect).
  6. Click Continue.

  Firebase will show a TXT record for ownership verification — something like:

  ┌──────┬───────────────────────────────────┬──────────────────────────────────┐
  │ Type │ Host (Firebase calls it "Domain") │              Value               │
  ├──────┼───────────────────────────────────┼──────────────────────────────────┤
  │ TXT  │ crewpoint.sookoon.space           │ google-site-verification=ABC123… │
  └──────┴───────────────────────────────────┴──────────────────────────────────┘

  Keep this Firebase tab open. You'll come back after step 2.

  Step 2 — Add the TXT verification record in Namecheap

  1. namecheap.com → sign in → Domain List → click Manage on sookoon.space.
  2. Top tabs → Advanced DNS.
  3. Add New Record:
    - Type: TXT Record
    - Host: crewpoint &nbsp;(just the subdomain label — Namecheap automatically appends .sookoon.space)
    - Value: (paste the entire google-site-verification=... string from Firebase — leave the quotes off)
    - TTL: Automatic
  4. Click the green checkmark to save.

  Step 3 — Verify ownership in Firebase

  1. Wait 5–10 minutes for the TXT record to propagate. You can check with:
  dig +short TXT crewpoint.sookoon.space
  1. You should see your verification string.
  2. Back in the Firebase Console tab → click Verify.
  3. Firebase confirms ownership and shows the A records for routing — typically two IPs:
  151.101.1.195
  151.101.65.195
  3. (yours may differ — use what Firebase shows, not these examples)

  Step 4 — Add the A records in Namecheap

  Back to Namecheap Advanced DNS for sookoon.space:

  1. Add New Record (first A record):
    - Type: A Record
    - Host: crewpoint
    - Value: (first IP from Firebase)
    - TTL: Automatic
  2. Add New Record (second A record):
    - Type: A Record
    - Host: crewpoint
    - Value: (second IP from Firebase)
    - TTL: Automatic
  3. Save (green checkmarks).

  You can leave the TXT record in place — it's harmless and re-verifying later is faster if you keep it.

  Step 5 — Final verify + SSL provisioning

  1. In the Firebase Console → click Finish (or Verify, depending on the wizard step).
  2. The status will go to "Setting up" — Firebase provisions a Let's Encrypt SSL cert. This takes 15 minutes to a few hours,
  occasionally up to 24 hours. Be patient.
  3. Once it shows Connected with a green check and SSL is issued:
    - Visit https://crewpoint.sookoon.space — Flutter web app should serve.
    - Visit https://crewpoint.sookoon.space/privacy and /terms — the static legal HTML pages (set up in Phase 5 of the audit work) should
   serve from the firebase.json rewrites.
    - Browser should show a valid lock icon.

  Step 6 — Smoke-test the production wiring

  Once DNS + SSL are live, run the Phase 5 manual smoke from the pre-launch checklist:

  # Confirm the custom domain serves all three:
  open https://crewpoint.sookoon.space          # Flutter app
  open https://crewpoint.sookoon.space/privacy  # static legal HTML
  open https://crewpoint.sookoon.space/terms    # static legal HTML

  # Confirm prod build links to the custom domain (NOT *.web.app):
  grep -o "crewpoint-prod\.web\.app" build/web/main.dart.js | head -3
  # should return nothing — your Phase 5 AppFlavor.legalBaseUrl wiring
  # routes prod legal links to crewpoint.sookoon.space, never *.web.app.

  ---
  About crewpoint.app

  Three options ranked by effort:

  1. Sit on it (recommended for V1). Don't point it anywhere. The Sookoon umbrella branding is crewpoint.sookoon.space and that's the URL
   on the marketing site, in the legal docs, and in the in-app footer. Using crewpoint.app would dilute the Sookoon brand. Keep the
  registration; revisit after launch.

  2. Redirect crewpoint.app → crewpoint.sookoon.space. Easy: in Namecheap, Domain List → Manage crewpoint.app → Domain tab → Redirect
  Domain → URL https://crewpoint.sookoon.space (Permanent 301, "Make it look like the real URL" off). Done. Costs nothing, no DNS records
   needed.

  3. Make crewpoint.app a parallel custom domain. Repeat Step 1–5 above with crewpoint.app (apex) and www.crewpoint.app. The Flutter app
  would load at either URL. Downsides: two URLs to maintain SSL on, two URLs in search engine indexes (canonical-tag fix needed), brand
  split. Not recommended for V1.

  If you want option 2, I can give you the click path inside Namecheap. If you want option 3, the Firebase + Namecheap steps are nearly
  identical to what's above (apex domains additionally need the records added at @ and www instead of a subdomain label).

  Troubleshooting

  - TXT record verification fails after 30 min — confirm in Namecheap that the Host field is exactly crewpoint (not
  crewpoint.sookoon.space — Namecheap appends the apex automatically). Re-check with dig +short TXT crewpoint.sookoon.space.
  - SSL stuck in "Setting up" past 24 hours — usually Let's Encrypt rate-limited or DNS not fully propagated. Delete the custom domain in
   Firebase and re-add it. Don't touch the DNS records.
  - Browser shows "Site can't be reached" for hours — DNS propagation can take up to 48 h on rare ISPs. Test from a different network or
  use whatsmydns.net to check global propagation of the A records.
  - crewpoint.sookoon.space works but legal pages 404 — the firebase.json rewrites only apply to the prod hosting target. Confirm you
  deployed crewpoint-prod, not crewpoint-dev or crewpoint-stg, and that web/legal/privacy.html is present in the deployed build/web/.