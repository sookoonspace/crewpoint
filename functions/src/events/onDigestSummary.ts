import {onSchedule} from "firebase-functions/v2/scheduler";
import {logger} from "firebase-functions/v2";
import {Firestore, Query, Timestamp, getFirestore} from "firebase-admin/firestore";
import {sendCategorizedPush} from "../notifications/sendPush";

/**
 * Phase 6.1 — opt-in daily digest. Scheduled every 60 minutes; per
 * recipient with `notificationPrefs.dailyDigest === true`, fires when
 * the recipient's local hour matches [DIGEST_HOUR] in their tz
 * (Phase 5 IANA `timezone` pref). Aggregates unread chat / pending
 * tasks / open settlements; skips when all counters are zero so we
 * never ship a "you have nothing" ping.
 */
export const DIGEST_HOUR = 9;

/**
 * Returns true when [now] in [timezone] is at [targetHour]:XX. Pure;
 * no Firestore reads. Defensive: returns false on null / empty /
 * unknown timezone so a misconfigured recipient never accidentally
 * receives a digest at an unexpected hour.
 */
export function isDigestHour(args: {
  timezone: string | null | undefined;
  now: Date;
  targetHour: number;
}): boolean {
  const tz = args.timezone;
  if (!tz) return false;
  try {
    const parts = new Intl.DateTimeFormat("en-US", {
      timeZone: tz,
      hour: "2-digit",
      hour12: false,
    }).formatToParts(args.now);
    const h = parts.find((p) => p.type === "hour")?.value;
    if (h === undefined) return false;
    let hour = parseInt(h, 10);
    if (Number.isNaN(hour)) return false;
    if (hour === 24) hour = 0; // some Node versions render midnight as "24"
    return hour === args.targetHour;
  } catch {
    return false;
  }
}

/**
 * Should the CF emit a digest push for this recipient? Combines pref
 * gates (`dailyDigest`, master `pushEnabled`) with content gate
 * (at least one non-zero counter). Pure.
 */
export function shouldFireDigest(args: {
  dailyDigest: boolean;
  pushEnabled: boolean;
  unread: number;
  pending: number;
  openSettlements: number;
}): boolean {
  if (!args.dailyDigest) return false;
  if (!args.pushEnabled) return false;
  const total = args.unread + args.pending + args.openSettlements;
  return total > 0;
}

/**
 * Builds the `placeholders` map handed to the digest template. Emits
 * raw counter strings AND a pre-formatted summary line so locales
 * don't each re-implement plural arithmetic. Zero counters drop out
 * of the summary entirely.
 */
export function buildDigestPlaceholders(args: {
  unread: number;
  pending: number;
  openSettlements: number;
}): Record<string, string> {
  const parts: string[] = [];
  if (args.unread > 0) {
    parts.push(
      `${args.unread} unread message${args.unread === 1 ? "" : "s"}`
    );
  }
  if (args.pending > 0) {
    parts.push(
      `${args.pending} pending task${args.pending === 1 ? "" : "s"}`
    );
  }
  if (args.openSettlements > 0) {
    parts.push(
      `${args.openSettlements} open settlement` +
        (args.openSettlements === 1 ? "" : "s")
    );
  }
  return {
    unread: String(args.unread),
    pending: String(args.pending),
    openSettlements: String(args.openSettlements),
    summary: parts.join(", "),
  };
}

/**
 * `onDigestSummary` — every 60 minutes, scan users with
 * `notificationPrefs.dailyDigest === true`, compute their local hour,
 * and dispatch the digest push when it's 9:00 in their timezone.
 *
 * The aggregation reads:
 *   - unread chat: messages newer than `users/{uid}/chatReads/{eventId}.lastReadAt`
 *     across the user's active events
 *   - pending tasks: `events/{eventId}/tasks` where `assigneeId == uid &&
 *     status != 'done'` across all events the user is in
 *   - open settlements: TBD — V1 uses `collectionGroup('expenses')` over
 *     the user's events and computes their net debt via the same
 *     BalanceLedger.calculate logic the client uses. For the first cut,
 *     count is the number of (counterparty, event) pairs they owe.
 *
 * Idempotency: the 60-minute schedule + hour-match check means each
 * user gets at most one digest per day. A failure mid-fan-out means
 * the next-hour run will NOT re-fire (the hour has moved on); a
 * subsequent retry would only land the next day. Acceptable for the
 * V1 cost profile.
 *
 * Best-effort: this trigger does not retry.
 */
