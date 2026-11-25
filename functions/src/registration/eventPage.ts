import {onCall, onRequest, HttpsError} from "firebase-functions/v2/https";
import {logger} from "firebase-functions/v2";
import {getFirestore} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import {requireString, withStructuredLogs} from "../utils/logging";
import {allowRequest, callerAddress} from "../utils/rateLimit";
import {PublicEvent, publicEventView} from "./publicEvent";
import {registrationOf} from "./registrationSettings";
import {normaliseSlug} from "./settings";

const db = getFirestore();

/** About 60 event-page opens a minute from one address (Req 13a). */
export const PAGE_OPENS_PER_MINUTE = 60;
const MINUTE = 60 * 1000;

/**
 * App Check is required on deployed functions (Req 13a). The emulators run
 * without it, since tests never hold a real token.
 */
const enforceAppCheck = process.env.FUNCTIONS_EMULATOR !== "true";

interface Found {
  id: string;
  event: FirebaseFirestore.DocumentData;
  view: PublicEvent;
}

/** The event a slug names and what its page may show, or null. */
export async function findPublicEvent(rawSlug: string, now = Date.now()): Promise<Found | null> {
  const slug = normaliseSlug(rawSlug);
  if (!slug) return null;
  const mapping = await db.collection("eventSlugs").doc(slug).get();
  const id = mapping.data()?.eventId;
  if (typeof id !== "string") return null;
  const eventRef = db.collection("events").doc(id);
  const [eventDoc, tally] = await Promise.all([
    eventRef.get(),
    eventRef.collection("registrationTally").doc("current").get(),
  ]);
  if (!eventDoc.exists) return null;
  const event = eventDoc.data()!;
  const registration = registrationOf(event);
  // A name the event has since given up no longer leads to it.
  if (registration.slug !== slug) return null;
  const used = tally.data()?.placesUsed;
  return {
    id,
    event,
    view: publicEventView({
      event,
      registration,
      placesUsed: typeof used === "number" ? used : 0,
      now,
    }),
  };
}

function rateLimited(): HttpsError {
  return new HttpsError(
    "resource-exhausted", "Please try again in a few minutes.", {reason: "rateLimited"});
}

/**
 * getEventPage — the public event page (Spec #233 Req 10, 13a, 14; #240,
 * `/e/:eventSlug`): what an event shows to anyone with its link, signed in
 * or not, found only by its slug. Returns the public view (`publicEvent.ts`)
 * and never the event's ID, people, counts or money. A draft is
 * `{state: "notOpen"}`; a missing slug `not-found`. App Check is required,
 * and about 60 opens a minute from one address are allowed; beyond that
 * `resource-exhausted` with `details.reason: "rateLimited"`.
 */
export const getEventPage = onCall({timeoutSeconds: 15, enforceAppCheck}, async (request) => {
  const data = (request.data ?? {}) as {slug?: unknown};
  const slug = requireString(data.slug, "slug");
  const subject = callerAddress(request.rawRequest as never);
  return withStructuredLogs({op: "getEventPage", uid: request.auth?.uid ?? "anonymous", args: {slug}}, async () => {
    const allowed = await allowRequest(db, {
      bucket: "eventPage", subject, limit: PAGE_OPENS_PER_MINUTE, windowMs: MINUTE,
    });
    if (!allowed) throw rateLimited();
    const found = await findPublicEvent(slug);
    if (!found) throw new HttpsError("not-found", "We couldn't find this event.");
    return found.view;
  });
});

