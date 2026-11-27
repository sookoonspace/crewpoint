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

/**
 * An open waitlist offer (Spec #233 Req 32, 34, TD 11; #248): places held
 * for one waiting group until [expiresAt], kept in the tally's `offers`.
 * Times are milliseconds since the epoch.
 */
export interface Offer {
  registrationId: string;
  size: number;
  offeredAt: number;
  expiresAt: number;
}

export interface PlanOffersInput {
  capacity: number | null;
  placesUsed: number;
  /** Offers still open, whose places are held. */
  offers: readonly Offer[];
  /** Waiting groups, in any order. */
  queue: readonly WaitingGroup[];
  now: number;
  offerHours: number;
  /** The registration deadline; after it nothing is offered by itself. */
  deadline: number | null;
}

/**
 * The offers to make now: while places are free, the first waiting group
 * that fits, again and again, so several can be open at once. A larger
 * group skipped keeps its position (Req 34). Nothing after the deadline.
 */
export function planOffers(input: PlanOffersInput): Offer[] {
  if (input.deadline !== null && input.now > input.deadline) return [];
  const offered = new Set(input.offers.map((o) => o.registrationId));
  let held = input.offers.reduce((n, o) => n + o.size, 0);
  const made: Offer[] = [];
  let waiting = input.queue.filter((g) => !offered.has(g.registrationId));
  for (;;) {
    const free = input.capacity === null ? Number.POSITIVE_INFINITY : input.capacity - input.placesUsed - held;
    if (free <= 0) break;
    const id = nextGroupThatFits(waiting, free);
    if (id === null) break;
    const group = waiting.find((g) => g.registrationId === id)!;
    made.push({
      registrationId: id, size: group.size, offeredAt: input.now,
      expiresAt: input.now + input.offerHours * 60 * 60 * 1000,
    });
    held += group.size;
    waiting = waiting.filter((g) => g.registrationId !== id);
  }
  return made;
}

/** [offers] split into those still open at [now] and those that ran out. */
export function expireOffers(offers: readonly Offer[], now: number): {open: Offer[]; expired: Offer[]} {
  return {
    open: offers.filter((o) => o.expiresAt > now),
    expired: offers.filter((o) => o.expiresAt <= now),
  };
}