export const onDigestSummary = onSchedule(
  {schedule: "every 60 minutes", retryCount: 0},
  async () => {
    const db = getFirestore();
    const now = new Date();
    let attempted = 0;
    let skipped = 0;
    let muted = 0;

    // Find every user with the opt-in flag set. The collection-group
    // query targets the `private/profile` subdoc that carries the pref.
    const optIns = await db
      .collectionGroup("private")
      .where("notificationPrefs.dailyDigest", "==", true)
      .get();

    for (const doc of optIns.docs) {
      // Path shape: users/{uid}/private/profile
      const segments = doc.ref.path.split("/");
      if (segments.length !== 4 || segments[2] !== "private") continue;
      const uid = segments[1];

      const data = doc.data();
      const prefs =
        (data.notificationPrefs as Record<string, unknown> | undefined) ??
        {};
      const pushEnabled = prefs.pushEnabled !== false;
      const dailyDigest = prefs.dailyDigest === true;
      const timezone =
        typeof prefs.timezone === "string" ? prefs.timezone : null;

      if (!isDigestHour({timezone, now, targetHour: DIGEST_HOUR})) {
        skipped++;
        continue;
      }

      // Aggregation — best-effort; failures count against `skipped`.
      let unread = 0;
      let pending = 0;
      let openSettlements = 0;
      try {
        const counters = await computeUserCounters(db, uid);
        unread = counters.unread;
        pending = counters.pending;
        openSettlements = counters.openSettlements;
      } catch (e) {
        logger.warn(`Digest aggregation failed for ${uid}`, e);
        skipped++;
        continue;
      }

      if (
        !shouldFireDigest({
          dailyDigest,
          pushEnabled,
          unread,
          pending,
          openSettlements,
        })
      ) {
        muted++;
        continue;
      }

      const placeholders = buildDigestPlaceholders({
        unread,
        pending,
        openSettlements,
      });

      const result = await sendCategorizedPush({
        recipientUids: [uid],
        senderId: null,
        category: "digest",
        // Digest is a per-user summary, not per-event. We still need
        // an eventId for the mute lookup; use a sentinel that never
        // matches a real event id so muteEvent never blocks digest.
        eventId: "__digest__",
        title: "Your morning summary",
        body: placeholders.summary,
        templateKey: "digest",
        placeholders,
        deepLink: "/dashboard",
      });
      attempted += result.attempted;
      skipped += result.skipped;
    }

    logger.info(
      `Digest sweep: ${attempted} sent, ${skipped} skipped, ${muted} muted`
    );
  }
);

/**
 * Per-user aggregation. Reads the user's chatReads + active events,
 * counts unread messages / pending tasks / debt rows. Errors propagate
 * to the caller, which counts the user against `skipped`.
 *
 * The implementation here is intentionally simple (single-pass, no
 * batching) — daily-digest fan-out is low-volume (opt-in only, ~hourly
 * scan, at most one fire per user per day) so the cost vs. complexity
 * trade favours readability. If digest opt-in adoption grows past
 * thousands the per-user cost should be revisited.
 */
async function computeUserCounters(
  db: Firestore,
  uid: string
): Promise<{unread: number; pending: number; openSettlements: number}> {
  // 1. Unread chat — read all chatReads docs to learn the user's
  // (eventId, lastReadAt) cursor, then count messages newer in each event.
  const chatReadsSnap = await db
    .collection("users")
    .doc(uid)
    .collection("chatReads")
    .get();
  let unread = 0;
  for (const readDoc of chatReadsSnap.docs) {
    const eventId = readDoc.id;
    const lastReadAt =
      (readDoc.data().lastReadAt as Timestamp | undefined) ??
      null;
    let query = db
      .collection("events")
      .doc(eventId)
      .collection("messages") as Query;
    if (lastReadAt) {
      query = query.where("timestamp", ">", lastReadAt);
    }
    const msgsSnap = await query.count().get();
    unread += msgsSnap.data().count;
  }

  // 2. Pending tasks — collectionGroup scan on tasks assigned to user
  // and not done. Requires a composite index on (assigneeId asc, status
  // asc) — see firestore.indexes.json.
  const tasksSnap = await db
    .collectionGroup("tasks")
    .where("assigneeId", "==", uid)
    .where("status", "!=", "done")
    .count()
    .get();
  const pending = tasksSnap.data().count;

  // 3. Open settlements — V1 stub: count of distinct events with at
  // least one expense the user did NOT pay. A proper net-debt
  // computation requires the same BalanceLedger logic the client runs
  // (per-event simplification of settlements). Deferred — accuracy here
  // is "is there anything to nudge me about?", not exact dollars.
  const expensesSnap = await db
    .collectionGroup("expenses")
    .where("payerId", "!=", uid)
    .count()
    .get();
  const openSettlements = expensesSnap.data().count;

  return {unread, pending, openSettlements};
}
