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

/** The part of `users/{uid}` copied into `events/{eventId}/profiles/{uid}`. */
export function profileFrom(
  uid: string,
  user: Data
): Record<string, string | null> {
  const profile: Record<string, string | null> = {uid};
  for (const field of PROFILE_FIELDS) {
    const value = user?.[field];
    profile[field] = typeof value === "string" ? value : null;
  }
  return profile;
}
