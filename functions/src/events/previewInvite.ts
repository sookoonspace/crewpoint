import {onCall, HttpsError} from "firebase-functions/v2/https";
import {Timestamp, getFirestore} from "firebase-admin/firestore";
import {requireString, withStructuredLogs} from "../utils/logging";
import {inviteRoleId} from "./generateInviteCode";
import {readEventRoles} from "./members";
import {PRESET_ROLES} from "./permissions";

const db = getFirestore();

/**
 * previewInvite — what a code from an invite link leads to, before joining
 * (Req 47, `/join/:code`): the event's title and start, the role it carries,
 * and whether the caller can join now. A draft, an ended or archived event,
 * a full one, or someone already in it is explained instead of failing at
 * the last step. Needs a signed-in caller, so codes cannot be tried
 * anonymously to read event titles.
 */
export const previewInvite = onCall({timeoutSeconds: 30}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const uid = request.auth.uid;
  const data = (request.data ?? {}) as {code?: unknown};
  const code = requireString(data.code, "code").trim().toUpperCase();
  if (code.length !== 6) {
    throw new HttpsError("invalid-argument", "code must be 6 characters.");
  }

  return withStructuredLogs({op: "previewInvite", uid, args: {code}}, async () => {
    const invite = await db.collection("event_invites").doc(code).get();
    const expiresAt = (invite.data()?.expiresAt as Timestamp | undefined)?.toMillis() ?? 0;
    if (!invite.exists || expiresAt <= Date.now()) {
      throw new HttpsError("not-found", "This code is invalid or has expired.");
    }
    const eventId: string = invite.data()!.eventId;
    const eventRef = db.collection("events").doc(eventId);
    const eventDoc = await eventRef.get();
    if (!eventDoc.exists) {
      throw new HttpsError("not-found", "This code is invalid or has expired.");
    }
    const event = eventDoc.data()!;
    const roleId = inviteRoleId(invite.data()!);
    const roles = await db.runTransaction((tx) => readEventRoles(tx, eventRef));
    const roleName: string =
      ((roles[roleId] as {name?: unknown} | undefined)?.name as string | undefined) ?? PRESET_ROLES[roleId]?.name ?? roleId;
    const memberIds: string[] = event.memberIds ?? [];
    const member = await eventRef.collection("members").doc(uid).get();
    const status: string = event.status ?? "published";
    const reason = ["draft", "ended", "archived"].includes(status) ? status : null;
    const limit = event.memberLimit;
    return {
      eventId,
      title: event.title ?? "",
      roleId,
      roleName,
      open: reason === null,
      reason,
      alreadyMember: member.exists || memberIds.includes(uid),
      full: Number.isInteger(limit) && limit > 0 && memberIds.length >= limit,
      startDate: (event.startDate as Timestamp | undefined)?.toMillis?.() ?? null,
      dateOnly: event.dateOnly === true,
      timeZone: event.timeZone ?? null,
      expiresAt,
    };
  });
});
