/**
 * System templates (Req 62): data only, kept in the app's
 * `assets/templates/` and copied to `functions/templates/` by
 * `npm run gen:templates`, so no environment needs seeding. Each sets
 * modules, labels, roles, fields, categories, the attendance policy and
 * expense access. `createEvent` copies one into a new event, so a later
 * template version never changes an existing event.
 *
 * Event-specific words live only in these files (Req 2).
 */
import {readFileSync} from "fs";
import {join} from "path";
import labelDefaults from "../shared/label_defaults.json";
import {PRESET_ROLES} from "./permissions";

export interface TemplateField {
  id: string;
  label: string;
  type: string;
  options: string[];
  required: boolean;
  scope: string;
  visibility: string;
  order: number;
}

export interface EventTemplate {
  id: string;
  version: number;
  name: Record<string, string>;
  description: Record<string, string>;
  icon: string;
  fastPath: boolean;
  modules: Record<string, boolean>;
  labels: Record<string, {one?: string; other?: string}>;
  settings: {
    attendancePolicy: string;
    expenseAccess: {mode: string; roleIds?: string[]; uids?: string[]};
    categories: {id: string; name: string; minAge?: number; maxAge?: number; isChild?: boolean}[];
  };
  fields: TemplateField[];
  /** Preset roles renamed for this kind of event, as `{name, base}`. */
  roles: Record<string, {name: string; base: string}>;
}

const DIR = join(__dirname, "..", "..", "templates");
const MODULES = ["tasks", "budget", "chat", "schedule"];
const POLICIES = ["arrivalToDeparture", "invitedOnly", "everyone", "bySession"];
const ACCESS = ["everyone", "involved", "selected"];
const FIELD_TYPES = ["text", "number", "date", "singleChoice", "multiChoice", "yesNo"];

function fail(what: string): never {
  throw new Error(`Template ${what} is not valid.`);
}

/** Throws when [t] is not a well-formed template. */
export function validateTemplate(t: EventTemplate | null): EventTemplate {
  if (!t || typeof t.id !== "string" || !Number.isInteger(t.version)) fail("header");
  for (const [m, on] of Object.entries(t.modules ?? {})) {
    if (!MODULES.includes(m) || typeof on !== "boolean") fail(`module ${m}`);
  }
  const concepts = Object.keys(labelDefaults);
  for (const [c, forms] of Object.entries(t.labels ?? {})) {
    if (!concepts.includes(c) || typeof forms !== "object") fail(`label ${c}`);
  }
  const ids = new Set<string>();
  for (const f of t.fields ?? []) {
    if (!f.id || ids.has(f.id) || !f.label || !FIELD_TYPES.includes(f.type) ||
      !Array.isArray(f.options) || !["participant", "group"].includes(f.scope) ||
      !["standard", "private"].includes(f.visibility)) {
      fail(`field ${f.id}`);
    }
    ids.add(f.id);
  }
  if (!POLICIES.includes(t.settings?.attendancePolicy)) fail("attendance policy");
  if (!ACCESS.includes(t.settings?.expenseAccess?.mode)) fail("expense access");
  for (const c of t.settings?.categories ?? []) {
    if (!c.id || !c.name) fail("category");
  }
  for (const [roleId, role] of Object.entries(t.roles ?? {})) {
    if (roleId === "owner" || !role.name || !PRESET_ROLES[role.base]) fail(`role ${roleId}`);
  }
  return t;
}

export const SYSTEM_TEMPLATE_IDS: string[] =
  JSON.parse(readFileSync(join(DIR, "index.json"), "utf8")).templates;

const cache = new Map<string, EventTemplate>();

/** The system template [id], checked, or null when there is none. */
export function systemTemplate(id: string): EventTemplate | null {
  if (!SYSTEM_TEMPLATE_IDS.includes(id)) return null;
  let t = cache.get(id);
  if (!t) {
    t = validateTemplate(JSON.parse(readFileSync(join(DIR, `${id}.json`), "utf8")));
    cache.set(id, t);
  }
  return t;
}
