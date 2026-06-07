import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import * as admin from "firebase-admin";
import {sendCategorizedPush} from "../notifications/sendPush";

/**
 * Returns the counterparty of [disputerId] in a settlement between
 * [payerId] (debtor) and [payeeId] (creditor). Returns null when the
 * disputer is neither party — defensive guard against malformed notice
 * docs (the `disputeSettlement` callable enforces caller-is-party at the
 * auth layer, so we should never see this in practice).
 */
export function pickDisputeRecipient(
  disputerId: string,
  payerId: string,
  payeeId: string
): string | null {
  if (disputerId === payerId) return payeeId;
  if (disputerId === payeeId) return payerId;
  return null;
}

/**
 * onSettlementDisputed — fires when a "settlement_disputed" chat notice
 * is created (the original settlement expense has been deleted by the
 * `disputeSettlement` callable). Pushes the counterparty of the disputer
 * with a deep-link to the budget screen.
 *
 * Notice doc shape (written by `disputeSettlement`):
 *   {
 *     senderId: <disputer uid>,
 *     kind: 'settlement_disputed',
 *     payerId: <original debtor>,
 *     payeeId: <original creditor>,
 *     text, timestamp, isHighPriority: false
 *   }
 *
 * Shares the `events/{eventId}/messages/{messageId}` path with
 * `onUrgentMessageCreated`; the two coexist by filtering on different
 * shape fields (`kind === 'settlement_disputed'` here,
 * `isHighPriority === true` there).
 *
 * Best-effort: not retried on failure.
 */
export const onSettlementDisputed = onDocumentCreated(
  {
    document: "events/{eventId}/messages/{messageId}",
    timeoutSeconds: 30,
    retry: false,
  },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    if (data.kind !== "settlement_disputed") return;

    const eventId = event.params.eventId;
    const messageId = event.params.messageId;
    const disputerId = (data.senderId as string | undefined) ?? "";
    const payerId = (data.payerId as string | undefined) ?? "";
    const payeeId = (data.payeeId as string | undefined) ?? "";

    const recipient = pickDisputeRecipient(disputerId, payerId, payeeId);
    if (!recipient) {
      logger.warn(
        `onSettlementDisputed: cannot resolve counterparty` +
          ` (eventId=${eventId}, messageId=${messageId},` +
          ` disputerId=${disputerId})`
      );
      return;
    }

    const eventDoc = await admin
      .firestore()
      .collection("events")
      .doc(eventId)
      .get();
    if (!eventDoc.exists) {
      logger.warn(
        `Event ${eventId} missing on settlement-disputed trigger ${messageId}`
      );
      return;
    }
    const eventTitle =
      (eventDoc.data()?.title as string | undefined) ?? "Event";

    const result = await sendCategorizedPush({
      recipientUids: [recipient],
      senderId: disputerId,
      category: "settlement_disputed",
      eventId,
      title: `Settlement disputed in ${eventTitle}`,
      body: "Tap to review the budget.",
      deepLink: `/dashboard/event/${eventId}/budget`,
      extraData: {eventId},
    });

    logger.info(
      `Settlement-disputed push for ${messageId}:` +
        ` ${result.attempted} attempted, ${result.skipped} skipped`
    );
  }
);
