/**
 * Plans a roster import (Req 44, 45) from parsed CSV rows. Pure: no
 * Firestore, so it is unit-tested and shared by the dry run and the apply.
 * Source-agnostic (L6): any export works once its columns are mapped.
 */

/** What a column is mapped to. `field:<id>` is a custom field. */
export type Target =
  | "ignore" | "name" | "group" | "externalId" | "birthDate" | "age"
  | "isChild" | "category" | "email" | `field:${string}`;

export interface FieldDef {
  id: string;
  label: string;
  type: string;
  options: readonly string[];
  required: boolean;
  scope: string;
  visibility: string;
}

export interface CategoryDef {
  id: string;
  name: string;
  minAge?: number;
  maxAge?: number;
  isChild?: boolean;
}

export interface ExistingPerson {
  id: string;
  name: string;
  groupId: string | null;
  externalId?: string | null;
  imported?: boolean;
  status?: string;
}

export interface ImportContext {
  fields: FieldDef[];
  categories: CategoryDef[];
  /** The event's first day, `YYYY-MM-DD`, for ages. */
  eventStart: string | null;
  existing: ExistingPerson[];
  existingGroups: {id: string; name: string}[];
}

export type Problem =
  | "required" | "unknownAge" | "duplicateEmail" | "badEmail" | "notAnOption"
  | "wrongType" | "tooLong" | "duplicateRow" | "unknownCategory";

export interface RowError {
  /** 1-based, counting the header as row 1, as a spreadsheet shows it. */
  row: number;
  column: string;
  problem: Problem;
}

export interface PlannedPerson {
  row: number;
  name: string;
  groupName: string | null;
  /** The existing group it goes in, or null for a new or no group. */
  groupId: string | null;
  externalId: string | null;
  /** Only the columns that were mapped; anything else is left as it is. */
  birthDate?: string | null;
  isChild?: boolean;
  categoryId?: string | null;
  email?: string | null;
  standard: Record<string, unknown>;
  private: Record<string, unknown>;
  groupStandard: Record<string, unknown>;
  /** The existing participant it updates, or null for someone new. */
  match: string | null;
}

export interface Plan {
  total: number;
  people: PlannedPerson[];
  errors: RowError[];
  mappingProblems: string[];
  creates: number;
  updates: number;
  newGroups: string[];
  /** Imported groups with nobody in this file, for review (Req 45). */
  missingGroups: {groupId: string | null; name: string; participantIds: string[]}[];
}

export const normalise = (s: string | null | undefined): string =>
  (s ?? "").trim().replace(/\s+/g, " ").toLowerCase();

const personKey = (group: string | null | undefined, name: string) =>
  `${normalise(group)}|${normalise(name)}`;

/** `YYYY-MM-DD`, or `M/D/YYYY` as US tools export it. Null if unreadable. */
export function readDate(text: string): string | null {
  const t = text.trim();
  let y: number; let m: number; let d: number;
  let match = /^(\d{4})-(\d{1,2})-(\d{1,2})$/.exec(t);
  if (match) {
    [y, m, d] = [Number(match[1]), Number(match[2]), Number(match[3])];
  } else if ((match = /^(\d{1,2})\/(\d{1,2})\/(\d{4})$/.exec(t))) {
    [m, d, y] = [Number(match[1]), Number(match[2]), Number(match[3])];
  } else {
    return null;
  }
  const date = new Date(Date.UTC(y, m - 1, d));
  if (date.getUTCFullYear() !== y || date.getUTCMonth() !== m - 1 || date.getUTCDate() !== d) {
    return null;
  }
  return `${String(y).padStart(4, "0")}-${String(m).padStart(2, "0")}-${String(d).padStart(2, "0")}`;
}

/** Whole years from [birthDate] to [on], both `YYYY-MM-DD`. */
export function ageOn(birthDate: string, on: string): number {
  const [by, bm, bd] = birthDate.split("-").map(Number);
  const [oy, om, od] = on.split("-").map(Number);
  let age = oy - by;
  if (om < bm || (om === bm && od < bd)) age--;
  return age;
}

/** The first category whose age rule fits [age]. */
export function categoryForAge(age: number, categories: readonly CategoryDef[]): CategoryDef | null {
  for (const c of categories) {
    const ruled = c.minAge !== undefined || c.maxAge !== undefined;
    if (ruled && (c.minAge === undefined || age >= c.minAge) &&
      (c.maxAge === undefined || age <= c.maxAge)) return c;
  }
  return null;
}

