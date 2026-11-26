/**
 * The registration change log's diff (Spec #233 Req 36; #244, B-06): which
 * fields changed between two snapshots of a registration, with the person
 * they belong to and the values before and after. Pure; the callables
 * write one `changes/{id}` entry holding the list, with who and when.
 */

export interface PersonSnapshot {
  name: string;
  birthDate?: string | null;
  age?: number | null;
  answers: Record<string, unknown>;
  arrivalAt?: number | null;
  departureAt?: number | null;
  signUps?: string[];
  optOuts?: string[];
}

export interface RegistrationSnapshot {
  groupName: string;
  email: string | null;
  phone: string | null;
  groupAnswers: Record<string, unknown>;
  /** By participant ID. */
  people: Record<string, PersonSnapshot>;
}

export interface FieldChange {
  /** Such as `email`, `groupAnswers.hotel`, `people.<id>.answers.diet`, `people.<id>`. */
  field: string;
  /** The person's name for a person's field, else null. */
  person: string | null;
  before: unknown;
  after: unknown;
}

/** Lists compare as sets; everything else by value. */
function same(a: unknown, b: unknown): boolean {
  const norm = (v: unknown): unknown => (v === undefined ? null : v);
  const x = norm(a);
  const y = norm(b);
  if (Array.isArray(x) && Array.isArray(y)) {
    return x.length === y.length && [...x].map(String).sort().join("\u0000") === [...y].map(String).sort().join("\u0000");
  }
  if (Array.isArray(x) || Array.isArray(y)) {
    const list = (Array.isArray(x) ? x : y) as unknown[];
    const other = Array.isArray(x) ? y : x;
    return list.length === 0 && other === null;
  }
  return JSON.stringify(x) === JSON.stringify(y);
}

function compareMaps(
  prefix: string,
  person: string | null,
  before: Record<string, unknown>,
  after: Record<string, unknown>,
  out: FieldChange[]
): void {
  const keys = [...new Set([...Object.keys(before), ...Object.keys(after)])].sort();
  for (const k of keys) {
    if (!same(before[k], after[k])) {
      out.push({field: `${prefix}.${k}`, person, before: before[k] ?? null, after: after[k] ?? null});
    }
  }
}

export function diffRegistration(before: RegistrationSnapshot, after: RegistrationSnapshot): FieldChange[] {
  const out: FieldChange[] = [];
  for (const k of ["groupName", "email", "phone"] as const) {
    if (!same(before[k], after[k])) out.push({field: k, person: null, before: before[k] ?? null, after: after[k] ?? null});
  }
  compareMaps("groupAnswers", null, before.groupAnswers, after.groupAnswers, out);
  const ids = [...new Set([...Object.keys(before.people), ...Object.keys(after.people)])].sort();
  for (const id of ids) {
    const was = before.people[id];
    const now = after.people[id];
    if (!was || !now) {
      const name = (was ?? now)!.name;
      out.push({field: `people.${id}`, person: name, before: was ? name : null, after: now ? name : null});
      continue;
    }
    const person = now.name;
    for (const k of ["name", "birthDate", "age"] as const) {
      if (!same(was[k], now[k])) out.push({field: `people.${id}.${k}`, person, before: was[k] ?? null, after: now[k] ?? null});
    }
    compareMaps(`people.${id}.answers`, person, was.answers, now.answers, out);
    for (const k of ["arrivalAt", "departureAt", "signUps", "optOuts"] as const) {
      if (!same(was[k], now[k])) out.push({field: `people.${id}.${k}`, person, before: was[k] ?? null, after: now[k] ?? null});
    }
  }
  return out;
}
