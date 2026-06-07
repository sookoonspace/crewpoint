import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {requireString, withStructuredLogs} from "../utils/logging";

const db = admin.firestore();

/**
 * disputeSettlement — rolls back a settlement that the payer or payee
 * disputes.
 *
 * - Caller must be the payer or the payee of the settlement
 * - Deletes the settlement expense
 * - Replaces the chat notice text with a "disputed" line
 *
 * The chat notice has the same id as the expense (idempotent on
 * retries).
 */
export const disputeSettlement = onCall(
  {timeoutSeconds: 30},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }

    const data = (request.data ?? {}) as {
      eventId?: unknown;
      settlementId?: unknown;
    };
    const eventId = requireString(data.eventId, "eventId");
    const settlementId = requireString(data.settlementId, "settlementId");

    const uid = request.auth.uid;

    return withStructuredLogs(
      {op: "disputeSettlement", uid, args: {eventId, settlementId}},
      async () => {
        const expenseRef = db
          .collection("events")
          .doc(eventId)
          .collection("expenses")
          .doc(settlementId);

        const expenseDoc = await expenseRef.get();
        if (!expenseDoc.exists) {
          throw new HttpsError("not-found", "Settlement not found.");
        }

        const expense = expenseDoc.data()!;
        if (!expense.isPayment) {
          throw new HttpsError(
            "failed-precondition",
            "Only settlements (isPayment) can be disputed."
          );
        }

        const payerId = expense.payerId as string | undefined;
        const splits =
          (expense.splits as Array<{userId: string}> | undefined) ?? [];
        const payeeId = splits[0]?.userId;

        if (!payerId || !payeeId) {
          throw new HttpsError(
            "failed-precondition",
            "Settlement is missing payer/payee data."
          );
        }

        if (uid !== payerId && uid !== payeeId) {
          throw new HttpsError(
            "permission-denied",
            "Only the payer or the payee can dispute this settlement."
          );
        }

        await expenseRef.delete();

        const noticeRef = db
          .collection("events")
          .doc(eventId)
          .collection("messages")
          .doc(settlementId);

        await noticeRef.set(
          {
            senderId: uid,
            text: "Settlement disputed",
            isHighPriority: false,
            kind: "settlement_disputed",
            // Snapshot the two parties on the notice so
            // `onSettlementDisputed` can route the push to the counterparty
            // — the original settlement expense has been deleted above so
            // the trigger has no other source for this.
            payerId,
            payeeId,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
          },
          {merge: true}
        );

        return {success: true};
      }
    );
  }
);
