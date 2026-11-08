import {onCall, HttpsError} from "firebase-functions/v2/https";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {requireString, withStructuredLogs} from "../utils/logging";
import {assertNotArchived} from "./eventStatus";
import {readEventRoles, readPermissions, rebuildMember, requirePermission} from "./members";
import {expenseAccessOf, parseExpenseAccess} from "./expenseAccess";
import {calculateLedger, LedgerExpense} from "./ledger";

const db = getFirestore();

/** Member documents rebuilt per transaction, well under the 500-write cap. */
const CHUNK = 400;

const same = (a: unknown, b: unknown) => JSON.stringify(a) === JSON.stringify(b);

/**
 * setExpenseAccess — `event.manage` chooses who reads every expense (Req 38):
 * Everyone, Only people involved, or Selected roles and people. Saves
 * `settings.expenseAccess`, records the change in `settingsLog` with who made
 * it and when (Req 38b), and recalculates `expenses.readAll` on every member
 * document (Technical Decision 4a). Only reading changes.
 *
 * Safe to retry: the same option again records nothing and recalculates to
 * the same result. Member documents are rebuilt in transactions that each
 * read the event again, so a role change made meanwhile is never undone.
 */
export const setExpenseAccess = onCall({timeoutSeconds: 120}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const data = (request.data ?? {}) as {eventId?: unknown; access?: unknown};
  const eventId = requireString(data.eventId, "eventId");
  const access = parseExpenseAccess(data.access);
  const uid = request.auth.uid;

  return withStructuredLogs(
    {op: "setExpenseAccess", uid, args: {eventId, mode: access.mode}},
    async () => {
      const eventRef = db.collection("events").doc(eventId);
      await db.runTransaction(async (tx) => {
        const eventDoc = await tx.get(eventRef);
        if (!eventDoc.exists) {
          throw new HttpsError("not-found", "Event not found.");
        }
        const eventData = eventDoc.data()!;
        assertNotArchived(eventData);
        await requirePermission(
          tx, eventRef, eventData, uid, "event.manage",
          "Only people who manage the event can change who sees expenses."
        );
        const before = expenseAccessOf(eventData);
        if (same(before, access)) return;
        tx.update(eventRef, {
          "settings.expenseAccess": access,
          "updatedAt": FieldValue.serverTimestamp(),
        });
        tx.set(eventRef.collection("settingsLog").doc(), {
          setting: "expenseAccess",
          from: before,
          to: access,
          changedBy: uid,
          changedAt: FieldValue.serverTimestamp(),
        });
      });

      const members = await eventRef.collection("members").listDocuments();
      let changed = 0;
      for (let i = 0; i < members.length; i += CHUNK) {
        const refs = members.slice(i, i + CHUNK);
        changed += await db.runTransaction(async (tx) => {
          const [eventDoc, roles, ...docs] = await Promise.all([
            tx.get(eventRef),
            readEventRoles(tx, eventRef),
            ...refs.map((ref) => tx.get(ref)),
          ]);
          const current = expenseAccessOf(eventDoc.data());
          let count = 0;
          for (const doc of docs) {
            if (!doc.exists) continue;
            const rebuilt = rebuildMember(doc.id, doc.data()!, roles, current);
            if (same(rebuilt.permissions, doc.data()!.permissions)) continue;
            tx.update(doc.ref, {permissions: rebuilt.permissions});
            count++;
          }
          return count;
        });
      }
      return {success: true, changed};
    }
  );
});

/**
 * getMyBalance — the caller's own balance in an event, and the transfers
 * that settle it, worked out on the server from every expense (Req 38c). For
 * someone who may not read other people's expenses, this is how they still
 * see what they owe and who to pay. Nothing about other people's balances
 * is returned, beyond the transfers that involve the caller.
 */
export const getMyBalance = onCall({timeoutSeconds: 30}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const data = (request.data ?? {}) as {eventId?: unknown};
  const eventId = requireString(data.eventId, "eventId");
  const uid = request.auth.uid;

  return withStructuredLogs(
    {op: "getMyBalance", uid, args: {eventId}},
    async () => {
      const eventRef = db.collection("events").doc(eventId);
      const eventDoc = await eventRef.get();
      if (!eventDoc.exists) {
        throw new HttpsError("not-found", "Event not found.");
      }
      const eventData = eventDoc.data()!;
      const held = await readPermissions(null, eventRef, eventData, uid);
      if (held.length === 0) {
        throw new HttpsError("permission-denied", "You are not in this event.");
      }
      const expenses = await eventRef.collection("expenses").get();
      const ledger = calculateLedger(
        expenses.docs.map((d) => d.data() as LedgerExpense),
        (eventData.memberIds ?? []) as string[]
      );
      return {
        net: ledger.netBalances[uid] ?? 0,
        currency: (eventData.currency as string | undefined) ?? "USD",
        transfers: ledger.settlements.filter(
          (t) => t.fromUserId === uid || t.toUserId === uid
        ),
      };
    }
  );
});
