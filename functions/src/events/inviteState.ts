/**
 * Member invite links (Spec #233 Req 15, #238): an event has several, each
 * `event_invites/{code}` with its own role, expiry and optional single use,
 * and each can be turned off. Pure, so the callables and tests share it.
 *
 * Fields: `eventId`, `roleId` (missing means Participant), `expiresAt`
 * (missing means no expiry, as `joinEvent` always allowed), `singleUse`,
 * `uses`, `usedBy` and `usedAt` (a single-use link's one join), `lastUsedAt`,
 * `turnedOffAt` and `turnedOffBy`, `createdBy` and `createdAt`. Invites from
 * before #238 have only the first three and read as active links that
 * anyone may use until they expire.
 */
import {DocumentData} from "firebase-admin/firestore";

/** Whether a link can be used now. */
export type InviteState = "active" | "used" | "expired" | "off";

/** Milliseconds from a Firestore timestamp, or null. */
function millis(value: unknown): number | null {
  const t = value as {toMillis?: () => number} | null | undefined;
  return typeof t?.toMillis === "function" ? t.toMillis() : null;
}

/** [invite]'s state at [now]: turned off, then used, then expired. */
export function inviteState(invite: DocumentData, now: number): InviteState {
  if (invite.turnedOffAt) return "off";
  if (invite.singleUse === true && invite.usedBy) return "used";
  const expiresAt = millis(invite.expiresAt);
  if (expiresAt !== null && expiresAt <= now) return "expired";
  return "active";
}

/** What `listInviteLinks` returns for one link. */
export interface InviteView {
  code: string;
  roleId: string;
  expiresAt: number | null;
  singleUse: boolean;
  uses: number;
  usedAt: number | null;
  turnedOffAt: number | null;
  createdAt: number | null;
  state: InviteState;
}

/** [invite] as the app lists it. */
export function inviteView(code: string, invite: DocumentData, now: number): InviteView {
  return {
    code,
    roleId: typeof invite.roleId === "string" ? invite.roleId : "participant",
    expiresAt: millis(invite.expiresAt),
    singleUse: invite.singleUse === true,
    uses: typeof invite.uses === "number" ? invite.uses : 0,
    usedAt: millis(invite.usedAt),
    turnedOffAt: millis(invite.turnedOffAt),
    createdAt: millis(invite.createdAt),
    state: inviteState(invite, now),
  };
}