const escape = (s: string) =>
  s.replace(/[&<>"']/g, (c) => ({"&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;", "'": "&#39;"}[c]!));

/** The event's dates as the page shows them, in its time zone. */
export function formatDates(view: Extract<PublicEvent, {title: string}>): string {
  if (view.startDate === null) return "";
  const zone = view.dateOnly ? "UTC" : view.timeZone;
  const day = (ms: number) => new Intl.DateTimeFormat("en-US", {
    timeZone: zone, weekday: "short", month: "short", day: "numeric", year: "numeric",
    ...(view.dateOnly ? {} : {hour: "numeric", minute: "2-digit"}),
  }).format(new Date(ms));
  const start = day(view.startDate);
  return view.endDate === null || view.endDate === view.startDate ? start : `${start} – ${day(view.endDate)}`;
}

/**
 * The small first page for `/e/:eventSlug` (Req 69): title, dates, place,
 * Register and link-preview tags, then the Flutter app, which takes over
 * and removes `#cp-ssr`. It stays above the app's canvas until then, so a
 * slow phone never shows a blank screen while the app loads. Anything the page may not show (a draft, an
 * unknown name, a busy address) gets the plain app shell.
 */
export function renderEventPage({view, slug, origin}: {
  view: PublicEvent | null;
  slug: string;
  origin: string;
}): string {
  const shown = view && view.state !== "notOpen" ? view : null;
  const title = shown ? `${shown.title} · CrewPoint` : "CrewPoint";
  const dates = shown ? formatDates(shown) : "";
  const place = shown?.venues.map((v) => v.name).filter(Boolean).join(" · ") ?? "";
  const url = `${origin}/e/${encodeURIComponent(slug)}`;
  const summary = [dates, place].filter(Boolean).join(" · ");
  const meta = shown ? [
    `<meta property="og:type" content="website">`,
    `<meta property="og:title" content="${escape(shown.title)}">`,
    `<meta property="og:description" content="${escape(summary)}">`,
    `<meta property="og:url" content="${escape(url)}">`,
    shown.hasCover ? `<meta property="og:image" content="${escape(url)}/cover.jpg">` : "",
    `<meta name="twitter:card" content="${shown.hasCover ? "summary_large_image" : "summary"}">`,
    `<meta name="description" content="${escape(summary)}">`,
  ].filter(Boolean).join("\n  ") : `<meta name="robots" content="noindex">`;
  const register = shown?.state === "open" && shown.mode === "open" ?
    `<a class="cp-btn" href="/e/${encodeURIComponent(slug)}/register">Register</a>` : "";
  const body = shown ? `<main id="cp-ssr"><div class="cp-in">
    <h1>${escape(shown.title)}</h1>
    ${dates ? `<p>${escape(dates)}</p>` : ""}
    ${place ? `<p>${escape(place)}</p>` : ""}
    ${register}
  </div></main>` : "";
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <base href="/">
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${escape(title)}</title>
  ${meta}
  <link rel="icon" type="image/png" href="favicon.png">
  <link rel="manifest" href="manifest.json">
  <style>
    body { margin: 0; font: 16px/1.4 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
      background: #f7f7f5; color: #1d1d1b; }
    /* Above Flutter's canvas, which fills the window as soon as the engine
       starts, until the event page removes it with the event on screen. */
    #cp-ssr { position: fixed; inset: 0; z-index: 2147483647; overflow-y: auto; background: #f7f7f5; }
    #cp-ssr .cp-in { max-width: 560px; margin: 0 auto; padding: 32px 16px; }
    #cp-ssr h1 { font-size: 28px; line-height: 1.2; margin: 0 0 12px; }
    #cp-ssr p { font-size: 17px; margin: 0 0 8px; color: #4a4a46; }
    .cp-btn { display: inline-block; margin-top: 16px; padding: 14px 24px; min-height: 20px;
      border-radius: 12px; background: #1f6f5c; color: #fff; text-decoration: none; font-weight: 600; }
    @media (prefers-color-scheme: dark) {
      body, #cp-ssr { background: #151514; color: #f2f2ef; }
      #cp-ssr p { color: #c6c6c0; }
      .cp-btn { background: #4fb59a; color: #0b1f1a; }
    }
  </style>
</head>
<body>
  ${body}
  <script src="flutter_bootstrap.js" async></script>
</body>
</html>
`;
}

/**
 * eventPageHtml — Hosting sends `/e/**` here (Req 69). `/e/:slug` gets the
 * server-rendered first page; `/e/:slug/cover.jpg` the event's cover photo
 * for link previews (never a draft's); any other path the plain app shell.
 * Pages are cached at the edge for a minute.
 */
export const eventPageHtml = onRequest({timeoutSeconds: 15}, async (req, res) => {
  const parts = req.path.split("/").filter(Boolean);
  const slug = parts[1] ?? "";
  const host = String(req.headers["x-forwarded-host"] ?? req.headers.host ?? "");
  const origin = host ? `https://${host.split(",")[0].trim()}` : "";
  try {
    if (parts[0] === "e" && parts.length === 3 && parts[2] === "cover.jpg") {
      const found = await findPublicEvent(slug);
      if (!found || found.view.state === "notOpen" || !found.view.hasCover) {
        res.status(404).send("Not found");
        return;
      }
      const file = getStorage().bucket().file(String(found.event.cover.path));
      const [metadata] = await file.getMetadata();
      const [bytes] = await file.download();
      res.set("Cache-Control", "public, max-age=300, s-maxage=3600");
      res.set("Content-Type", String(metadata.contentType ?? "image/jpeg"));
      res.status(200).send(bytes);
      return;
    }
    let view: PublicEvent | null = null;
    if (parts[0] === "e" && parts.length === 2) {
      const allowed = await allowRequest(db, {
        bucket: "eventPageHtml", subject: callerAddress(req as never), limit: PAGE_OPENS_PER_MINUTE, windowMs: MINUTE,
      });
      view = allowed ? (await findPublicEvent(slug))?.view ?? null : null;
    }
    res.set("Cache-Control", "public, max-age=0, s-maxage=60");
    res.set("Content-Type", "text/html; charset=utf-8");
    res.status(200).send(renderEventPage({view, slug, origin}));
  } catch (error) {
    logger.error("eventPageHtml failed", {path: req.path, error: error instanceof Error ? error.message : String(error)});
    // The app shell still loads, and the app shows its own error.
    res.set("Cache-Control", "no-store");
    res.set("Content-Type", "text/html; charset=utf-8");
    res.status(200).send(renderEventPage({view: null, slug, origin}));
  }
});
