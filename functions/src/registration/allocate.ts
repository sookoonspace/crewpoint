/**
 * The capacity rules for registrations (Spec #233 Req 32, 32a, 33, 34;
 * #242). Pure, so the submit transaction and the tests share them.
 */

export type AllocatedStatus = "submitted" | "pending" | "waitlisted";

export interface AllocateInput {
  /** The event's capacity in people, or null for no limit. */
  capacity: number | null;
  /** People in submitted and pending registrations. */
  placesUsed: number;
  /** Places held by open waitlist offers. */
  held: number;
  /** People in the group being submitted. */
  size: number;
  /** Whether submissions wait for an organizer (Req 47 `review`). */
  review: boolean;
}

/**
 * Where a group of [size] goes: in whole, as `submitted` (or `pending`
 * when review is on, which also takes places), or on the waitlist whole,
 * never split (Req 33).
 */
export function allocate({capacity, placesUsed, held, size, review}: AllocateInput): {
  status: AllocatedStatus;
  placesUsed: number;
} {
  const fits = capacity === null || placesUsed + held + size <= capacity;
  if (!fits) return {status: "waitlisted", placesUsed};
  return {status: review ? "pending" : "submitted", placesUsed: placesUsed + size};
}

/** A waiting registration, in the queue. */
export interface WaitingGroup {
  registrationId: string;
  size: number;
  /** Its waitlist number; lower goes first. */
  position: number;
}

/**
 * The first waiting group, in queue order, whose people fit in [free]
 * places, or null (Req 34). A larger group skipped keeps its position for
 * the next opening that fits.
 */
export function nextGroupThatFits(queue: readonly WaitingGroup[], free: number): string | null {
  const ordered = [...queue].sort((a, b) => a.position - b.position);
  return ordered.find((g) => g.size <= free)?.registrationId ?? null;
}
