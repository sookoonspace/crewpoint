/**
 * An event's registration settings (Spec #233 Req 8, 11, 16-19, 60; #239),
 * kept in `settings.registration` and written only by
 * `saveRegistrationSettings` and, for the slug, `claimEventSlug`. Pure, so
 * the callables and tests share one set of checks.
 *
 * The form is built from the event's custom fields: `sections` group them
 * in order, `blocks` switch on the built-in parts, and `conditions` show a
 * question only to a category or when one other answer has a value. A
 * condition never depends on a question that has a condition itself, so a
 * form is at most one level deep.
 *
 * Times are stored as milliseconds since the epoch rather than Timestamps,
 * because the app mirrors an event's settings on the device as JSON.
 */

export type RegistrationMode = "open" | "invited";

/** Text an organizer writes, in English and, when given, Gujarati. */
export interface LocalText {
  en: string;
  gu?: string;
}

export interface RegistrationSection {
  id: string;
  name: LocalText;
  fieldIds: string[];
}

/** The built-in parts of the form the organizer switches on (Req 17). */
export interface RegistrationBlocks {
  /** Each person's name and birth date, or their age with [ageOnly]. */
  people: boolean;
  ageOnly: boolean;
  /** Arrival and departure per person. */
  stay: boolean;
  /** By-sign-up sessions as per-person choices. */
  sessionChoices: boolean;
  waivers: boolean;
  /** The contact's email and phone, kept privately. */
  contact: boolean;
}

/** Shown only to a category, or when one other answer has a value. */
export type FieldCondition = {categoryId: string} | {fieldId: string; value: string};

export interface RegistrationSettings {
  mode: RegistrationMode;
  /** When registration closes, in milliseconds since the epoch, or none. */
  deadline: number | null;
  /** Whether a submission waits for an organizer to approve it. */
  review: boolean;
  /** How many extra guests each party may bring (Req 49). */
  extraGuests: number;
  sections: RegistrationSection[];
  blocks: RegistrationBlocks;
  /** By question ID. */
  conditions: Record<string, FieldCondition>;
  /** Seen only by groups with a submitted registration (Req 19). */
  afterNote: LocalText | null;
  /** Replaces [afterNote] from [laterNoteFrom]. */
  laterNote: LocalText | null;
  laterNoteFrom: number | null;
  /** The role people get when they register (Req 60). */
  registrationRoleId: string;
  /** How long an offered place is held (Req 34). */
  offerHours: number;
}

/** What the platform starts with when neither event nor template sets it. */
export const DEFAULT_REGISTRATION: RegistrationSettings = {
  mode: "invited",
  deadline: null,
  review: false,
  extraGuests: 0,
  sections: [],
  blocks: {
    people: true, ageOnly: false, stay: false, sessionChoices: false, waivers: false, contact: true,
  },
  conditions: {},
  afterNote: null,
  laterNote: null,
  laterNoteFrom: null,
  registrationRoleId: "participant",
  offerHours: 72,
};

/** What the checks need to know about the event. */
export interface RegistrationContext {
  fields: {id: string; type: string; options: string[]}[];
  categoryIds: string[];
  /** Each role's permissions, by role ID. */
  roles: Record<string, string[]>;
}

/** A setting that cannot be saved, with a message for the organizer. */
export class RegistrationSettingsError extends Error {}

/**
 * The only permissions the role for people who register may hold: anyone
 * may register on an open event, so the role must manage nothing.
 */
export const SELF_SERVICE_PERMISSIONS = [
  "chat.send", "chat.urgent", "group.readOwn", "group.editOwn", "incidents.report", "scores.enter",
];

const MAX_SECTIONS = 20;
const MAX_NAME = 80;
const MAX_NOTE = 5000;
const MAX_EXTRA_GUESTS = 20;
const MAX_OFFER_HOURS = 14 * 24;
const ID = /^[A-Za-z0-9_-]{1,40}$/;

function fail(message: string): never {
  throw new RegistrationSettingsError(message);
}

const isObject = (v: unknown): v is Record<string, unknown> =>
  typeof v === "object" && v !== null && !Array.isArray(v);