const YES = ["yes", "y", "true", "1"];
const NO = ["no", "n", "false", "0"];

/** A cell read as an answer to [field]: the value, or why it cannot be. */
function readAnswer(field: FieldDef, text: string): {value?: unknown; problem?: Problem} {
  const t = text.trim();
  if (t === "") return field.required ? {problem: "required"} : {};
  switch (field.type) {
  case "number": {
    const n = Number(t);
    return Number.isFinite(n) ? {value: n} : {problem: "wrongType"};
  }
  case "date": {
    const d = readDate(t);
    return d ? {value: d} : {problem: "wrongType"};
  }
  case "yesNo":
    if (YES.includes(t.toLowerCase())) return {value: true};
    if (NO.includes(t.toLowerCase())) return {value: false};
    return {problem: "wrongType"};
  case "singleChoice": {
    const option = field.options.find((o) => normalise(o) === normalise(t));
    return option ? {value: option} : {problem: "notAnOption"};
  }
  case "multiChoice": {
    const picked = t.split(/[;|]/).map((p) => p.trim()).filter(Boolean);
    const options = picked.map((p) => field.options.find((o) => normalise(o) === normalise(p)));
    return options.every(Boolean) ? {value: options} : {problem: "notAnOption"};
  }
  default:
    return t.length > 500 ? {problem: "tooLong"} : {value: t};
  }
}

