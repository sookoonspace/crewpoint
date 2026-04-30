import * as admin from "firebase-admin";

const BATCH_LIMIT = 500;

export interface BatchOperation {
  type: "delete" | "update";
  ref: FirebaseFirestore.DocumentReference;
  data?: Record<string, unknown>;
}

/**
 * Commits Firestore operations in sequential chunks of 500
 * to stay within Firestore's batch write limit.
 */
export async function commitInChunks(
  operations: BatchOperation[]
): Promise<void> {
  const db = admin.firestore();

  for (let i = 0; i < operations.length; i += BATCH_LIMIT) {
    const chunk = operations.slice(i, i + BATCH_LIMIT);
    const batch = db.batch();

    for (const op of chunk) {
      if (op.type === "delete") {
        batch.delete(op.ref);
      } else if (op.type === "update" && op.data) {
        batch.update(op.ref, op.data);
      }
    }

    await batch.commit();
  }
}

/**
 * Collects all document refs from a subcollection in one shot.
 *
 * **Avoid for unbounded subcollections** (messages, expenses, tasks
 * under a long-lived event). The whole snapshot is held in memory
 * before the caller processes it; a 100k-doc subcollection blows the
 * 256 MiB callable memory limit. Use [streamDeleteSubcollection]
 * for delete workloads instead.
 */
export async function getSubcollectionRefs(
  parentRef: FirebaseFirestore.DocumentReference,
  subcollection: string
): Promise<FirebaseFirestore.DocumentReference[]> {
  const snapshot = await parentRef.collection(subcollection).get();
  return snapshot.docs.map((doc) => doc.ref);
}

/**
 * Deletes every doc in `parentRef.collection(subcollection)` in pages
 * of `BATCH_LIMIT` (500), bounded memory.
 *
 * Pattern: `query.limit(500).get()` → batched delete → re-query until
 * the page is empty. We do NOT carry `startAfter` across pages because
 * the cursor anchor would be one of the docs we just deleted; re-running
 * `limit(500)` from the start lands on the next 500 surviving docs.
 *
 * Idempotent: running twice in a row on the same parent simply reports
 * `empty` on the first iteration of the second invocation. Tolerant of
 * concurrent inserts (those just become the next page).
 */
export async function streamDeleteSubcollection(
  parentRef: FirebaseFirestore.DocumentReference,
  subcollection: string
): Promise<void> {
  const db = admin.firestore();
  // eslint-disable-next-line no-constant-condition
  while (true) {
    const snapshot = await parentRef
      .collection(subcollection)
      .limit(BATCH_LIMIT)
      .get();
    if (snapshot.empty) return;

    const batch = db.batch();
    for (const doc of snapshot.docs) {
      batch.delete(doc.ref);
    }
    await batch.commit();
  }
}