function wholeNumber(v: unknown, min: number, max: number, what: string): number {
  if (typeof v !== "number" || !Number.isInteger(v) || v < min || v > max) {
    fail(`The ${what} must be a whole number from ${min} to ${max}.`);
  }
  return v;
}

function time(v: unknown, what: string): number | null {
  if (v === null || v === undefined) return null;
  if (typeof v !== "number" || !Number.isFinite(v)) fail(`The ${what} is not a date and time.`);
  return v;
}

/** Text in English and optionally Gujarati, or null when the English is empty. */
function localText(v: unknown, max: number, what: string): LocalText | null {
  if (v === null || v === undefined) return null;
  if (!isObject(v) || typeof v.en !== "string") fail(`The ${what} must be text.`);
  const en = v.en.trim();
  const gu = typeof v.gu === "string" ? v.gu.trim() : "";
  if (en.length > max || gu.length > max) fail(`The ${what} is longer than ${max} characters.`);
  if (en.length === 0) return null;
  return gu ? {en, gu} : {en};
}

function parseSections(v: unknown, fieldIds: Set<string>): RegistrationSection[] {
  if (v === undefined || v === null) return [];
  if (!Array.isArray(v) || v.length > MAX_SECTIONS) fail(`Use at most ${MAX_SECTIONS} sections.`);
  const ids = new Set<string>();
  const placed = new Set<string>();
  return v.map((raw) => {
    if (!isObject(raw) || typeof raw.id !== "string" || !ID.test(raw.id) || ids.has(raw.id)) {
      fail("A section is not valid.");
    }
    ids.add(raw.id);
    const name = localText(raw.name, MAX_NAME, "section name");
    if (!name) fail("Every section needs a name.");
    if (!Array.isArray(raw.fieldIds)) fail(`Section "${name.en}" has no list of questions.`);
    const list = raw.fieldIds.map((id) => {
      if (typeof id !== "string" || !fieldIds.has(id)) {
        fail(`Section "${name.en}" lists a question that does not exist.`);
      }
      if (placed.has(id)) fail("A question can be in only one section.");
      placed.add(id);
      return id;
    });
    return {id: raw.id, name, fieldIds: list};
  });
}

function parseBlocks(v: unknown): RegistrationBlocks {
  const raw = isObject(v) ? v : {};
  const blocks = {...DEFAULT_REGISTRATION.blocks};
  for (const key of Object.keys(blocks) as (keyof RegistrationBlocks)[]) {
    if (raw[key] === undefined) continue;
    if (typeof raw[key] !== "boolean") fail(`The ${key} block must be on or off.`);
    blocks[key] = raw[key] as boolean;
  }
  return blocks;
}

function parseConditions(
  v: unknown, ctx: RegistrationContext
): Record<string, FieldCondition> {
  if (v === undefined || v === null) return {};
  if (!isObject(v)) fail("Question conditions are not valid.");
  const fields = new Map(ctx.fields.map((f) => [f.id, f]));
  const out: Record<string, FieldCondition> = {};
  for (const [fieldId, raw] of Object.entries(v)) {
    if (!fields.has(fieldId)) fail("A condition is set on a question that does not exist.");
    if (!isObject(raw)) fail("A question condition is not valid.");
    if (typeof raw.categoryId === "string") {
      if (!ctx.categoryIds.includes(raw.categoryId)) {
        fail("A condition names a category that does not exist.");
      }
      out[fieldId] = {categoryId: raw.categoryId};
      continue;
    }
    if (typeof raw.fieldId !== "string" || typeof raw.value !== "string") {
      fail("A question condition is not valid.");
    }
    const target = fields.get(raw.fieldId);
    if (!target) fail("A condition depends on a question that does not exist.");
    if (raw.fieldId === fieldId) fail("A question cannot depend on itself.");
    const values = target.type === "yesNo" ? ["yes", "no"] :
      target.type === "singleChoice" || target.type === "multiChoice" ? target.options : null;
    if (!values) fail("A condition can depend only on a yes/no or choice question.");
    if (!values.includes(raw.value)) fail("A condition depends on a value the question does not offer.");
    out[fieldId] = {fieldId: raw.fieldId, value: raw.value};
  }
  // One level only (Req 18).
  for (const [fieldId, c] of Object.entries(out)) {
    if ("fieldId" in c && out[c.fieldId]) {
      fail(`Question "${fieldId}" depends on a question that itself has a condition.`);
    }
  }
  return out;
}

