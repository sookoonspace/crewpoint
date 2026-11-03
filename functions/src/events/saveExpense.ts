import {onCall, HttpsError} from "firebase-functions/v2/https";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {requireString, withStructuredLogs} from "../utils/logging";

const db = getFirestore();

/** Matches the limit in the expense form. `settings.maxExpenseAmount` overrides it. */
export const DEFAULT_MAX_EXPENSE_AMOUNT = 10000000;

/** Allowed difference between the splits' total and the amount, per split. */
const SPLIT_TOLERANCE = 0.01;

interface Split {
  userId: string;
  amount: number;
}

function invalid(message: string): HttpsError {
  return new HttpsError("invalid-argument", message);
}

function requireOptionalString(value: unknown, field: string): string | null {
  if (value === undefined || value === null) return null;
  if (typeof value !== "string") throw invalid(`${field} must be a string.`);
  return value;
}

function requireSplits(value: unknown): Split[] {
  if (!Array.isArray(value)) throw invalid("splits must be a list.");
  const seen = new Set<string>();
  return value.map((raw) => {
    const split = (raw ?? {}) as {userId?: unknown; amount?: unknown};
    const userId = requireString(split.userId, "split userId");
    const amount = split.amount;
    if (typeof amount !== "number" || !Number.isFinite(amount) || amount < 0) {
      throw invalid("Each split must be a finite amount of zero or more.");
    }
    if (seen.has(userId)) throw invalid("A person can only be in splits once.");
    seen.add(userId);
    return {userId, amount};
  });
}

/**
 * saveExpense — creates or edits an expense. Firestore rules cannot loop over
 * splits, so this is the only way to write a non-payment expense.
 *
 * The client chooses the ID, so a retry after a lost response is an edit of the
 * same expense rather than a duplicate. It always saves a non-payment, and
 * settlement payments cannot be edited here.
 *
 * Who may act: a member adds an expense as its payer, and the payer, owner or
 * an admin may edit it. People already on an expense may stay on it after they
 * leave the event, so that editing it does not lose their share of a debt.
 */
export const saveExpense = onCall({timeoutSeconds: 30}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const uid = request.auth.uid;
  const data = (request.data ?? {}) as Record<string, unknown>;

  const eventId = requireString(data.eventId, "eventId");
  const expenseId = requireString(data.expenseId, "expenseId");
  if (expenseId.includes("/")) throw invalid("expenseId is not valid.");
  const payerId = requireString(data.payerId, "payerId");
  const amount = data.amount;
  if (typeof amount !== "number" || !Number.isFinite(amount) || amount <= 0) {
    throw invalid("Amount must be a finite number above zero.");
  }
  const description = requireOptionalString(data.description, "description");
  const receiptPath = requireOptionalString(data.receiptPath, "receiptPath");
  const isDonation = data.isDonation === true;
  const splits = requireSplits(data.splits);

  return withStructuredLogs(
    {op: "saveExpense", uid, args: {eventId, expenseId}},
    async () => {
      const eventRef = db.collection("events").doc(eventId);
      const expenseRef = eventRef.collection("expenses").doc(expenseId);

      await db.runTransaction(async (tx) => {
        const eventDoc = await tx.get(eventRef);
        if (!eventDoc.exists) {
          throw new HttpsError("not-found", "Event not found.");
        }
        const event = eventDoc.data()!;
        const memberIds: string[] = event.memberIds || [];
        const adminIds: string[] = event.adminIds || [];

        const maxAmount =
          event.settings?.maxExpenseAmount ?? DEFAULT_MAX_EXPENSE_AMOUNT;
        if (amount > maxAmount) {
          throw invalid(`Amount cannot be more than ${maxAmount}.`);
        }

        const existingDoc = await tx.get(expenseRef);
        const existing = existingDoc.exists ? existingDoc.data()! : null;

        if (!memberIds.includes(uid)) {
          throw new HttpsError(
            "permission-denied",
            "Only event members can save expenses."
          );
        }
        if (existing) {
          if (existing.isPayment === true) {
            throw new HttpsError(
              "failed-precondition",
              "A settlement payment cannot be edited."
            );
          }
          if (payerId !== existing.payerId) {
            throw invalid("The payer of an expense cannot change.");
          }
          const canEdit =
            existing.payerId === uid ||
            event.creatorId === uid ||
            adminIds.includes(uid);
          if (!canEdit) {
            throw new HttpsError(
              "permission-denied",
              "Only the payer, owner or an admin can edit this expense."
            );
          }
        } else if (payerId !== uid) {
          throw new HttpsError(
            "permission-denied",
            "You can only add an expense that you paid for."
          );
        }

        const alreadyOn: string[] = existing ?
          [
            existing.payerId,
            ...(existing.splits ?? []).map((s: Split) => s.userId),
          ] :
          [];
        const allowed = new Set([...memberIds, ...alreadyOn]);
        if (splits.some((s) => !allowed.has(s.userId))) {
          throw invalid("Everyone in the splits must be an event member.");
        }

        // The ledger reads no splits as "shared by all current members". A
        // donation with nobody to share it is the one valid case of that.
        const onlyMember = memberIds.length === 1 && memberIds[0] === payerId;
        if (splits.length === 0) {
          if (!(isDonation && onlyMember)) {
            throw invalid("An expense must be split between members.");
          }
        } else {
          const total = splits.reduce((sum, s) => sum + s.amount, 0);
          if (Math.abs(total - amount) > SPLIT_TOLERANCE * splits.length) {
            throw invalid("The splits must add up to the amount.");
          }
        }

        const fields = {
          eventId,
          payerId,
          amount,
          description,
          receiptPath,
          isDonation,
          isPayment: false,
          splits,
          involvedUids: [
            ...new Set([payerId, ...splits.map((s) => s.userId)]),
          ],
          updatedAt: FieldValue.serverTimestamp(),
        };
        tx.set(expenseRef, fields);
      });

      return {success: true};
    }
  );
});
