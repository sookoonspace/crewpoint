# APNs Auth Key Setup — Step-by-Step

Configures Apple Push Notification service for all three CrewPoint flavors (dev / stg / prod) so Firebase can deliver pushes to iOS devices.

## Before you start — read this

APNs auth keys (`.p8` files) are issued **per Apple Developer team**. As of Apple's updated key-creation flow, you must pick at creation time:

- An **environment** (Sandbox or Production) — locked once saved.
- A **scope restriction** (Team-wide vs. Topic-restricted) — locked once saved.
- A list of **eligible topics** (only if you chose Topic-restricted).

Apple now explicitly **recommends environment-specific keys**. We follow that recommendation:

| Key | Environment | Used by Firebase projects | Bundle IDs |
|---|---|---|---|
| **Sandbox key** | Sandbox | `crewpoint-dev`, `crewpoint-stg` | `…crewpoint.dev`, `…crewpoint.stg` |
| **Production key** | Production | `crewpoint-prod` | `…crewpoint.app` |

That's **two keys, both Team-scoped** — which is also exactly Apple's 2-active-keys-per-team limit, so no headroom is wasted.

How environments map to your client builds:

- `aps-environment = development` (dev / stg builds, also any Xcode-run build on a real device) → reaches **sandbox** APNs → Firebase needs the **sandbox key**.
- `aps-environment = production` (TestFlight, App Store, archives) → reaches **production** APNs → Firebase needs the **production key**.

Once saved, neither environment nor scope can be changed. Mistake = revoke + recreate.

Both keys stay valid until you explicitly revoke them. There's no expiry.

You'll need:

- Admin access to your Apple Developer team (developer.apple.com)
- Owner / Editor access to all three Firebase projects (console.firebase.google.com)
- The bundle IDs for each flavor:
  - `space.sookoon.crewpoint.dev`
  - `space.sookoon.crewpoint.stg`
  - `space.sookoon.crewpoint.app`

---

## Step 1 — Confirm each App ID has Push Notifications enabled

The auth key is useless if the App IDs aren't allowed to use push. Verify all three first to avoid creating a key against a misconfigured app and chasing the bug afterwards.

1. Sign in at https://developer.apple.com → **Certificates, Identifiers & Profiles** → **Identifiers**.
2. For each of the three bundle IDs above:
   - Click the identifier row.
   - Scroll the **Capabilities** list.
   - Confirm **Push Notifications** is checked.
   - If it isn't: check it → click **Save** at the top right → confirm the dialog.
3. If you enabled push on any of them just now, **regenerate the development provisioning profile** (Step 6 below) — old profiles won't include the new entitlement and APNs will silently refuse to register on first launch.

---

## Step 2 — Revoke old keys if you're at the limit

You're about to create **two** APNs keys (sandbox + production). Apple caps active APNs keys at 2 per team, so you'll be at the limit. Confirm there's space — or make space — before starting.

1. https://developer.apple.com → **Certificates, IDs & Profiles** → **Keys**.
2. Count the **Active** keys with **Apple Push Notifications service (APNs)** in the capabilities column.
3. If the count is 2 or more, you have to revoke before creating:
   - Click an APNs key row → **Revoke**.
   - Repeat until you're down to zero APNs keys (you're creating both from scratch).

> Once revoked, every server using that key stops sending pushes immediately. If a revoked key is currently uploaded to a Firebase project that's serving live users, plan downtime or stage the rotation: create new key → upload to Firebase → revoke old one.

---

## Step 3 — Create the **Sandbox** APNs key

You'll repeat this whole flow twice — first for sandbox, then again for production in Step 4.

1. https://developer.apple.com → **Certificates, IDs & Profiles** → **Keys** → click the **+** (top right).
2. **Name**:
   ```
   CrewPoint APNs Sandbox (2026)
   ```
   Including "Sandbox" + the year in the name avoids mix-ups when the two keys sit next to each other in the Keys list.
3. Under **Capabilities**, check **Apple Push Notifications service (APNs)** → click the **Configure** button next to it.
4. On the **Configure Key** screen:
   - **Environment** → select **Sandbox**.
   - **Scope restriction** → select **Team** (unrestricted). Topic-scoped keys are useful when one Apple team backs many unrelated apps and you want to limit blast radius — we don't need that here.
   - **Eligible topics** → leave blank (Team scope ignores it).
   - Click **Save** to return to the key-create form.
