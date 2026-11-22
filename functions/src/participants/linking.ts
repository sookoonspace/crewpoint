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

/**
 * A signed-in account's verified email and verified phone (E.164), with
 * their match keys (Spec #233 Req 13). Either may be missing.
 */
export interface Identity {
  email?: string | null;
  phone?: string | null;
  emailKey?: string | null;
  phoneKey?: string | null;
}

/**
 * A participant record with what its private details carry, or, for an
 * unnamed entry, the match keys a deleted account left.
 */
export interface MatchRecord extends Candidate {
  eventId: string;
  email?: string | null;
  phone?: string | null;
  emailKey?: string | null;
  phoneKey?: string | null;
}

/** Whether [record] carries the account's email or phone, or their keys. */
function matches(record: MatchRecord, identity: Identity): boolean {
  const same = (a: string | null | undefined, b: string | null | undefined) => !!a && a === b;
  return same(record.email, identity.email) || same(record.phone, identity.phone) ||
    same(record.emailKey, identity.emailKey) || same(record.phoneKey, identity.phoneKey);
}

/**
 * What to do in each event where a record carries the account's verified
 * email or phone (Spec #233 Req 13). A record matched by both counts once,
 * and an email match and a phone match on two adults are two adults.
 */
export function decideLinks(
  records: readonly MatchRecord[],
  identity: Identity,
  uid: string
): Record<string, LinkDecision> {
  const byEvent = new Map<string, Map<string, MatchRecord>>();
  for (const r of records) {
    if (!matches(r, identity)) continue;
    const people = byEvent.get(r.eventId) ?? new Map<string, MatchRecord>();
    people.set(r.participantId, r);
    byEvent.set(r.eventId, people);
  }
  const decisions: Record<string, LinkDecision> = {};
  for (const [eventId, people] of byEvent) {
    decisions[eventId] = decideLink([...people.values()], uid);
  }
  return decisions;
}

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
