import {onCall, HttpsError} from "firebase-functions/v2/https";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {requireString, withStructuredLogs} from "../utils/logging";
import {DEFAULT_MAX_EXPENSE_AMOUNT} from "./saveExpense";

const db = getFirestore();

const CURRENCY_SYMBOLS: Record<string, string> = {
  EUR: "€",
  GBP: "£",
  JPY: "¥",
  INR: "₹",
};

function invalid(message: string): HttpsError {
  return new HttpsError("invalid-argument", message);
}

/**
 * recordSettlement — records that the caller paid someone, writing the payment
 * and its chat notice together. The server writes the notice text, so neither
 * the amount nor the wording can be forged.
 *
 * The client chooses the ID, which both documents share. Sending the same
 * settlement again changes nothing, so a retry after a lost response is safe.
 */
export const recordSettlement = onCall(
  {timeoutSeconds: 30},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }
    const uid = request.auth.uid;
    const data = (request.data ?? {}) as Record<string, unknown>;

    const eventId = requireString(data.eventId, "eventId");
    const settlementId = requireString(data.settlementId, "settlementId");
    if (settlementId.includes("/")) throw invalid("settlementId is not valid.");
    const payerId = requireString(data.payerId, "payerId");
    const payeeId = requireString(data.payeeId, "payeeId");
    const amount = data.amount;
    if (typeof amount !== "number" || !Number.isFinite(amount) || amount <= 0) {
      throw invalid("Amount must be a finite number above zero.");
    }

    return withStructuredLogs(
      {op: "recordSettlement", uid, args: {eventId, settlementId}},
      async () => {
        const eventRef = db.collection("events").doc(eventId);
        const expenseRef = eventRef.collection("expenses").doc(settlementId);
        const noticeRef = eventRef.collection("messages").doc(settlementId);

        await db.runTransaction(async (tx) => {
          const eventDoc = await tx.get(eventRef);
          if (!eventDoc.exists) {
            throw new HttpsError("not-found", "Event not found.");
          }
          const event = eventDoc.data()!;
          const memberIds: string[] = event.memberIds || [];

          if (payerId !== uid || !memberIds.includes(uid)) {
            throw new HttpsError(
              "permission-denied",
              "You can only record a payment that you made in your own event."
            );
          }
          if (payeeId === payerId) throw invalid("You cannot pay yourself.");
          if (!memberIds.includes(payeeId)) {
            throw invalid("The person paid must be an event member.");
          }
          const maxAmount =
            event.settings?.maxExpenseAmount ?? DEFAULT_MAX_EXPENSE_AMOUNT;
          if (amount > maxAmount) {
            throw invalid(`Amount cannot be more than ${maxAmount}.`);
          }

          const existingDoc = await tx.get(expenseRef);
          if (existingDoc.exists) {
            const existing = existingDoc.data()!;
            const isSameSettlement =
              existing.isPayment === true &&
              existing.payerId === payerId &&
              existing.amount === amount &&
              existing.splits?.[0]?.userId === payeeId;
            if (isSameSettlement) return;
            throw new HttpsError(
              "already-exists",
              "This ID belongs to a different expense."
            );
          }

          const timestamp = FieldValue.serverTimestamp();
          tx.set(expenseRef, {
            eventId,
            payerId,
            amount,
            description: null,
            receiptPath: null,
            isDonation: false,
            isPayment: true,
            splits: [{userId: payeeId, amount}],
            involvedUids: [payerId, payeeId],
            updatedAt: timestamp,
          });
          const symbol = CURRENCY_SYMBOLS[event.currency] ?? "$";
          tx.set(noticeRef, {
            senderId: payerId,
            text: `Settled ${symbol}${amount.toFixed(2)} with a member`,
            isHighPriority: false,
            kind: "settlement",
            timestamp,
          });
        });

        return {success: true};
      }
    );
  }
);
