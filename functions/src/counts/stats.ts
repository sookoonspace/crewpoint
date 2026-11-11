/**
 * Counts per event and per session (Req 52), by category and by every
 * choice or yes/no custom field, private ones included (owner's decision,
 * 2026-11-11: totals only, read with `counts.read`). Pure: the scheduled job
 * and `recalculateCounts` load the data and call [computeStats].
 *
 * Only active people count. A session counts those [attends] says attend.
 * Unanswered fields and people with no category count under `_none`.
 */
import {attends, AttendancePerson, AttendanceSession} from "../schedule/attendance";

export const NONE = "_none";

export interface CountField {
  id: string;
  type: string;
  scope: string;
}

export interface CountPerson extends AttendancePerson {
  id: string;
  groupId?: string | null;
  /** Standard and private answers together, by field ID. */
  answers: Record<string, unknown>;
}

export interface CountGroup {
  id: string;
  invitedTo?: string[] | null;
  /** Standard and private group answers together. */
  answers?: Record<string, unknown>;
}

export interface Tally {
  total: number;
  byCategory: Record<string, number>;
  byField: Record<string, Record<string, number>>;
}

export interface EventStats {
  event: Tally & {groups: number};
  sessions: Record<string, Tally>;
}

const COUNTED = new Set(["singleChoice", "multiChoice", "yesNo"]);

/** The answer's values to count, or none when unanswered. */
function valuesOf(type: string, answer: unknown): string[] {
  if (type === "yesNo") return typeof answer === "boolean" ? [answer ? "yes" : "no"] : [];
  if (Array.isArray(answer)) return answer.filter((v): v is string => typeof v === "string" && v !== "");
  return typeof answer === "string" && answer !== "" ? [answer] : [];
}

function add(map: Record<string, number>, key: string): void {
  map[key] = (map[key] ?? 0) + 1;
}

export function computeStats({policy, sessions, people, groups, fields}: {
  policy?: string | null;
  sessions: AttendanceSession[];
  people: CountPerson[];
  groups: CountGroup[];
  fields: CountField[];
}): EventStats {
  const counted = fields.filter((f) => COUNTED.has(f.type));
  const groupById = new Map(groups.map((g) => [g.id, g]));
  const active = people.filter((p) => p.status !== "cancelled");

  const tally = (): Tally => ({
    total: 0,
    byCategory: {},
    byField: Object.fromEntries(counted.map((f) => [f.id, {}])),
  });
  const count = (t: Tally, p: CountPerson): void => {
    t.total++;
    add(t.byCategory, p.categoryId || NONE);
    const group = p.groupId ? groupById.get(p.groupId) : undefined;
    for (const f of counted) {
      const answer = f.scope === "group" ? group?.answers?.[f.id] : p.answers[f.id];
      const values = valuesOf(f.type, answer);
      if (values.length === 0) add(t.byField[f.id], NONE);
      for (const v of values) add(t.byField[f.id], v);
    }
  };

  const event = tally();
  const withGroups = new Set<string>();
  for (const p of active) {
    count(event, p);
    if (p.groupId) withGroups.add(p.groupId);
  }

  const bySession: Record<string, Tally> = {};
  for (const s of sessions) {
    const t = tally();
    for (const p of active) {
      const group = p.groupId ? groupById.get(p.groupId) : undefined;
      if (attends({policy, session: s, person: p, group})) count(t, p);
    }
    bySession[s.id] = t;
  }

  return {event: {...event, groups: withGroups.size}, sessions: bySession};
}
