import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();
const storage = admin.storage();
const auth = admin.auth();

const BATCH_LIMIT = 500;

/**
 * Commits Firestore operations in chunks of 500 to avoid batch limits.
 * Each chunk is committed sequentially.
 */
async function commitInChunks(
  operations: Array<{
    type: "delete" | "update";
    ref: FirebaseFirestore.DocumentReference;
    data?: Record<string, unknown>;
  }>
): Promise<void> {
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
 * Collects all document refs from a subcollection for batch operations.
 */
async function getSubcollectionRefs(
  eventRef: FirebaseFirestore.DocumentReference,
  subcollection: string
): Promise<FirebaseFirestore.DocumentReference[]> {
  const snapshot = await eventRef.collection(subcollection).get();
  return snapshot.docs.map((doc) => doc.ref);
}

/**
 * Deletes an event and all its subcollections (messages, expenses, tasks).
 */
async function deleteEventCompletely(
  eventRef: FirebaseFirestore.DocumentReference
): Promise<void> {
  const ops: Array<{
    type: "delete";
    ref: FirebaseFirestore.DocumentReference;
  }> = [];

  // Collect all subcollection documents
  for (const sub of ["messages", "expenses", "tasks"]) {
    const refs = await getSubcollectionRefs(eventRef, sub);
    for (const ref of refs) {
      ops.push({type: "delete", ref});
    }
  }

  // Delete the event document itself
  ops.push({type: "delete", ref: eventRef});

  await commitInChunks(ops);
}

/**
 * Anonymizes a user's data in a shared event:
 * - Transfers creatorId if the user is the creator
 * - Removes user from members array
 * - Anonymizes messages (senderId -> 'deleted_user')
 * - Anonymizes expenses (payerId -> 'deleted_user')
 * - Unassigns tasks (assigneeId -> null)
 */
async function anonymizeUserInEvent(
  eventRef: FirebaseFirestore.DocumentReference,
  eventData: FirebaseFirestore.DocumentData,
  uid: string
): Promise<void> {
  const ops: Array<{
    type: "update" | "delete";
    ref: FirebaseFirestore.DocumentReference;
    data?: Record<string, unknown>;
  }> = [];

  // Transfer ownership if user is creator
  const members: string[] = eventData.members || [];
  const remainingMembers = members.filter((m: string) => m !== uid);
  const updateData: Record<string, unknown> = {
    members: admin.firestore.FieldValue.arrayRemove(uid),
  };

  if (eventData.creatorId === uid && remainingMembers.length > 0) {
    updateData.creatorId = remainingMembers[0];
  }

  ops.push({type: "update", ref: eventRef, data: updateData});

  // Anonymize messages sent by this user
  const messagesSnapshot = await eventRef
    .collection("messages")
    .where("senderId", "==", uid)
    .get();

  for (const doc of messagesSnapshot.docs) {
    ops.push({
      type: "update",
      ref: doc.ref,
      data: {senderId: "deleted_user"},
    });
  }

  // Anonymize expenses paid by this user
  const expensesSnapshot = await eventRef
    .collection("expenses")
    .where("payerId", "==", uid)
    .get();

  for (const doc of expensesSnapshot.docs) {
    ops.push({
      type: "update",
      ref: doc.ref,
      data: {payerId: "deleted_user"},
    });
  }

  // Unassign tasks assigned to this user
  const tasksSnapshot = await eventRef
    .collection("tasks")
    .where("assigneeId", "==", uid)
    .get();

  for (const doc of tasksSnapshot.docs) {
    ops.push({
      type: "update",
      ref: doc.ref,
      data: {assigneeId: null},
    });
  }

  await commitInChunks(ops);
}

/**
 * Deletes all files in a user's Storage folder.
 */
async function deleteUserStorage(uid: string): Promise<void> {
  const bucket = storage.bucket();
  const [files] = await bucket.getFiles({prefix: `users/${uid}/`});

  // Delete in batches to avoid memory issues with many files
  const deletePromises = files.map((file) => file.delete());
  await Promise.all(deletePromises);
}

/**
 * deleteUserAccount — Firebase Callable Cloud Function
 *
 * Handles complete account deletion server-side:
 * 1. Solo events → hard delete
 * 2. Shared events → anonymize + transfer ownership
 * 3. Delete user document
 * 4. Delete user storage files
 * 5. Delete Firebase Auth user (last)
 */
export const deleteUserAccount = functions
  .runWith({timeoutSeconds: 120, memory: "256MB"})
  .https.onCall(async (_data, context) => {
    // 1. Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Must be authenticated to delete account."
      );
    }

    const uid = context.auth.uid;
    functions.logger.info(`Starting account deletion for user ${uid}`);

    try {
      // 2. Query all events where user is a member
      const eventsSnapshot = await db
        .collection("events")
        .where("members", "array-contains", uid)
        .get();

      functions.logger.info(
        `Found ${eventsSnapshot.size} events for user ${uid}`
      );

      // 3 & 4. Process each event
      for (const eventDoc of eventsSnapshot.docs) {
        const eventData = eventDoc.data();
        const members: string[] = eventData.members || [];

        if (members.length <= 1) {
          // Solo event — delete completely
          functions.logger.info(
            `Deleting solo event ${eventDoc.id}`
          );
          await deleteEventCompletely(eventDoc.ref);
        } else {
          // Shared event — anonymize
          functions.logger.info(
            `Anonymizing user in shared event ${eventDoc.id}`
          );
          await anonymizeUserInEvent(eventDoc.ref, eventData, uid);
        }
      }

      // 5. Delete user document
      functions.logger.info(`Deleting user document ${uid}`);
      await db.collection("users").doc(uid).delete();

      // 6. Delete user storage files
      functions.logger.info(`Deleting storage files for ${uid}`);
      try {
        await deleteUserStorage(uid);
      } catch (storageError) {
        // Storage folder may not exist — log and continue
        functions.logger.warn(
          `Storage cleanup warning for ${uid}:`,
          storageError
        );
      }

      // 7. Delete Firebase Auth user — LAST STEP
      functions.logger.info(`Deleting auth user ${uid}`);
      await auth.deleteUser(uid);

      functions.logger.info(
        `Account deletion completed for user ${uid}`
      );
      return {success: true};
    } catch (error) {
      functions.logger.error(
        `Account deletion failed for user ${uid}:`,
        error
      );
      throw new functions.https.HttpsError(
        "internal",
        "Account deletion failed. Please try again or contact support."
      );
    }
  });
