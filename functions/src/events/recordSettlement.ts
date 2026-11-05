import {onCall, HttpsError} from "firebase-functions/v2/https";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {requireString, withStructuredLogs} from "../utils/logging";
import {DEFAULT_MAX_EXPENSE_AMOUNT} from "./saveExpense";
import {assertNotArchived} from "./eventStatus";
import {assertModuleOn} from "./eventModules";

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
 * A member records a payment they made to someone in the event. Holders of
 * `money.record` (owners and admins until permissions land) can also record a
 * payment to or from someone who has left, so that a former member's debt can
 * still be settled. Anyone else must have appeared on the event's expenses.
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

        // Older expenses have no involvedUids, so this reads the event's
        // expenses, but only when someone in this settlement has left.
        const hasHistory = async (person: string): Promise<boolean> => {
          const expenses = await eventRef
            .collection("expenses")
            .select("payerId", "splits")
            .get();
          return expenses.docs.some((doc) => {
            const expense = doc.data();
            return (
              expense.payerId === person ||
              (expense.splits ?? []).some(
                (split: {userId: string}) => split.userId === person
              )
            );
          });
        };

        await db.runTransaction(async (tx) => {
          const eventDoc = await tx.get(eventRef);
          if (!eventDoc.exists) {
            throw new HttpsError("not-found", "Event not found.");
          }
          const event = eventDoc.data()!;
          assertNotArchived(event);
          assertModuleOn(event, "budget");
          const memberIds: string[] = event.memberIds || [];

          const adminIds: string[] = event.adminIds || [];
          if (!memberIds.includes(uid)) {
            throw new HttpsError(
              "permission-denied",
              "Only event members can record a payment."
            );
          }
          if (payeeId === payerId) throw invalid("You cannot pay yourself.");

          const departed = [payerId, payeeId].filter(
            (person) => !memberIds.includes(person)
          );
          for (const person of departed) {
            if (!(await hasHistory(person))) {
              throw invalid("Both people must belong to this event.");
            }
          }

          const canRecordForOthers =
            event.creatorId === uid || adminIds.includes(uid);
          const isOwnPaymentToMember =
            payerId === uid && departed.length === 0;
          if (!isOwnPaymentToMember) {
            if (!canRecordForOthers || departed.length === 0) {
              throw new HttpsError(
                "permission-denied",
                "You can only record a payment you made, or one for someone " +
                  "who has left if you manage the event's money."
              );
            }
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
            recordedBy: uid,
            updatedAt: timestamp,
          });
          const symbol = CURRENCY_SYMBOLS[event.currency] ?? "$";
          const party = payerId !== uid ?
            "on behalf of a former member" :
            departed.length > 0 ? "with a former member" : "with a member";
          tx.set(noticeRef, {
            senderId: uid,
            text: `Settled ${symbol}${amount.toFixed(2)} ${party}`,
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
