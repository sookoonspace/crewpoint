import {FieldValue} from "firebase-admin/firestore";
import {acceptanceStatus, waiverApplies, WaiverAppliesTo} from "./waivers";

/**
 * Waiver acceptances on the server (Spec #233 Req 27-29; #246). Each
 * person's acceptances live in `participants/{id}/private/waivers` as
 * `accepted: {waiverId: {version, at, by, as}}`, written only here: `as`
 * is `self` for the account's own person, `guardian` for a child and
 * `onBehalf` for another adult. Never edited, only added to: accepting a
 * newer version replaces that waiver's entry. The person carries
 * `missingWaivers` (IDs) and `waiversMissing` for the Missing waiver list.
 */

export interface WaiverDoc {
  id: string;
  title: {en: string; gu?: string};
  version: number;
  appliesTo: WaiverAppliesTo;
  required: boolean;
  requireLatest: boolean;
}

export type Accepted = Record<string, {version: number}>;

export async function loadWaivers(eventRef: FirebaseFirestore.DocumentReference): Promise<WaiverDoc[]> {
  const snap = await eventRef.collection("waivers").get();
  return snap.docs.map((d) => {
    const w = d.data();
    return {
      id: d.id,
      title: w.title ?? {en: ""},
      version: typeof w.version === "number" ? w.version : 1,
      appliesTo: w.appliesTo ?? {kind: "everyone"},
      required: w.required === true,
      requireLatest: w.requireLatest !== false,
    };
  });
}

interface Person {
  categoryId: string | null;
  signUps: readonly string[];
}

/** The waivers that apply to [person] and do not count yet. */
export function missingFor(person: Person, waivers: readonly WaiverDoc[], accepted: Accepted): string[] {
  return waivers
    .filter((w) => waiverApplies(w.appliesTo, person))
    .filter((w) => !acceptanceStatus(w, accepted[w.id]?.version ?? null).counts)
    .map((w) => w.id)
    .sort();
}

/** Required waivers [person] still needs, once [accepting] is accepted (Req 29). */
export function requiredMissing(
  person: Person,
  waivers: readonly WaiverDoc[],
  accepted: Accepted,
  accepting: readonly string[]
): string[] {
  const after = withAccepted(accepted, accepting, waivers);
  return missingFor(person, waivers.filter((w) => w.required), after);
}

/** [accepted] with [accepting] at each waiver's current version. */
export function withAccepted(accepted: Accepted, accepting: readonly string[], waivers: readonly WaiverDoc[]): Accepted {
  const out: Accepted = {...accepted};
  for (const id of accepting) {
    const w = waivers.find((x) => x.id === id);
    if (w) out[id] = {version: w.version};
  }
  return out;
}

/**
 * The writes for [accepting] on one person: their acceptance entries (with
 * who and as whom) and their missing list. [accepted] is what they held.
 */
export function acceptanceWrites(args: {
  accepting: readonly string[];
  accepted: Accepted;
  waivers: readonly WaiverDoc[];
  person: Person;
  by: string;
  as: "self" | "guardian" | "onBehalf";
}): {entries: Record<string, unknown>; missing: string[]} {
  const known = args.accepting.filter((id) => args.waivers.some((w) => w.id === id));
  const entries: Record<string, unknown> = {};
  for (const id of known) {
    const w = args.waivers.find((x) => x.id === id)!;
    if ((args.accepted[id]?.version ?? 0) >= w.version) continue;
    entries[id] = {version: w.version, at: FieldValue.serverTimestamp(), by: args.by, as: args.as};
  }
  const after = withAccepted(args.accepted, known, args.waivers);
  return {entries, missing: missingFor(args.person, args.waivers, after)};
}

/** As whom [by] accepts for a person (Req 27). */
export function acceptedAs(person: {isChild: boolean; uid?: string | null}, by: string): "self" | "guardian" | "onBehalf" {
  if (person.isChild) return "guardian";
  return person.uid === by ? "self" : "onBehalf";
}

/** A person's accepted versions, from `waiverVersions` on their record. */
export function acceptedOf(person: FirebaseFirestore.DocumentData | undefined): Accepted {
  const raw = person?.waiverVersions;
  const out: Accepted = {};
  if (raw && typeof raw === "object") {
    for (const [id, v] of Object.entries(raw)) if (typeof v === "number") out[id] = {version: v};
  }
  return out;
}

/** The person-record fields for [accepted] after [accepting], and [missing]. */
export function waiverFields(accepted: Accepted, entries: Record<string, unknown>, missing: string[]): Record<string, unknown> {
  const versions: Record<string, number> = {};
  for (const [id, a] of Object.entries(accepted)) versions[id] = a.version;
  for (const [id, e] of Object.entries(entries)) versions[id] = (e as {version: number}).version;
  return {waiverVersions: versions, missingWaivers: missing, waiversMissing: missing.length > 0};
}

/**
 * For each form person, the required waivers they still miss once their
 * `acceptWaivers` are accepted, as `people[i].waivers` problems (Req 29).
 */
export function requiredProblems(
  people: ReadonlyArray<{categoryId: string | null; signUps: string[]; acceptWaivers: string[]}>,
  waivers: readonly WaiverDoc[],
  acceptedFor: (i: number) => Accepted
): string[] {
  return people.flatMap((p, i) =>
    requiredMissing(p, waivers, acceptedFor(i), p.acceptWaivers).length > 0 ? [`people[${i}].waivers`] : []);
}

/**
 * Writes one person's acceptances in [tx] (their `private/waivers`, merged,
 * only when something new is accepted) and returns the fields for their
 * record.
 */
export function writeAcceptances(
  tx: FirebaseFirestore.Transaction,
  personRef: FirebaseFirestore.DocumentReference,
  args: Parameters<typeof acceptanceWrites>[0]
): Record<string, unknown> {
  const {entries, missing} = acceptanceWrites(args);
  if (Object.keys(entries).length > 0) {
    tx.set(personRef.collection("private").doc("waivers"), {accepted: entries}, {merge: true});
  }
  return waiverFields(args.accepted, entries, missing);
}
