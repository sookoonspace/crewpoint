import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {requireString, withStructuredLogs} from "../utils/logging";

const db = admin.firestore();
const MAX_MEMBERS = 50;

/**
 * joinEvent — verifies a join code and adds the caller to the event.
 *
 * - Code must exist and not be expired
 * - Caller must not already be a member
 * - Event must not exceed `MAX_MEMBERS` (50) members
 *
 * Idempotency: safe to retry. A retry whose first attempt already
 * added the caller will hit the already-exists branch (the `arrayUnion`
 * has no idempotency on the wire, but `memberIds.includes(uid)` guards
 * against duplicate additions across retries within reasonable
 * windows — the underlying Firestore array-membership invariant).
 */
export const joinEvent = onCall(
  {timeoutSeconds: 30},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }

    const data = (request.data ?? {}) as {joinCode?: unknown};
    const joinCode = requireString(data.joinCode, "joinCode");
    if (joinCode.length !== 6) {
      throw new HttpsError(
        "invalid-argument",
        "joinCode must be a 6-character string."
      );
    }

    const uid = request.auth.uid;
    const code = joinCode.toUpperCase();

    return withStructuredLogs(
      {op: "joinEvent", uid, args: {code}},
      async () => {
        const codeDoc = await db.collection("event_invites").doc(code).get();
        if (!codeDoc.exists) {
          throw new HttpsError(
            "not-found",
            "This code is invalid or has expired."
          );
        }

        const codeData = codeDoc.data()!;

        const expiresAt = codeData.expiresAt?.toDate();
        if (expiresAt && expiresAt < new Date()) {
          await db.collection("event_invites").doc(code).delete();
          throw new HttpsError(
            "not-found",
            "This code is invalid or has expired."
          );
        }

        const eventId: string = codeData.eventId;

        const eventDoc = await db.collection("events").doc(eventId).get();
        if (!eventDoc.exists) {
          throw new HttpsError("not-found", "Event no longer exists.");
        }

        const eventData = eventDoc.data()!;
        const memberIds: string[] = eventData.memberIds || [];

        if (memberIds.includes(uid)) {
          throw new HttpsError(
            "already-exists",
            "You're already a member of this event."
          );
        }

        if (memberIds.length >= MAX_MEMBERS) {
          throw new HttpsError(
            "resource-exhausted",
            `This event is full (max ${MAX_MEMBERS} members).`
          );
        }

        await db.collection("events").doc(eventId).update({
          memberIds: admin.firestore.FieldValue.arrayUnion(uid),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        return {
          eventId,
          title: eventData.title,
          eventType: eventData.eventType,
        };
      }
    );
  }
);
