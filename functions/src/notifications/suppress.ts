import type {NotificationCategory} from "./sendPush";

/**
 * Phase 5 suppression predicates. Pure / side-effect-free — exported
 * for unit tests and consumed by `sendCategorizedPush` to gate the
 * per-recipient fan-out.
 *
 * Two suppression sources:
 *   - **Quiet hours**: `notificationPrefs.{quietHoursStart, quietHoursEnd,
 *     timezone}` define a wall-clock window in the recipient's timezone
 *     during which non-urgent pushes are dropped. All three fields must
 *     be set; otherwise the check is skipped.
 *   - **Event mute**: `users/{uid}/eventMutes/{eventId}.mutedUntil` (ISO
 *     UTC string) drops every push for that (uid, eventId) until the
 *     timestamp passes.
 *
 * Bypass: `category === 'chat_urgent'` AND recipient
 * `notificationPrefs.criticalOptIn === true` ignores both. Mirrors the
 * Phase 4 interruption-level routing — opted-in urgent pings are the
 * one stream that pierces every quiet / mute state the user has set.
 */

export interface QuietHoursPrefs {
  quietHoursStart: number | null;
  quietHoursEnd: number | null;
  timezone: string | null;
}

/**
 * Returns true when [at] falls inside the recipient's quiet-hours
 * window. Window is `[start, end)` (end-exclusive); `start > end`
 * means the window crosses midnight (e.g. 22:00-07:00).
 *
 * No-op when any of the three fields is null — quiet hours are
 * considered off.
 */
export function isWithinQuietHours(prefs: QuietHoursPrefs, at: Date): boolean {
  const {quietHoursStart, quietHoursEnd, timezone} = prefs;
  if (
    quietHoursStart === null ||
    quietHoursEnd === null ||
    timezone === null ||
    timezone === undefined
  ) {
    return false;
  }
  // Convert `at` to minute-of-day in the recipient's timezone via
  // Intl.DateTimeFormat — Node 22 ships with the full IANA database
  // so no third-party tz library is needed.
  let hour: number;
  let minute: number;
  try {
    const parts = new Intl.DateTimeFormat("en-US", {
      timeZone: timezone,
      hour: "2-digit",
      minute: "2-digit",
      hour12: false,
    }).formatToParts(at);
    const h = parts.find((p) => p.type === "hour")?.value;
    const m = parts.find((p) => p.type === "minute")?.value;
    if (h === undefined || m === undefined) return false;
    hour = parseInt(h, 10);
    minute = parseInt(m, 10);
    if (Number.isNaN(hour) || Number.isNaN(minute)) return false;
    // Intl returns "24" for midnight under hour12:false on some Node
    // versions; normalize to "0" to keep `nowMinute` in [0, 1439].
    if (hour === 24) hour = 0;
  } catch {
    // Unknown timezone string → treat as "no quiet hours".
    return false;
  }
  const nowMinute = hour * 60 + minute;
  if (quietHoursStart <= quietHoursEnd) {
    return nowMinute >= quietHoursStart && nowMinute < quietHoursEnd;
  }
  // Crosses midnight.
  return nowMinute >= quietHoursStart || nowMinute < quietHoursEnd;
}

/**
 * Returns true while `mutedUntil` is at or after [now]. Accepts the
 * value verbatim from the Firestore doc; falls back to false on
 * null / undefined / wrong type / unparseable string.
 */
export function isMutedUntilAfter(
  mutedUntil: unknown,
  now: Date
): boolean {
  if (typeof mutedUntil !== "string") return false;
  const ts = Date.parse(mutedUntil);
  if (Number.isNaN(ts)) return false;
  return ts >= now.getTime();
}

/**
 * Combined suppression predicate used inside `sendCategorizedPush`.
 * Returns true when the push should be dropped for this recipient.
 *
 * `chat_urgent` + `criticalOptIn === true` bypasses both quiet hours
 * and event mute — the documented one bypass. Every other category /
 * non-opted-in chat_urgent honours both.
 */
export function shouldSuppress(args: {
  category: NotificationCategory;
  criticalOptIn: boolean;
  prefs: QuietHoursPrefs;
  eventMutedUntil: unknown;
  now: Date;
}): boolean {
  if (args.category === "chat_urgent" && args.criticalOptIn) return false;
  if (isWithinQuietHours(args.prefs, args.now)) return true;
  if (isMutedUntilAfter(args.eventMutedUntil, args.now)) return true;
  return false;
}
