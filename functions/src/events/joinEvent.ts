import {onCall, HttpsError} from "firebase-functions/v2/https";
import {expenseAccessOf} from "./expenseAccess";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {requireString, withStructuredLogs} from "../utils/logging";
import {assertOpenToJoin} from "./eventStatus";
import {memberDoc, memberRef, readEventRoles} from "./members";
import {inviteRoleId} from "./generateInviteCode";
import {recordInviteUse, unusableInvite} from "./inviteLinks";
import {inviteState} from "./inviteState";
import {PRESET_ROLES, isAdminLevel} from "./permissions";

const db = getFirestore();

/**
 * joinEvent — verifies a join code and adds the caller to the event.
 *
 * - Code must exist and be usable: not expired, not turned off, and for a
 *   single-use link not used yet (#238). An unusable one is `not-found`
 *   with `details.reason` (`expired`, `off` or `used`), which older apps
 *   show as an invalid or expired code
 * - Every join counts on the invite (`uses`); a single-use link records who
 *   used it, so it stops working
 * - The invite's role is applied (Req 31). A role the event has removed since,
 *   or an invite from before roles, gives Participant
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
        const inviteRef = db.collection("event_invites").doc(code);
        return db.runTransaction(async (tx) => {
          // The invite is read in the transaction, so two people cannot
          // both use a single-use link (#238).
          const codeDoc = await tx.get(inviteRef);
          const codeData = codeDoc.data();
          if (!codeData) {
            throw new HttpsError("not-found", "This code is invalid or has expired.");
          }
          const state = inviteState(codeData, Date.now());
          if (state !== "active") throw unusableInvite(state);

          const eventId: string = codeData.eventId;
          const eventRef = db.collection("events").doc(eventId);
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
          const invited = inviteRoleId(codeData);
          const roleId =
            invited !== "owner" && (PRESET_ROLES[invited] || roles[invited]) ?
              invited :
              "participant";
          recordInviteUse(tx, inviteRef, codeData, uid);
          tx.set(
            memberRef(eventRef, uid),
            memberDoc(uid, {roleIds: [roleId]}, roles, expenseAccessOf(eventData))
          );
          tx.update(eventRef, {
            memberIds: FieldValue.arrayUnion(uid),
            ...(isAdminLevel([roleId]) ?
              {adminIds: FieldValue.arrayUnion(uid)} :
              {}),
            memberCount: memberIds.length + 1,
            updatedAt: FieldValue.serverTimestamp(),
          });

          return {
            eventId,
            roleId,
            title: eventData.title,
            eventType: eventData.eventType,
          };
        });
      }
    );
  }
);
