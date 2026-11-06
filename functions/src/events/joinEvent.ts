import {onCall, HttpsError} from "firebase-functions/v2/https";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {requireString, withStructuredLogs} from "../utils/logging";
import {assertOpenToJoin} from "./eventStatus";
import {memberDoc, memberRef, readEventRoles} from "./members";

const db = getFirestore();

/**
 * joinEvent — verifies a join code and adds the caller to the event.
 *
 * - Code must exist and not be expired
 * - Caller must not already be a member
 * - Event must not exceed `memberLimit`, which caps how many people can log in.
 *   It is optional, and no value means unlimited.
 *
 * The check and the write share one transaction, so simultaneous joins cannot
 * exceed the limit. `memberCount` comes from `memberIds`, so an event from before
 * `memberCount` existed is corrected the first time someone joins.
 *
 * Idempotency: safe to retry. A retry whose first attempt already added the
 * caller hits the already-exists branch.
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

        const eventRef = db.collection("events").doc(eventId);

        return db.runTransaction(async (tx) => {
          const eventDoc = await tx.get(eventRef);
          if (!eventDoc.exists) {
            throw new HttpsError("not-found", "Event no longer exists.");
          }

          const eventData = eventDoc.data()!;
          assertOpenToJoin(eventData);
          const memberIds: string[] = eventData.memberIds || [];

          if (memberIds.includes(uid)) {
            throw new HttpsError(
              "already-exists",
              "You're already a member of this event."
            );
          }

          const memberLimit = eventData.memberLimit;
          const hasLimit = Number.isInteger(memberLimit) && memberLimit > 0;
          if (hasLimit && memberIds.length >= memberLimit) {
            throw new HttpsError("resource-exhausted", "This event is full.");
          }

          const roles = await readEventRoles(tx, eventRef);
          tx.set(
            memberRef(eventRef, uid),
            memberDoc(uid, {roleIds: ["participant"]}, roles)
          );
          tx.update(eventRef, {
            memberIds: FieldValue.arrayUnion(uid),
            memberCount: memberIds.length + 1,
            updatedAt: FieldValue.serverTimestamp(),
          });

          return {
            eventId,
            title: eventData.title,
            eventType: eventData.eventType,
          };
        });
      }
    );
  }
);
