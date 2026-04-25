import {onCall, HttpsError} from "firebase-functions/v2/https";
import {logger} from "firebase-functions/v2";
import * as admin from "firebase-admin";
import {commitInChunks, getSubcollectionRefs, BatchOperation} from "../utils/batch";

const db = admin.firestore();
const storage = admin.storage();
const auth = admin.auth();

/**
 * Deletes an event and all its subcollections (messages, expenses, tasks).
 */
async function deleteEventCompletely(
  eventRef: FirebaseFirestore.DocumentReference
): Promise<void> {
  const ops: BatchOperation[] = [];

  for (const sub of ["messages", "expenses", "tasks"]) {
    const refs = await getSubcollectionRefs(eventRef, sub);
    for (const ref of refs) {
      ops.push({type: "delete", ref});
    }
  }

  ops.push({type: "delete", ref: eventRef});
  await commitInChunks(ops);
}

/**
 * Anonymizes a user's data in a shared event:
 * - Transfers creatorId to first admin (or first remaining member)
 * - Removes user from memberIds and adminIds
 * - Anonymizes messages/expenses
 * - Unassigns tasks
 */
async function anonymizeUserInEvent(
  eventRef: FirebaseFirestore.DocumentReference,
  eventData: FirebaseFirestore.DocumentData,
  uid: string
): Promise<void> {
  const ops: BatchOperation[] = [];

  const memberIds: string[] = eventData.memberIds || [];
  const adminIds: string[] = eventData.adminIds || [];
  const remainingMembers = memberIds.filter((m: string) => m !== uid);
  const updateData: Record<string, unknown> = {
    memberIds: admin.firestore.FieldValue.arrayRemove(uid),
    adminIds: admin.firestore.FieldValue.arrayRemove(uid),
  };

  // Transfer ownership if user is creator
  if (eventData.creatorId === uid && remainingMembers.length > 0) {
    // Prefer first admin, fallback to first remaining member
    const remainingAdmins = adminIds.filter((a: string) => a !== uid);
    updateData.creatorId = remainingAdmins.length > 0
      ? remainingAdmins[0]
      : remainingMembers[0];
  }

  ops.push({type: "update", ref: eventRef, data: updateData});

  // Anonymize messages
  const messagesSnapshot = await eventRef
    .collection("messages")
    .where("senderId", "==", uid)
    .get();

  for (const doc of messagesSnapshot.docs) {
    ops.push({type: "update", ref: doc.ref, data: {senderId: "deleted_user"}});
  }

  // Anonymize expenses
  const expensesSnapshot = await eventRef
    .collection("expenses")
    .where("payerId", "==", uid)
    .get();

  for (const doc of expensesSnapshot.docs) {
    ops.push({type: "update", ref: doc.ref, data: {payerId: "deleted_user"}});
  }

  // Unassign tasks
  const tasksSnapshot = await eventRef
    .collection("tasks")
    .where("assigneeId", "==", uid)
    .get();

  for (const doc of tasksSnapshot.docs) {
    ops.push({type: "update", ref: doc.ref, data: {assigneeId: null}});
  }

  await commitInChunks(ops);
}

/**
 * Deletes all files in a user's Storage folder.
 */
async function deleteUserStorage(uid: string): Promise<void> {
  const bucket = storage.bucket();
  const [files] = await bucket.getFiles({prefix: `users/${uid}/`});
  await Promise.all(files.map((file) => file.delete()));
}

/**
 * deleteUserAccount — Firebase Callable Cloud Function (2nd Gen)
 *
 * Server-side account deletion:
 * 1. Solo events → hard delete
 * 2. Shared events → anonymize + transfer ownership to first admin
 * 3. Delete user document
 * 4. Delete user storage files
 * 5. Delete Firebase Auth user (last)
 */
export const deleteUserAccount = onCall(
  {timeoutSeconds: 120, memory: "256MiB"},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Must be authenticated to delete account."
      );
    }

    const uid = request.auth.uid;
    logger.info(`Starting account deletion for user ${uid}`);

    try {
      // Query all events where user is a member
      const eventsSnapshot = await db
        .collection("events")
        .where("memberIds", "array-contains", uid)
        .get();

      logger.info(`Found ${eventsSnapshot.size} events for user ${uid}`);

      // Process each event
      for (const eventDoc of eventsSnapshot.docs) {
        const eventData = eventDoc.data();
        const memberIds: string[] = eventData.memberIds || [];

        if (memberIds.length <= 1) {
          logger.info(`Deleting solo event ${eventDoc.id}`);
          await deleteEventCompletely(eventDoc.ref);
        } else {
          logger.info(`Anonymizing user in shared event ${eventDoc.id}`);
          await anonymizeUserInEvent(eventDoc.ref, eventData, uid);
        }
      }

      // Delete user document
      logger.info(`Deleting user document ${uid}`);
      await db.collection("users").doc(uid).delete();

      // Delete user storage files
      logger.info(`Deleting storage files for ${uid}`);
      try {
        await deleteUserStorage(uid);
      } catch (storageError) {
        logger.warn(`Storage cleanup warning for ${uid}:`, storageError);
      }

      // Delete Firebase Auth user — LAST STEP
      logger.info(`Deleting auth user ${uid}`);
      await auth.deleteUser(uid);

      logger.info(`Account deletion completed for user ${uid}`);
      return {success: true};
    } catch (error) {
      logger.error(`Account deletion failed for user ${uid}:`, error);
      throw new HttpsError(
        "internal",
        "Account deletion failed. Please try again or contact support."
      );
    }
  }
);
