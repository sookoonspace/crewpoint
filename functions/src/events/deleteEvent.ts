import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {streamDeleteSubcollection} from "../utils/batch";
import {requireString, withStructuredLogs} from "../utils/logging";

const db = admin.firestore();

/**
 * deleteEvent — deletes an event and all subcollections.
 *
 * - Caller must be the event creator (owner)
 * - Streams delete of `messages`, `expenses`, `tasks` subcollections
 *   in pages of 500 (bounded memory; safe for 100k+ message events)
 * - Deletes any active invite codes for the event
 * - Deletes the event doc itself
 *
 * **Memory bound**: at most 500 doc refs in flight at any time. The
 * 256 MiB function memory cap is never approached regardless of
 * subcollection size.
 *
 * Idempotency: a retry that runs after the first attempt deleted some
 * subset of docs simply re-pages through the surviving docs (Firestore
 * tolerates `delete` on a missing doc; the streaming pattern handles
 * gaps without special-casing). The second invocation either finds
 * `not-found` on the event doc (already deleted) or finds an empty
 * subcollection page on the first iteration of each loop.
 */
export const deleteEvent = onCall(
  {timeoutSeconds: 540, memory: "256MiB"},
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
        const eventRef = db.collection("events").doc(eventId);
        const eventDoc = await eventRef.get();
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

        for (const sub of ["messages", "expenses", "tasks"]) {
          await streamDeleteSubcollection(eventRef, sub);
        }

        const inviteCodes = await db
          .collection("event_invites")
          .where("eventId", "==", eventId)
          .get();
        if (!inviteCodes.empty) {
          const batch = db.batch();
          for (const doc of inviteCodes.docs) {
            batch.delete(doc.ref);
          }
          await batch.commit();
        }

        await eventRef.delete();

        return {success: true};
      }
    );
  }
);
