import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import {getFirestore} from "firebase-admin/firestore";
import {sendCategorizedPush} from "../notifications/sendPush";
import {readAllAccess, readsExpense} from "./access";

const db = getFirestore();

/**
 * onExpenseCreated — pushes a "new expense" notification to every event
 * member who may read the expense, except the payer (Req 32). Includes
 * settlement payments (`isPayment: true`) because the counterparty does
 * benefit from a "they paid you back" ping; `onSettlementDisputed` covers
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
    await handleExpenseCreated({
      eventId: event.params.eventId,
      expenseId: event.params.expenseId,
      data,
    });
  }
);

export async function handleExpenseCreated({
  eventId,
  expenseId,
  data,
}: {
  eventId: string;
  expenseId: string;
  data: FirebaseFirestore.DocumentData;
}): Promise<void> {
  const payerId = (data.payerId as string | undefined) ?? "";
  const description = (data.description as string | undefined) ?? "Expense";
  const amount = data.amount as number | undefined;

  if (!payerId) {
    logger.warn(
      `Skipping onExpenseCreated: expense ${expenseId} missing payerId`
    );
    return;
  }

  const eventRef = db.collection("events").doc(eventId);
  const eventDoc = await eventRef.get();
  if (!eventDoc.exists) {
    logger.warn(
      `Event ${eventId} missing on expense-created trigger for ${expenseId}`
    );
    return;
  }
  const eventData = eventDoc.data() ?? {};
  const eventTitle = (eventData.title as string | undefined) ?? "Event";

  // Only people who may read the expense, minus the payer.
  // `sendCategorizedPush` also excludes `senderId` defensively.
  const recipientUids = (await readAllAccess(eventRef, eventData))
    .filter((m) => m.uid !== payerId && readsExpense(m, data))
    .map((m) => m.uid);
  if (recipientUids.length === 0) {
    logger.info(
      `No recipients for expense ${expenseId} in event ${eventId} ` +
        "(solo event or payer-only member list)"
    );
    return;
  }

  const formattedAmount =
    typeof amount === "number" ? `$${amount.toFixed(2)}` : "";
  const body = formattedAmount ?
    `${description} (${formattedAmount})` :
    description;

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
