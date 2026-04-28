import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import * as admin from "firebase-admin";

const db = admin.firestore();

const FCM_BATCH_SIZE = 500;

/**
 * onUrgentMessageCreated — Firestore trigger that fans out a push when an
 * urgent (high-priority) chat message is created.
 *
 * - Ignores non-urgent messages
 * - Loads the event to find recipient member ids
 * - Resolves their `fcmTokens`, skipping the sender
 * - sendEachForMulticast in 500-token chunks
 * - Prunes tokens that fail with `messaging/registration-token-not-registered`
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

    // Collect tokens for every recipient except the sender, tracking which
    // (uid, token) pair to prune if FCM rejects it.
    type TokenOwner = {uid: string; token: string};
    const owners: TokenOwner[] = [];
    for (const uid of memberIds) {
      if (uid === senderId) continue;
      const userSnap = await db.collection("users").doc(uid).get();
      const tokens = (userSnap.data()?.fcmTokens as string[] | undefined) ?? [];
      for (const token of tokens) {
        owners.push({uid, token});
      }
    }
    if (owners.length === 0) {
      logger.info(`No FCM recipients for urgent message ${messageId}`);
      return;
    }

    const truncatedBody = text.length > 80 ? text.substring(0, 80) + "…" : text;
    const notification = {
      title: `🚨 Urgent in ${eventTitle}`,
      body: truncatedBody,
    };
    const messageData = {
      eventId,
      messageId,
      deepLink: `/dashboard/event/${eventId}/chat`,
    };

    // Chunk by FCM_BATCH_SIZE and send.
    const messaging = admin.messaging();
    const deadTokens: TokenOwner[] = [];
    for (let i = 0; i < owners.length; i += FCM_BATCH_SIZE) {
      const chunk = owners.slice(i, i + FCM_BATCH_SIZE);
      const response = await messaging.sendEachForMulticast({
        tokens: chunk.map((o) => o.token),
        notification,
        data: messageData,
      });
      response.responses.forEach((res, idx) => {
        if (res.success) return;
        const code = res.error?.code ?? "";
        if (
          code === "messaging/registration-token-not-registered" ||
          code === "messaging/invalid-argument"
        ) {
          deadTokens.push(chunk[idx]);
        }
      });
    }

    // Prune dead tokens.
    if (deadTokens.length > 0) {
      const byUid = new Map<string, string[]>();
      for (const owner of deadTokens) {
        const list = byUid.get(owner.uid) ?? [];
        list.push(owner.token);
        byUid.set(owner.uid, list);
      }
      const batch = db.batch();
      for (const [uid, tokens] of byUid) {
        batch.update(db.collection("users").doc(uid), {
          fcmTokens: admin.firestore.FieldValue.arrayRemove(...tokens),
        });
      }
      await batch.commit();
      logger.info(
        `Pruned ${deadTokens.length} dead FCM tokens for ${byUid.size} users`
      );
    }

    logger.info(
      `Urgent push sent to ${owners.length} tokens for ${messageId}`
    );
  }
);
