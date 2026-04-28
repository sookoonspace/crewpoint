import {onCall, HttpsError} from "firebase-functions/v2/https";
import {logger} from "firebase-functions/v2";
import * as admin from "firebase-admin";

const db = admin.firestore();

/**
 * disputeSettlement — rolls back a settlement that the payer or payee
 * disputes.
 *
 * - Caller must be the payer or the payee of the settlement
 * - Deletes the settlement expense
 * - Replaces the chat notice text with a "disputed" line
 *
 * The chat notice has the same id as the expense (idempotent on retries).
 */
export const disputeSettlement = onCall(
  {timeoutSeconds: 30},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }

    const {eventId, settlementId} = request.data as {
      eventId?: string;
      settlementId?: string;
    };

    if (!eventId || !settlementId) {
      throw new HttpsError(
        "invalid-argument",
        "eventId and settlementId are required."
      );
    }

    const uid = request.auth.uid;

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
    const splits = (expense.splits as Array<{userId: string}> | undefined) ?? [];
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

    // Delete the settlement expense.
    await expenseRef.delete();

    // Replace the chat notice (same id) with a disputed line.
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
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true}
    );

    logger.info(
      `Settlement ${settlementId} disputed in event ${eventId} by ${uid}`
    );

    return {success: true};
  }
);
