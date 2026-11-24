# Light sign-in for registering (#241)

Register asks for a light account (Spec #233 Req 12): an email sign-in
link, a code texted to a phone, or Google or Apple, with no password. These
are the settings and checks it needs per project. Do dev first; each
change to a real project needs the owner's approval.

## Firebase console (Authentication)

1. **Sign-in method → Email/Password → Email link (passwordless sign-in):**
   on. The password option stays as it is.
2. **Sign-in method → Phone:** on.
3. **Settings → SMS region policy:** *Allow* only **United States (US),
   Canada (CA) and United Kingdom (GB)**. The app also refuses other
   numbers, but only this setting stops Firebase sending.
4. **Settings → User account linking:** *Link accounts that use the same
   email* (the default), so the same email by any method is one account
   (L-06).
5. **Settings → Authorized domains:** the flavor's Hosting domain
   (`crewpoint-dev.web.app`, `crewpoint-stg.web.app`,
   `crewpoint.sookoon.space`).

## How the email link travels

`sendSignInLink` (App Check required, about 10 links an hour per address
and 5 per email) asks Firebase for the link with `linkDomain` set to the
flavor's Hosting domain, since Firebase Dynamic Links no longer exist, and
queues the `signInLink` email (`functions/src/mail/templates/`) in the
visitor's language. Firebase's own template is never used. In dev and
staging the email goes only to `serverConfig/mail.allowedRecipients`
(`docs/ops/email.md`).

The link opens `/auth/link?to=<where they started>` on the Hosting domain.
With the app installed, App Links (Android) and Universal Links (iOS) open
the app there instead.

## App Links and Universal Links

- `web/.well-known/assetlinks.json` lists the three Android packages with
  the SHA-256 of the key that signs release builds. Today that is the
  debug key (`android/app/build.gradle.kts`). **When Play App Signing is
  set up, add the Play signing key's SHA-256** (Play Console → App
  integrity) to each entry.
- `web/.well-known/apple-app-site-association` lists the three iOS apps
  (team `9TF5KXSKY4`). Hosting serves it as `application/json`.
- Hosting now deploys `.well-known` (`firebase.json` no longer ignores
  every dot-path). That also publishes
  `apple-developer-domain-association.txt`, still a placeholder (see
  `docs/web-hosting-guide.md`, Stage 7).
- Android: an `autoVerify` intent filter on `${appLinkHost}`, set per
  flavor, for `/join/`, `/e/`, `/r/` and `/auth/link`.
- iOS: `applinks:$(APP_LINK_HOST)` in `Runner.entitlements`, set per
  flavor in the xcconfigs. **The App IDs need the Associated Domains
  capability** in the Apple Developer portal; with automatic signing,
  Xcode adds it when you next build with the account signed in.
- Flutter's built-in deep linking is off on both, so each link reaches the
  router once, through `IIncomingLinkSource`.

## Manual checks (Testing Strategy 7)

Not yet done: they need the functions and Hosting on dev, and real
devices. Record each run here.

| Check | Result | Date | Notes |
| --- | --- | --- | --- |
| Email link opened on iPhone with the app installed | | | |
| Email link opened on iPhone without the app (Safari) | | | |
| Email link opened on Android with the app installed | | | |
| Email link opened on Android without the app (Chrome) | | | |
| Email link opened on a second device: asks for the email | | | |
| Second device, a different email: refused | | | |
| An expired or used link: "Send a new link" works | | | |
| SMS code to a US number | | | |
| SMS code to a Canadian number | | | |
| SMS code to a UK number | | | |
| A number from another country is refused by Firebase | | | |
| Same email by link and by Google is one account | | | |
