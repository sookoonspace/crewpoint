/**
 * Which participant record a signed-in person links to (Req 46, X-05). Pure,
 * so it is unit-tested apart from Firestore.
 *
 * Only adult records count, decided in #78: registration exports often repeat
 * a parent's email on every row of a family. Exactly one adult with the email
 * links. Two or more adults, or only children, are ambiguous and go to an
 * organizer. Children are never linked to an account, and a record is never
 * matched on its name.
 */

/** A record carrying the person's verified email, or its match key. */
export interface Candidate {
  participantId: string;
  groupId: string | null;
  isChild: boolean;
  /** The account it is linked to already, if any. */
  linkedUid: string | null;
  status: string;
}

export type LinkDecision =
  | {kind: "none"}
  | {kind: "linked"; participantId: string}
  | {kind: "link"; participantId: string}
  | {kind: "ask"; participantIds: string[]; groupIds: string[]};

export function decideLink(candidates: readonly Candidate[], uid: string): LinkDecision {
  const mine = candidates.find((c) => c.linkedUid === uid);
  if (mine) return {kind: "linked", participantId: mine.participantId};
  const open = candidates.filter((c) => c.linkedUid === null && c.status !== "cancelled");
  if (open.length === 0) return {kind: "none"};
  const adults = open.filter((c) => !c.isChild);
  if (adults.length === 1) return {kind: "link", participantId: adults[0].participantId};
  return {
    kind: "ask",
    participantIds: open.map((c) => c.participantId),
    groupIds: [...new Set(open.map((c) => c.groupId).filter((g): g is string => g !== null))],
  };
}