5. Click **Continue** → review → **Register**.
6. The next page shows the info you'll need to upload to Firebase. **Save all three NOW** — Apple lets you download the `.p8` exactly once:
   - **Key ID** — a 10-character string like `8X7N9YBM3Z`. Note this down as the **sandbox** Key ID.
   - **Team ID** — visible in the top-right of any Apple Developer page (10 chars, all caps).
   - The `.p8` file itself — click **Download**. Rename it on disk to something unambiguous like `AuthKey_<KeyID>_sandbox.p8` so you don't confuse it with the production one in Step 4.
7. Store the `.p8` somewhere safe + backed up (1Password, encrypted disk image, etc.). Treat it like a private key — anyone with it can send push notifications under your team's name.

> If you close the page without downloading, **the file is gone**. You'd have to revoke this key and create a new one. Don't skip the download.

---

## Step 4 — Create the **Production** APNs key

Same flow, different environment.

1. https://developer.apple.com → **Certificates, IDs & Profiles** → **Keys** → **+**.
2. **Name**:
   ```
   CrewPoint APNs Production (2026)
   ```
3. **Capabilities** → check **Apple Push Notifications service (APNs)** → click **Configure**.
4. On the **Configure Key** screen:
   - **Environment** → select **Production**.
   - **Scope restriction** → **Team**.
   - **Eligible topics** → leave blank.
   - Click **Save**.
5. **Continue** → **Register**.
6. Download + record:
   - **Key ID** — note this down as the **production** Key ID (different from the sandbox one).
   - **Team ID** — same as Step 3.
   - The `.p8` file — rename to `AuthKey_<KeyID>_production.p8`.
7. Store next to the sandbox `.p8` in your secure store.

You now have **two `.p8` files + two distinct Key IDs + one shared Team ID**.

---

## Step 5 — Upload each key to the right Firebase project(s)

Mapping (memorise this — uploading the wrong key to the wrong project is the most common silent failure mode):

| Key | Firebase projects to upload to |
|---|---|
| **Sandbox** (`AuthKey_<sandbox_id>_sandbox.p8`) | `crewpoint-dev` + `crewpoint-stg` |
| **Production** (`AuthKey_<prod_id>_production.p8`) | `crewpoint-prod` |

So you'll perform the upload flow below **three times total** — sandbox key into dev, sandbox key into stg, production key into prod.

### 5.1 — Open the project's Cloud Messaging settings

1. https://console.firebase.google.com → select the project (start with `crewpoint-dev`).
2. Click the gear icon (top-left, next to "Project Overview") → **Project settings**.
3. Open the **Cloud Messaging** tab.
4. Scroll to the **Apple app configuration** section.

### 5.2 — Pick the right iOS app

Each Firebase project should have exactly one iOS app registered, with the bundle ID matching that flavor:

| Firebase project | Expected bundle ID | Which key to upload |
|---|---|---|
| `crewpoint-dev` | `space.sookoon.crewpoint.dev` | Sandbox |
| `crewpoint-stg` | `space.sookoon.crewpoint.stg` | Sandbox |
| `crewpoint-prod` | `space.sookoon.crewpoint.app` | Production |

If the bundle ID on the card doesn't match the expected one for that project, **stop and fix the mismatch first** — uploading the auth key won't help when the app and project are bound to different bundle IDs.

### 5.3 — Replace the existing APNs Authentication Key

Under the iOS app card, find the **APNs Authentication Key** row.

- If there's already a key listed: click the pencil icon → click the **trash** to remove the old one.
- Click **Upload** under the now-empty APNs Authentication Key row.

### 5.4 — Fill in the upload dialog