function parseRole(v: unknown, ctx: RegistrationContext): string {
  const roleId = v === undefined || v === null ? "participant" : v;
  if (typeof roleId !== "string" || roleId === "owner" || !ctx.roles[roleId]) {
    fail("Choose a role for people who register.");
  }
  if (ctx.roles[roleId].some((p) => !SELF_SERVICE_PERMISSIONS.includes(p))) {
    fail("People who register can only get a role without organizer permissions.");
  }
  return roleId;
}

/**
 * Checks [raw] against the event and returns the settings to store, or
 * throws a [RegistrationSettingsError]. Keys it does not know are dropped,
 * and the slug is never taken from here: only `claimEventSlug` sets it.
 */
export function parseRegistrationSettings(
  raw: unknown, ctx: RegistrationContext
): RegistrationSettings {
  if (!isObject(raw)) fail("Registration settings are missing.");
  const mode = raw.mode ?? DEFAULT_REGISTRATION.mode;
  if (mode !== "open" && mode !== "invited") fail("The registration mode must be open or invited.");
  if (raw.review !== undefined && typeof raw.review !== "boolean") fail("Review must be on or off.");
  const afterNote = localText(raw.afterNote, MAX_NOTE, "after-registration note");
  const laterNote = localText(raw.laterNote, MAX_NOTE, "replacement note");
  const laterNoteFrom = time(raw.laterNoteFrom, "replacement note's date");
  if (laterNote && laterNoteFrom === null) fail("Choose the date the replacement note starts.");
  return {
    mode,
    deadline: time(raw.deadline, "deadline"),
    review: raw.review === true,
    extraGuests: wholeNumber(raw.extraGuests ?? 0, 0, MAX_EXTRA_GUESTS, "number of extra guests"),
    sections: parseSections(raw.sections, new Set(ctx.fields.map((f) => f.id))),
    blocks: parseBlocks(raw.blocks),
    conditions: parseConditions(raw.conditions, ctx),
    afterNote,
    laterNote,
    laterNoteFrom: laterNote ? laterNoteFrom : null,
    registrationRoleId: parseRole(raw.registrationRoleId, ctx),
    offerHours: wholeNumber(raw.offerHours ?? 72, 1, MAX_OFFER_HOURS, "offer window in hours"),
  };
}

/** Settings as a template or an older event may hold them, some missing. */
export type PartialRegistration =
  Partial<Omit<RegistrationSettings, "blocks">> & {blocks?: Partial<RegistrationBlocks>};

/**
 * An event's settings with anything missing taken from its template
 * ([template]), then the platform's defaults, so older events read the
 * same as new ones.
 */
export function withRegistrationDefaults(
  stored: PartialRegistration | undefined | null,
  template: PartialRegistration | undefined | null,
): RegistrationSettings {
  return {
    ...DEFAULT_REGISTRATION,
    ...(template ?? {}),
    ...(stored ?? {}),
    blocks: {...DEFAULT_REGISTRATION.blocks, ...(template?.blocks ?? {}), ...(stored?.blocks ?? {})},
  };
}

/** Paths that routes or the product may need, so no event takes them. */
const RESERVED_SLUGS = new Set([
  "admin", "api", "app", "dashboard", "e", "help", "join", "login", "new", "r", "register",
  "settings", "signin", "support", "www", "crewpoint",
]);

/**
 * The slug in its stored form (lower-case letters, numbers and hyphens,
 * 3 to 40 long, starting and ending with a letter or number), or null when
 * it cannot be one.
 */
export function normaliseSlug(raw: string): string | null {
  const slug = raw.trim().toLowerCase();
  if (!/^[a-z0-9][a-z0-9-]{1,38}[a-z0-9]$/.test(slug)) return null;
  return RESERVED_SLUGS.has(slug) ? null : slug;
}
