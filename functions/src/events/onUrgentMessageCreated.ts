import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import {
  DocumentData,
  DocumentReference,
  getFirestore,
} from "firebase-admin/firestore";
import {sendCategorizedPush} from "../notifications/sendPush";
import {isOrganizerVerified} from "./organizers";
import {readPermissions} from "./members";
import {readAllAccess, readsChat} from "./access";

const db = getFirestore();

/** Default urgent pushes per sender per event per hour. */
export const DEFAULT_URGENT_RATE_PER_HOUR = 5;

/**
 * Default rates by whether the event's organizer is verified. They match until
 * a verification flow exists, when unverified organizers can be limited (Req 24).
 */
export const DEFAULT_URGENT_RATES = {
  verified: DEFAULT_URGENT_RATE_PER_HOUR,
  unverified: DEFAULT_URGENT_RATE_PER_HOUR,
};

const WINDOW_MS = 60 * 60 * 1000;

/**
 * Takes one slot of the sender's rate for this event, inside a transaction so
 * that simultaneous messages cannot exceed it. Returns false when none is left.
 * Skipped messages take no slot, so they do not extend the wait.
 */
async function takeUrgentSlot(
  eventId: string,
  senderId: string,
  limit: number,
  nowMs: number
): Promise<boolean> {
  const rateRef = db
    .collection("events")
    .doc(eventId)
    .collection("urgentRates")
    .doc(senderId);
  return db.runTransaction(async (tx) => {
    const doc = await tx.get(rateRef);
    const sentAt: number[] = doc.data()?.sentAt ?? [];
    const recent = sentAt.filter((at) => at > nowMs - WINDOW_MS);
    if (recent.length >= limit) return false;
    tx.set(rateRef, {sentAt: [...recent, nowMs]});
    return true;
  });
}

interface UrgentMessage {
  eventId: string;
  messageId: string;
  data: DocumentData;
  ref: DocumentReference;
  /** Clock seam. */
  now?: () => number;
  /** Default rates, unless the event sets its own. */
  rates?: {verified: number; unverified: number};
}

/**
 * Sends the push for an urgent message, unless the sender has no permission or
 * is over the rate. Over the rate, the message stays and is flagged
 * `urgentPushSkipped`, which is how the sender is told.
 */
export async function handleUrgentMessage({
  eventId,
  messageId,
  data,
  ref,
  now = Date.now,
  rates = DEFAULT_URGENT_RATES,
}: UrgentMessage): Promise<void> {
  if (data.isHighPriority !== true) return;

  const senderId = (data.senderId as string | undefined) ?? "";
  const text = (data.text as string | undefined) ?? "";

  const eventDoc = await db.collection("events").doc(eventId).get();
  if (!eventDoc.exists) {
    logger.warn(`Event ${eventId} missing on urgent message ${messageId}`);
    return;
  }
  const eventData = eventDoc.data()!;
  const eventTitle = (eventData.title as string | undefined) ?? "Event";

  // Rules already require `chat.urgent`, and this checks it again.
  const permissions = await readPermissions(
    null,
    eventDoc.ref,
    eventData,
    senderId
  );
  if (!permissions.includes("chat.urgent")) {
    logger.warn(`Urgent message ${messageId} from a sender without permission`);
    return;
  }

  const configured = eventData.settings?.urgentRatePerHour;
  const limit =
    Number.isInteger(configured) && configured > 0 ?
      configured :
      (await isOrganizerVerified(db, eventData.organizerId)) ?
        rates.verified :
        rates.unverified;
  if (!(await takeUrgentSlot(eventId, senderId, limit, now()))) {
    await ref.update({urgentPushSkipped: true});
    logger.info(`Urgent message ${messageId} is over the rate; no push sent`);
    return;
  }

  const truncatedBody = text.length > 80 ? text.substring(0, 80) + "…" : text;

  // Only people who can read chat hear about it (Req 32).
  const recipientUids = (await readAllAccess(eventDoc.ref, eventData))
    .filter(readsChat)
    .map((m) => m.uid);
  const result = await sendCategorizedPush({
    recipientUids,
    senderId,
    category: "chat_urgent",
    eventId,
    // Phase 6 — title / body fall through to the recipient's locale
    // template (functions/src/notifications/templates/en.json today;
    // base-language + English fallback when other locales register).
    // Literal title/body remain as the back-compat path for any
    // recipient missing a matching template.
    title: `🚨 Urgent in ${eventTitle}`,
    body: truncatedBody,
    templateKey: "chat_urgent",
    placeholders: {eventTitle, body: truncatedBody},
    deepLink: `/dashboard/event/${eventId}/chat`,
    extraData: {eventId, messageId},
  });

  logger.info(
    `Urgent push for ${messageId}:` +
      ` ${result.attempted} attempted, ${result.skipped} skipped`
  );
}

/**
 * onUrgentMessageCreated — Firestore trigger that fans out a push when an
 * urgent (high-priority) chat message is created.
 *
 * Token resolution, per-recipient pref filtering, batched send and dead-token
 * pruning live in `sendCategorizedPush`.
 *
 * Best-effort: this trigger is not retried on failure (urgent push should
 * not fire twice from a retry storm).
 */
export const onUrgentMessageCreated = onDocumentCreated(
  {
    document: "events/{eventId}/messages/{messageId}",
    timeoutSeconds: 30,
    retry: false,
  },
  async (event) => {
    const data = event.data?.data();
    if (!data || !event.data) return;
    await handleUrgentMessage({
      eventId: event.params.eventId,
      messageId: event.params.messageId,
      data,
      ref: event.data.ref,
    });
  }
);
