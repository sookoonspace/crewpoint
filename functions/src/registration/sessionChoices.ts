import {policyOf} from "../schedule/attendance";

/**
 * By-sign-up sessions as per-person choices on the registration form
 * (Spec #233 Req 17; #242, W-01). A session is by sign-up when its own
 * `attendance`, or else the event's policy, is `bySession`; sessions at
 * the same time (overlapping, chained) form one either/or choice, so a
 * person picks at most one of them. A session with no end lasts an hour,
 * as on the agenda. Hidden drafts are never offered. Pure, with cases in
 * `test/fixtures/session_choice_cases.json`, which the app's
 * `session_choices.dart` also runs; change them together.
 */
export interface ChoiceSession {
  id: string;
  startAt: string | number;
  endAt?: string | number | null;
  attendance?: string | null;
  hidden?: boolean;
}

const HOUR = 60 * 60 * 1000;
const ms = (t: string | number) => (typeof t === "number" ? t : Date.parse(t));

/** The choices, in time order; each is one session or an either/or. */
export function signUpChoices(policy: string | null | undefined, sessions: readonly ChoiceSession[]): string[][] {
  const offered = sessions
    .filter((s) => s.hidden !== true)
    .filter((s) => (s.attendance ? policyOf(s.attendance) : policyOf(policy)) === "bySession")
    .map((s) => {
      const start = ms(s.startAt);
      const end = s.endAt === null || s.endAt === undefined ? start + HOUR : ms(s.endAt);
      return {id: s.id, start, end};
    })
    .sort((a, b) => a.start - b.start || a.id.localeCompare(b.id));
  const choices: {ids: string[]; end: number}[] = [];
  for (const s of offered) {
    const last = choices[choices.length - 1];
    if (last && s.start < last.end) {
      last.ids.push(s.id);
      last.end = Math.max(last.end, s.end);
    } else {
      choices.push({ids: [s.id], end: s.end});
    }
  }
  return choices.map((c) => c.ids);
}

/** Whether [signUps] picks only offered sessions, at most one per choice. */
export function validSignUps(choices: readonly string[][], signUps: readonly string[]): boolean {
  const choiceOf = new Map<string, number>();
  choices.forEach((ids, i) => ids.forEach((id) => choiceOf.set(id, i)));
  const used = new Set<number>();
  for (const id of new Set(signUps)) {
    const i = choiceOf.get(id);
    if (i === undefined || used.has(i)) return false;
    used.add(i);
  }
  return true;
}