| Field | Value (depends on which project you're configuring) |
|---|---|
| **APNs auth key (.p8)** | The **sandbox** `.p8` for `crewpoint-dev` / `crewpoint-stg`; the **production** `.p8` for `crewpoint-prod`. |
| **Key ID** | The matching Key ID from Step 3 (sandbox) or Step 4 (production). |
| **Team ID** | Same Team ID for all three (single Apple Developer team). |

Click **Upload**.

### 5.5 — Verify

After upload, the APNs Authentication Key row should show:

- The Key ID you just uploaded
- The Team ID
- No error banner

### 5.6 — Repeat for the other two projects

- Switch to `crewpoint-stg` → repeat 5.1–5.5 uploading the **sandbox** `.p8` again.
- Switch to `crewpoint-prod` → repeat 5.1–5.5 uploading the **production** `.p8`.

After all three uploads, each Firebase project carries exactly one APNs key, matched to its build environment.

---

## Step 6 — Verify the Xcode entitlements (one-time per machine)

The auth keys are now in Firebase. Confirm the iOS app is asking for the right environment so it lines up with whichever key Firebase will use.

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Select the **Runner** target → **Signing & Capabilities**.
3. Check the **Push Notifications** capability is present (no red warnings).
4. Open `ios/Runner/Runner.entitlements` and confirm:
   ```xml
   <key>aps-environment</key>
   <string>development</string>
   ```
   For dev / stg / Xcode-run-on-device builds this stays as `development` → routed to sandbox APNs → uses the **sandbox key** uploaded to `crewpoint-dev` and `crewpoint-stg`.

   Xcode automatically swaps it to `production` when archiving for TestFlight / App Store → routed to production APNs → uses the **production key** uploaded to `crewpoint-prod`. You don't edit this manually.

---

## Step 7 — Regenerate the provisioning profile

This is the step most people skip and then spend an hour debugging silent APNs failures.

When you enable a new capability on an App ID (Step 1) or change which auth key Apple uses for your team, Xcode's cached provisioning profile becomes stale and **does not include the new entitlement**. iOS will silently refuse to register for remote notifications until the profile is refreshed.

In Xcode → **Signing & Capabilities**:

1. Toggle **Automatically manage signing** **OFF**.
2. Wait ~1 second.
3. Toggle it back **ON**.
4. Xcode contacts Apple Developer + downloads a fresh profile that includes the push entitlement.
5. Press **⌘⇧K** (Product → Clean Build Folder).
6. Rebuild and reinstall on the device.

---

## Step 8 — Verify the device gets an APNs token

After rebuilding and signing in (use the dev flavor for the fastest validation — it exercises the sandbox key + sandbox APNs path):

1. Open **Profile → Dev tools → FCM diagnostic** in the app.
2. The diagnostic should now show:
   - `Auth status: authorized`
   - `APNs token: <40+ hex chars>` (no longer null)
   - `FCM token (live): <FCM token string>`
   - `Firestore fcmTokens: 1 token` (after a few seconds)
3. In the Xcode debug console you should see:
   ```
   [CrewPoint][APNs] ✅ Registered for remote notifications. Token: <hex>
   ```

If you instead see:
```
[CrewPoint][APNs] ❌ Failed to register for remote notifications: <reason>
[CrewPoint][APNs] Error domain: <domain>, code: <code>, userInfo: <dict>
```
Paste the error domain + code into the team chat — that's the precise rejection reason from Apple.

---

## Rotation / future maintenance

- APNs auth keys don't expire. Rotate them only if:
  - A `.p8` file is compromised.
  - A team member with download access leaves the team.
  - Your team passes Apple ownership.
- Rotate one environment at a time:
  1. Create the new key (Sandbox or Production) in Apple Developer.
  2. Upload to the matching Firebase project(s) (sandbox → dev+stg, production → prod).
  3. Verify pushes still deliver from those projects.
  4. **Then** revoke the old key in Apple Developer.

  This order guarantees zero push downtime — the old key keeps working until the new one is live everywhere.

- Rotating both environments at once requires more care because Apple's 2-key limit blocks creating new keys until you've revoked old ones. Sequence: revoke one old key → create + roll out its replacement → revoke the other old key → create + roll out its replacement. Don't revoke both old keys up front.

---

## Troubleshooting quick reference

| Symptom | Likely cause | Where to look |
|---|---|---|
| Diagnostic shows `APNs token: null` indefinitely on a real device | App ID missing Push capability OR stale provisioning profile | Step 1, Step 7 |
| `❌ Failed to register` log with `code=3010` | Trying to register on iOS Simulator | Real device required |
| `❌ Failed to register` log with `code=3000`-ish | Bundle ID mismatch between Xcode and Apple Developer App ID | Step 1, Xcode bundle ID |
| FCM token arrives but no push delivers in **dev or stg** | Wrong key uploaded — make sure the **sandbox** key is in both `crewpoint-dev` and `crewpoint-stg` Firebase projects | Step 5.2 (mapping) |
| FCM token arrives but no push delivers in **prod / TestFlight** | The **production** key isn't uploaded to `crewpoint-prod`, OR the production key was uploaded to a dev/stg project by mistake | Step 5.2 (mapping) |
| Push delivers in dev but not in staging | Sandbox key uploaded to `crewpoint-dev` only — repeat 5.1–5.5 for `crewpoint-stg` | Step 5.6 |
| Push delivers in staging but not in TestFlight | Two possible causes: (a) production key missing from `crewpoint-prod`, or (b) you're testing a build that was signed with the dev cert instead of being archived. Re-archive properly from Xcode. | Step 5.2, Step 6 |
| `BadDeviceToken` returned by FCM server | The token came from sandbox APNs but is being sent through the production key (or vice versa) — environment / key mismatch | Step 5.2 (mapping), Step 6 (entitlement) |