export function planImport(rows: string[][], targets: Target[], ctx: ImportContext): Plan {
  const [header = [], ...data] = rows;
  const columnOf = (target: Target) => targets.indexOf(target);
  const label = (i: number) => header[i] ?? `Column ${i + 1}`;
  const fieldsById = new Map(ctx.fields.map((f) => [f.id, f]));
  const mappingProblems: string[] = [];
  if (columnOf("name") < 0) mappingProblems.push("nameNotMapped");
  for (const f of ctx.fields) {
    if (f.required && f.scope === "participant" && columnOf(`field:${f.id}`) < 0) {
      mappingProblems.push(`requiredFieldNotMapped:${f.id}`);
    }
  }
  const empty: Plan = {
    total: data.length, people: [], errors: [], mappingProblems,
    creates: 0, updates: 0, newGroups: [], missingGroups: [],
  };
  if (columnOf("name") < 0) return empty;

  const groupsByName = new Map(ctx.existingGroups.map((g) => [normalise(g.name), g]));
  const groupName = (id: string | null) =>
    ctx.existingGroups.find((g) => g.id === id)?.name ?? null;
  const byExternalId = new Map<string, ExistingPerson>();
  const byKey = new Map<string, ExistingPerson>();
  for (const p of ctx.existing) {
    if (p.externalId) byExternalId.set(p.externalId, p);
    byKey.set(personKey(groupName(p.groupId), p.name), p);
  }

  const errors: RowError[] = [];
  const people: PlannedPerson[] = [];
  const seenKeys = new Set<string>();
  const seenEmails = new Set<string>();
  const newGroups = new Set<string>();

  data.forEach((cells, index) => {
    const row = index + 2;
    const cell = (i: number) => (i >= 0 ? (cells[i] ?? "").trim() : "");
    const rowErrors: RowError[] = [];
    const fail = (column: number, problem: Problem) =>
      rowErrors.push({row, column: label(column), problem});

    const name = cell(columnOf("name"));
    if (!name) fail(columnOf("name"), "required");
    const groupText = cell(columnOf("group")) || null;
    const externalId = cell(columnOf("externalId")) || null;

    const person: PlannedPerson = {
      row, name, groupName: groupText, groupId: null, externalId,
      standard: {}, private: {}, groupStandard: {}, match: null,
    };

    // Age, from a birth date or an age column (X-06: unknown age).
    let age: number | null = null;
    const birthColumn = columnOf("birthDate");
    if (birthColumn >= 0) {
      const text = cell(birthColumn);
      if (text) {
        const date = readDate(text);
        if (!date) fail(birthColumn, "unknownAge");
        person.birthDate = date;
        if (date && ctx.eventStart) age = ageOn(date, ctx.eventStart);
      } else {
        person.birthDate = null;
      }
    }
    const ageColumn = columnOf("age");
    if (ageColumn >= 0 && cell(ageColumn)) {
      const n = Number(cell(ageColumn));
      if (!Number.isInteger(n) || n < 0 || n > 130) fail(ageColumn, "unknownAge");
      else age = n;
    }
    if (age !== null) {
      const category = categoryForAge(age, ctx.categories);
      if (category) {
        person.categoryId = category.id;
        person.isChild = category.isChild === true;
      }
    }
    const categoryColumn = columnOf("category");
    if (categoryColumn >= 0 && person.categoryId === undefined && cell(categoryColumn)) {
      const found = ctx.categories.find((c) => normalise(c.name) === normalise(cell(categoryColumn)));
      if (!found) fail(categoryColumn, "unknownCategory");
      else {
        person.categoryId = found.id;
        person.isChild = found.isChild === true;
      }
    }
    const childColumn = columnOf("isChild");
    if (childColumn >= 0 && person.isChild === undefined && cell(childColumn)) {
      const t = cell(childColumn).toLowerCase();
      if (YES.includes(t)) person.isChild = true;
      else if (NO.includes(t)) person.isChild = false;
      else fail(childColumn, "wrongType");
    }

    const emailColumn = columnOf("email");
    if (emailColumn >= 0) {
      const email = cell(emailColumn).toLowerCase();
      if (email) {
        if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) fail(emailColumn, "badEmail");
        else if (seenEmails.has(email)) fail(emailColumn, "duplicateEmail");
        person.email = email;
      } else {
        person.email = null;
      }
    }

    targets.forEach((target, column) => {
      if (!target.startsWith("field:")) return;
      const field = fieldsById.get(target.slice("field:".length));
      if (!field) return;
      const {value, problem} = readAnswer(field, cell(column));
      if (problem) {
        fail(column, problem);
        return;
      }
      if (value === undefined) return;
      const bucket = field.scope === "group" ?
        person.groupStandard :
        field.visibility === "private" ? person.private : person.standard;
      bucket[field.id] = value;
    });

    // The same person twice in one file (Req 44: never duplicates).
    const key = externalId ? `id:${externalId}` : `key:${personKey(groupText, name)}`;
    if (rowErrors.length === 0 && seenKeys.has(key)) fail(columnOf("name"), "duplicateRow");

    if (rowErrors.length > 0) {
      errors.push(...rowErrors);
      return;
    }
    seenKeys.add(key);
    if (person.email) seenEmails.add(person.email);
    const existing = (externalId ? byExternalId.get(externalId) : undefined) ??
      byKey.get(personKey(groupText, name));
    person.match = existing?.id ?? null;
    const group = groupText ? groupsByName.get(normalise(groupText)) : undefined;
    person.groupId = group?.id ?? null;
    if (groupText && !group) newGroups.add(groupText.trim());
    people.push(person);
  });

  // Imported groups with nobody in this file (Req 45, X-03). People added by
  // hand are never listed.
  const matched = new Set(people.map((p) => p.match).filter(Boolean));
  const missing = new Map<string, {groupId: string | null; name: string; participantIds: string[]}>();
  const present = new Set<string>();
  for (const p of ctx.existing) {
    if (!p.imported || p.status === "cancelled") continue;
    const groupKey = p.groupId ?? `person:${p.id}`;
    if (matched.has(p.id)) {
      present.add(groupKey);
      continue;
    }
    const entry = missing.get(groupKey) ?? {
      groupId: p.groupId, name: groupName(p.groupId) ?? p.name, participantIds: [],
    };
    entry.participantIds.push(p.id);
    missing.set(groupKey, entry);
  }
  const missingGroups = [...missing.entries()]
    .filter(([key]) => !present.has(key))
    .map(([, entry]) => entry);

  return {
    ...empty,
    people,
    errors,
    creates: people.filter((p) => !p.match).length,
    updates: people.filter((p) => p.match).length,
    newGroups: [...newGroups],
    missingGroups,
  };
}

/**
 * The roster's filter tags from standard choice and yes/no answers, as the
 * app's `filterTagsFor` writes them. Private answers are never tagged.
 */
export function filterTagsFor(
  fields: readonly FieldDef[],
  answers: Record<string, unknown>,
  scope = "participant"
): string[] {
  const tags: string[] = [];
  for (const f of fields) {
    const filters = f.visibility !== "private" && f.scope === scope &&
      ["singleChoice", "multiChoice", "yesNo"].includes(f.type);
    const value = answers[f.id];
    if (!filters || value === undefined || value === null || value === "") continue;
    const tag = (v: unknown) => `${f.id}=${typeof v === "boolean" ? (v ? "yes" : "no") : v}`;
    if (Array.isArray(value)) value.forEach((v) => tags.push(tag(v)));
    else tags.push(tag(value));
  }
  return tags;
}
