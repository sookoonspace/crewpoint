import {onCall, HttpsError} from "firebase-functions/v2/https";
import {logger} from "firebase-functions/v2";
import * as admin from "firebase-admin";
import {commitInChunks, getSubcollectionRefs, BatchOperation} from "../utils/batch";

const db = admin.firestore();

/**
 * deleteEvent — deletes an event and all subcollections.
 *
 * - Caller must be the event creator (owner)
 * - Batch deletes messages, expenses, tasks subcollections
 * - Uses commitInChunks for 500-doc batch limit safety
 */
export const deleteEvent = onCall(
  {timeoutSeconds: 120, memory: "256MiB"},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }

    const {eventId} = request.data as {eventId?: string};
    if (!eventId) {
      throw new HttpsError("invalid-argument", "eventId is required.");
    }

    const uid = request.auth.uid;

    // Verify caller is creator
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

    logger.info(`Deleting event ${eventId} by owner ${uid}`);

    try {
      const ops: BatchOperation[] = [];

      // Collect all subcollection documents
      for (const sub of ["messages", "expenses", "tasks"]) {
        const refs = await getSubcollectionRefs(
          db.collection("events").doc(eventId),
          sub
        );
        for (const ref of refs) {
          ops.push({type: "delete", ref});
        }
      }

      // Delete any invite codes for this event
      const inviteCodes = await db
        .collection("event_invites")
        .where("eventId", "==", eventId)
        .get();

      for (const doc of inviteCodes.docs) {
        ops.push({type: "delete", ref: doc.ref});
      }

      // Delete the event document itself
      ops.push({
        type: "delete",
        ref: db.collection("events").doc(eventId),
      });

      await commitInChunks(ops);

      logger.info(`Event ${eventId} deleted successfully`);
      return {success: true};
    } catch (error) {
      logger.error(`Failed to delete event ${eventId}:`, error);
      throw new HttpsError(
        "internal",
        "Failed to delete event. Please try again."
      );
    }
  }
);
