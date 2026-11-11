type Data = FirebaseFirestore.DocumentData | undefined;

/** What people in an event see of each other (Req 37). */
const NAME_FIELDS = ["displayName", "photoUrl"] as const;
export const HANDLE_FIELDS = [
  "paymentMethod",
  "paymentHandle",
  "venmoHandle",
  "cashappHandle",
] as const;
export const PROFILE_FIELDS = [...NAME_FIELDS, ...HANDLE_FIELDS];

/**
 * The key the member picker sorts and searches names by (Req 43a): the name
 * in lower case without surrounding spaces. No name sorts last.
 */
export function nameSortKey(name: unknown): string {
  const key = typeof name === "string" ? name.trim().toLowerCase() : "";
  return key || "\uf8ff";
}

/**
 * The part of `users/{uid}` copied into `events/{eventId}/profiles/{uid}`,
 * with its sort name. Callers add `inEvent`, which is true while the person
 * is in the event, so the picker lists only them.
 */
export function profileFrom(
  uid: string,
  user: Data
): Record<string, string | null> {
  const profile: Record<string, string | null> = {uid};
  for (const field of PROFILE_FIELDS) {
    const value = user?.[field];
    profile[field] = typeof value === "string" ? value : null;
  }
  profile.sortName = nameSortKey(profile.displayName);
  return profile;
}
