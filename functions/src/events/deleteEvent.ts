import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {commitInChunks, getSubcollectionRefs, BatchOperation} from "../utils/batch";
import {requireString, withStructuredLogs} from "../utils/logging";

const db = admin.firestore();

/**
 * deleteEvent — deletes an event and all subcollections.
 *
 * - Caller must be the event creator (owner)
 * - Batch deletes messages, expenses, tasks subcollections
 * - Uses commitInChunks for 500-doc batch limit safety
 *
 * **Known memory risk** (deferred to Phase 4): the current
 * implementation collects every subcollection ref into memory before
 * chunking. A 100k-message event would OOM the 256 MiB function
 * before the first batch commits. Tracked for streaming-pagination
 * refactor.
 *
 * Idempotency: a retry that runs after the first attempt deleted some
 * subset of docs will simply re-issue empty deletes for the missing
 * docs (Firestore tolerates `delete` on a missing doc) and converge on
 * the same end state.
 */
export const deleteEvent = onCall(
  {timeoutSeconds: 120, memory: "256MiB"},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }

    const data = (request.data ?? {}) as {eventId?: unknown};
    const eventId = requireString(data.eventId, "eventId");

    const uid = request.auth.uid;

    return withStructuredLogs(
      {op: "deleteEvent", uid, args: {eventId}},
      async () => {
        const eventDoc = await db.collection("events").doc(eventId).get();
        if (!eventDoc.exists) {
          throw new HttpsError("not-found", "Event not found.");
        }

        const eventData = eventDoc.data()!;
        if (eventData.creatorId !== uid) {
          throw new HttpsError(
            "permission-denied",
            "Only the event creator can delete the event."
          );
        }

        const ops: BatchOperation[] = [];

        for (const sub of ["messages", "expenses", "tasks"]) {
          const refs = await getSubcollectionRefs(
            db.collection("events").doc(eventId),
            sub
          );
          for (const ref of refs) {
            ops.push({type: "delete", ref});
          }
        }

        const inviteCodes = await db
          .collection("event_invites")
          .where("eventId", "==", eventId)
          .get();

        for (const doc of inviteCodes.docs) {
          ops.push({type: "delete", ref: doc.ref});
        }

        ops.push({
          type: "delete",
          ref: db.collection("events").doc(eventId),
        });

        await commitInChunks(ops);

        return {success: true};
      }
    );
  }
);
