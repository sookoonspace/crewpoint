import {
  DocumentReference,
  FieldValue,
  Firestore,
  Transaction,
} from "firebase-admin/firestore";

const organizerRef = (db: Firestore, uid: string): DocumentReference =>
  db.collection("organizers").doc(uid);

/**
 * Finds a person's personal organizer inside a transaction, and returns the
 * write that creates it if they have none. Legal name and tax ID arrive in
 * Stage 2. An existing organizer is left alone, which keeps `verified`.
 *
 * Transactions read before they write, so the caller applies the result after
 * its other reads.
 */
export async function preparePersonalOrganizer(
  db: Firestore,
  tx: Transaction,
  uid: string
): Promise<() => void> {
  const ref = organizerRef(db, uid);
  const existing = await tx.get(ref);
  return () => {
    if (existing.exists) return;
    tx.set(ref, {
      id: uid,
      ownerId: uid,
      kind: "personal",
      verified: false,
      createdAt: FieldValue.serverTimestamp(),
    });
  };
}

/** Creates a person's personal organizer unless they already have one. */
export async function ensurePersonalOrganizer(
  db: Firestore,
  uid: string
): Promise<void> {
  await db.runTransaction(async (tx) => {
    const write = await preparePersonalOrganizer(db, tx, uid);
    write();
  });
}

/** An organizer with no document, or no flag, counts as not verified. */
export async function isOrganizerVerified(
  db: Firestore,
  organizerId: unknown
): Promise<boolean> {
  if (typeof organizerId !== "string" || organizerId.length === 0) return false;
  const organizer = await organizerRef(db, organizerId).get();
  return organizer.data()?.verified === true;
}
