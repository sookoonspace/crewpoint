/**
 * Who attends a session (Req 50). Pure, so counts (Req 52) and the app's
 * agenda work it out the same way: the app runs the same cases from
 * `test/fixtures/attendance_cases.json` against its Dart copy.
 *
 * Only exceptions are stored. A session's own `attendance` overrides the
 * event's `settings.attendancePolicy`, and a missing policy means everyone.
 */

export type AttendancePolicy = "arrivalToDeparture" | "invitedOnly" | "everyone" | "bySession";

export const ATTENDANCE_POLICIES: readonly AttendancePolicy[] = [
  "arrivalToDeparture", "invitedOnly", "everyone", "bySession",
];

/** Times are ISO strings or Dates, so both stored and fixture data fit. */
type Instant = string | Date | {toDate(): Date} | null | undefined;

export interface AttendanceSession {
  id: string;
  startAt: Instant;
  attendance?: string | null;
  eligibility?: {categoryIds?: string[]; filterTags?: string[]} | null;
}

export interface AttendancePerson {
  status?: string | null;
  categoryId?: string | null;
  filterTags?: string[] | null;
  arrivalAt?: Instant;
  departureAt?: Instant;
  optOuts?: string[] | null;
  signUps?: string[] | null;
  invitedTo?: string[] | null;
}

export interface AttendanceCase {
  policy?: string | null;
  session: AttendanceSession;
  person: AttendancePerson;
  group?: {invitedTo?: string[] | null} | null;
}

function millis(value: Instant): number | null {
  if (value == null) return null;
  if (typeof value === "string") return Date.parse(value);
  if (value instanceof Date) return value.getTime();
  return value.toDate().getTime();
}

function policyOf(value: string | null | undefined): AttendancePolicy {
  return (ATTENDANCE_POLICIES as readonly string[]).includes(value ?? "") ?
    value as AttendancePolicy : "everyone";
}

/** Whether [person] attends [session] under the event's [policy]. */
export function attends({policy, session, person, group}: AttendanceCase): boolean {
  if (person.status === "cancelled") return false;
  if ((person.optOuts ?? []).includes(session.id)) return false;

  const invited = (person.invitedTo ?? []).includes(session.id) ||
    (group?.invitedTo ?? []).includes(session.id);
  if (invited) return true;

  const categoryIds = session.eligibility?.categoryIds ?? [];
  const tags = session.eligibility?.filterTags ?? [];
  const eligible =
    (categoryIds.length === 0 || categoryIds.includes(person.categoryId ?? "")) &&
    (tags.length === 0 || (person.filterTags ?? []).some((t) => tags.includes(t)));
  if (!eligible) return false;

  const mode = session.attendance ? policyOf(session.attendance) : policyOf(policy);
  switch (mode) {
  case "everyone":
    return true;
  case "invitedOnly":
    return false;
  case "bySession":
    return (person.signUps ?? []).includes(session.id);
  case "arrivalToDeparture": {
    const start = millis(session.startAt);
    const arrival = millis(person.arrivalAt);
    const departure = millis(person.departureAt);
    if (start == null) return false;
    return (arrival == null || start >= arrival) &&
      (departure == null || start < departure);
  }
  }
}
