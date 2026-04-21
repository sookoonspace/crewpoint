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
 * Collects all document refs from a subcollection.
 */
export async function getSubcollectionRefs(
  parentRef: FirebaseFirestore.DocumentReference,
  subcollection: string
): Promise<FirebaseFirestore.DocumentReference[]> {
  const snapshot = await parentRef.collection(subcollection).get();
  return snapshot.docs.map((doc) => doc.ref);
}
