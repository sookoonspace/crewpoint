import {HttpsError} from "firebase-functions/v2/https";

/**
 * Who reads every expense in an event (Req 38, L15), from
 * `settings.expenseAccess` on the event document. Whatever the option, the
 * payer and people in a split read that expense, and `money.read` reads all
 * of them. This module only decides who also gets `expenses.readAll`, which
 * is copied onto member documents (Technical Decision 4a).
 *
 * - `everyone`: every member except Observers and Vendors, who are included
 *   only when `includeNonContributors` is on [Decided 2026-11-08].
 * - `involved`: nobody, so members read only expenses they are part of.
 * - `selected`: members holding one of `roleIds`, or listed in `uids`.
 */
export type ExpenseAccessMode = "everyone" | "involved" | "selected";

export interface ExpenseAccess {
  mode: ExpenseAccessMode;
  includeNonContributors: boolean;
  roleIds: string[];
  uids: string[];
}

const MODES: readonly ExpenseAccessMode[] = ["everyone", "involved", "selected"];
/** Keeps the event document small; well above any real committee. */
export const MAX_SELECTED = 500;

const strings = (value: unknown): string[] =>
  Array.isArray(value) ?
    [...new Set(value.filter((v): v is string => typeof v === "string" && v.length > 0))] :
    [];

/** Only what [mode] uses, so a stored setting has one shape per option. */
function normalise(
  mode: ExpenseAccessMode,
  includeNonContributors: boolean,
  roleIds: string[],
  uids: string[]
): ExpenseAccess {
  return {
    mode,
    includeNonContributors: mode === "everyone" && includeNonContributors,
    roleIds: mode === "selected" ? roleIds : [],
    uids: mode === "selected" ? uids : [],
  };
}

/**
 * The event's setting. An event without one, which includes every event
 * from before #72, is Everyone, which is what members could read before.
 */
export function expenseAccessOf(
  eventData: FirebaseFirestore.DocumentData | undefined
): ExpenseAccess {
  const raw = eventData?.settings?.expenseAccess;
  const mode = MODES.includes(raw?.mode) ? raw.mode as ExpenseAccessMode : "everyone";
  return normalise(
    mode,
    raw?.includeNonContributors === true,
    strings(raw?.roleIds),
    strings(raw?.uids)
  );
}

/** A setting sent to `setExpenseAccess`, refused if it is malformed. */
export function parseExpenseAccess(input: unknown): ExpenseAccess {
  const raw = input as Record<string, unknown> | null;
  if (!raw || typeof raw !== "object" || !MODES.includes(raw.mode as ExpenseAccessMode)) {
    throw new HttpsError("invalid-argument", "Choose who can see expenses.");
  }
  for (const field of ["roleIds", "uids"] as const) {
    const value = raw[field];
    if (value === undefined) continue;
    if (!Array.isArray(value) || value.some((v) => typeof v !== "string" || !v)) {
      throw new HttpsError("invalid-argument", `${field} must be a list of IDs.`);
    }
    if (value.length > MAX_SELECTED) {
      throw new HttpsError("invalid-argument", `Pick at most ${MAX_SELECTED}.`);
    }
  }
  if (raw.includeNonContributors !== undefined && typeof raw.includeNonContributors !== "boolean") {
    throw new HttpsError("invalid-argument", "includeNonContributors must be true or false.");
  }
  return normalise(
    raw.mode as ExpenseAccessMode,
    raw.includeNonContributors === true,
    strings(raw.roleIds),
    strings(raw.uids)
  );
}

/** Whether someone with [roleIds] reads every expense under [access]. */
export function readsAllExpensesUnder(
  access: ExpenseAccess,
  uid: string,
  roleIds: readonly string[]
): boolean {
  switch (access.mode) {
  case "everyone":
    return access.includeNonContributors ||
      roleIds.some((r) => r !== "observer" && r !== "vendor");
  case "involved":
    return false;
  case "selected":
    return access.uids.includes(uid) ||
      roleIds.some((r) => access.roleIds.includes(r));
  }
}
