import {onCall, HttpsError} from "firebase-functions/v2/https";
import {getAuth} from "firebase-admin/auth";
import {getFirestore} from "firebase-admin/firestore";
import {withStructuredLogs} from "../utils/logging";
import {allowRequest, callerAddress} from "../utils/rateLimit";
import {enqueueEmail, normaliseEmail} from "../mail/outbox";

const db = getFirestore();

/** Each project's Hosting domain, where sign-in links open (Spec #233 TD 5). */
const HOSTS: Record<string, string> = {
  "crewpoint-dev": "crewpoint-dev.web.app",
  "crewpoint-stg": "crewpoint-stg.web.app",
  "crewpoint-prod": "crewpoint.sookoon.space",
};

/** The app on each project, so an installed app opens the link. */
const APP_IDS: Record<string, string> = {
  "crewpoint-dev": "space.sookoon.crewpoint.dev",
  "crewpoint-stg": "space.sookoon.crewpoint.stg",
  "crewpoint-prod": "space.sookoon.crewpoint.app",
};

const PROJECT = () => process.env.GCLOUD_PROJECT ?? "";
/** Tests run on `demo-crewpoint`, which stands in for dev. */
export const hostingDomain = () => HOSTS[PROJECT()] ?? HOSTS["crewpoint-dev"];
const appId = () => APP_IDS[PROJECT()] ?? APP_IDS["crewpoint-dev"];

/** Where a link may lead after signing in, as the app's router allows. */
const RETURNABLE = ["/join/", "/e/", "/r/"];

/** [raw] when it is a path the app returns to, else the home page. */
export function safeReturn(raw: unknown): string {
  if (typeof raw !== "string") return "/";
  return RETURNABLE.some((p) => raw.startsWith(p)) && !raw.includes("//") ? raw : "/";
}

const enforceAppCheck = process.env.FUNCTIONS_EMULATOR !== "true";

/** About 10 links an hour from one address, and 5 to one email (Req 13a). */
export const LINKS_PER_ADDRESS_PER_HOUR = 10;
export const LINKS_PER_EMAIL_PER_HOUR = 5;
const HOUR = 60 * 60 * 1000;

/**
 * sendSignInLink — Register's email sign-in (Spec #233 Req 12; #241): makes
 * Firebase's email sign-in link for [email] and sends it in CrewPoint's own
 * words, in the visitor's language, through the outbox. The link opens
 * `/auth/link?to=<returnTo>` on the flavor's Hosting domain, or the
 * installed app through App Links and Universal Links, and returns to
 * [returnTo] (only `/join/`, `/e/` and `/r/` paths; anything else goes
 * home). No account is needed to ask; App Check is required, and about 10
 * links an hour from one address and 5 to one email are sent, else
 * `resource-exhausted` with `details.reason: "rateLimited"`.
 */
export const sendSignInLink = onCall({timeoutSeconds: 30, enforceAppCheck}, async (request) => {
  const data = (request.data ?? {}) as {email?: unknown; returnTo?: unknown; language?: unknown};
  const email = normaliseEmail(data.email);
  if (!email) throw new HttpsError("invalid-argument", "Enter a valid email address.");
  const returnTo = safeReturn(data.returnTo);
  const language = data.language === "gu" ? "gu" : "en";
  const address = callerAddress(request.rawRequest as never);

  return withStructuredLogs({op: "sendSignInLink", uid: request.auth?.uid ?? "anonymous", args: {returnTo}}, async () => {
    const [byAddress, byEmail] = await Promise.all([
      allowRequest(db, {bucket: "signInAddress", subject: address, limit: LINKS_PER_ADDRESS_PER_HOUR, windowMs: HOUR}),
      allowRequest(db, {bucket: "signInEmail", subject: email, limit: LINKS_PER_EMAIL_PER_HOUR, windowMs: HOUR}),
    ]);
    if (!byAddress || !byEmail) {
      throw new HttpsError("resource-exhausted", "Please try again in a few minutes.", {reason: "rateLimited"});
    }
    const host = hostingDomain();
    const link = await getAuth().generateSignInWithEmailLink(email, {
      url: `https://${host}/auth/link?to=${encodeURIComponent(returnTo)}`,
      handleCodeInApp: true,
      linkDomain: host,
      iOS: {bundleId: appId()},
      android: {packageName: appId(), installApp: false},
    });
    await enqueueEmail(db, {
      to: email,
      uid: null,
      language,
      template: "signInLink",
      data: {link},
    });
    return {sent: true};
  });
});
