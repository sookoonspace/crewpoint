/**
 * Waivers' pure rules (Spec #233 Req 26-29; #246): who a waiver applies to,
 * and whether a person's acceptance counts. Cases in
 * `test/fixtures/waiver_cases.json`, which the app's `waivers.dart` also
 * runs; change them together.
 */

/** Everyone, one category, or the people signed up for one session. */
export type WaiverAppliesTo =
  | {kind: "everyone"}
  | {kind: "category"; id: string}
  | {kind: "session"; id: string};

export interface WaiverPerson {
  categoryId: string | null;
  signUps: readonly string[];
}

export function waiverApplies(appliesTo: WaiverAppliesTo, person: WaiverPerson): boolean {
  switch (appliesTo.kind) {
  case "everyone": return true;
  case "category": return person.categoryId === appliesTo.id;
  case "session": return person.signUps.includes(appliesTo.id);
  }
}

/**
 * How an acceptance of version [accepted] (null when never accepted)
 * stands against the waiver's current [version]: `current`, `earlier` or
 * `missing`. An earlier version still counts unless the organizer requires
 * the latest (Req 28).
 */
export function acceptanceStatus(
  waiver: {version: number; requireLatest: boolean},
  accepted: number | null
): {status: "current" | "earlier" | "missing"; counts: boolean} {
  if (accepted === null) return {status: "missing", counts: false};
  if (accepted >= waiver.version) return {status: "current", counts: true};
  return {status: "earlier", counts: !waiver.requireLatest};
}
