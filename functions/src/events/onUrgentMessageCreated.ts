import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import {getFirestore} from "firebase-admin/firestore";
import {sendCategorizedPush} from "../notifications/sendPush";

const db = getFirestore();

/**
 * onUrgentMessageCreated — Firestore trigger that fans out a push when an
 * urgent (high-priority) chat message is created.
 *
 * Phase 3a refactor: token resolution + per-recipient pref filtering +
 * batched send + dead-token pruning now lives in `sendCategorizedPush`.
 * This trigger only carries the urgent-specific shape — the title prefix,
 * body truncation, and the chat deep-link.
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
    if (!data) return;

    const isUrgent = data.isHighPriority === true;
    if (!isUrgent) return;

    const eventId = event.params.eventId;
    const messageId = event.params.messageId;
    const senderId = (data.senderId as string | undefined) ?? "";
    const text = (data.text as string | undefined) ?? "";

    const eventDoc = await db.collection("events").doc(eventId).get();
    if (!eventDoc.exists) {
      logger.warn(`Event ${eventId} missing on urgent message ${messageId}`);
      return;
    }
    const eventData = eventDoc.data()!;
    const memberIds: string[] = eventData.memberIds || [];
    const eventTitle = (eventData.title as string | undefined) ?? "Event";

    const truncatedBody =
      text.length > 80 ? text.substring(0, 80) + "…" : text;

    const result = await sendCategorizedPush({
      recipientUids: memberIds,
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
);
