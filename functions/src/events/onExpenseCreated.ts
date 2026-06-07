import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import * as admin from "firebase-admin";
import {sendCategorizedPush} from "../notifications/sendPush";

const db = admin.firestore();

/**
 * onExpenseCreated — pushes a "new expense" notification to every event
 * member except the payer. Includes settlement payments (`isPayment: true`)
 * because the counterparty does benefit from a "they paid you back" ping;
 * Phase 3c.3 layers a dedicated `onSettlementDisputed` trigger on top for
 * the dispute path.
 *
 * Best-effort: not retried on failure. A missed push is preferable to a
 * duplicate one on retry storms.
 */
export const onExpenseCreated = onDocumentCreated(
  {
    document: "events/{eventId}/expenses/{expenseId}",
    timeoutSeconds: 30,
    retry: false,
  },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const eventId = event.params.eventId;
    const expenseId = event.params.expenseId;
    const payerId = (data.payerId as string | undefined) ?? "";
    const description = (data.description as string | undefined) ?? "Expense";
    const amount = data.amount as number | undefined;

    if (!payerId) {
      logger.warn(
        `Skipping onExpenseCreated: expense ${expenseId} missing payerId`
      );
      return;
    }

    const eventDoc = await db.collection("events").doc(eventId).get();
    if (!eventDoc.exists) {
      logger.warn(
        `Event ${eventId} missing on expense-created trigger for ${expenseId}`
      );
      return;
    }
    const eventData = eventDoc.data() ?? {};
    const eventTitle = (eventData.title as string | undefined) ?? "Event";
    const memberIds = (eventData.memberIds as string[] | undefined) ?? [];

    // Recipients = members minus payer. `sendCategorizedPush` additionally
    // excludes `senderId` defensively (handles the case where a stale
    // event doc still lists the payer twice).
    const recipientUids = memberIds.filter((uid) => uid !== payerId);
    if (recipientUids.length === 0) {
      logger.info(
        `No recipients for expense ${expenseId} in event ${eventId} ` +
          "(solo event or payer-only member list)"
      );
      return;
    }

    const formattedAmount =
      typeof amount === "number" ? `$${amount.toFixed(2)}` : "";
    const body = formattedAmount
      ? `${description} (${formattedAmount})`
      : description;

    const result = await sendCategorizedPush({
      recipientUids,
      senderId: payerId,
      category: "expense_added",
      eventId,
      title: `New expense in ${eventTitle}`,
      body,
      deepLink: `/dashboard/event/${eventId}/budget`,
      extraData: {eventId, expenseId},
    });

    logger.info(
      `Expense-added push for ${expenseId}:` +
        ` ${result.attempted} attempted, ${result.skipped} skipped`
    );
  }
);
