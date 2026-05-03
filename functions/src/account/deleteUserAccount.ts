import {onCall, HttpsError} from "firebase-functions/v2/https";
import {logger} from "firebase-functions/v2";
import * as admin from "firebase-admin";
import {
  commitInChunks,
  streamDeleteSubcollection,
  BatchOperation,
} from "../utils/batch";
import {withStructuredLogs} from "../utils/logging";

const db = admin.firestore();
const storage = admin.storage();
const auth = admin.auth();

/**
 * Stage tag used in the `details.stage` field of every typed `HttpsError`
 * thrown by this function. The Flutter client maps these to typed
 * `errorCode` strings via `AccountDeletionService._mapFunctionsException`.
 */
const STAGE_FIRESTORE = "firestore";
const STAGE_STORAGE = "storage";
const STAGE_AUTH = "auth";

const CODE_FIRESTORE_CLEANUP_FAILED = "firestore-cleanup-failed";
const CODE_AUTH_DELETE_FAILED = "auth-delete-failed";

/**
 * Bounded retry helper around `admin.auth().deleteUser(uid)`.
 *
 * Auth deletion failures are the source of the partial-deletion bug
 * fixed in this spec — Firestore + Storage have already been wiped by
 * the time we reach the auth stage, so retrying here keeps the function
 * idempotent over a transient Firebase Auth blip without leaving the
 * user with an orphaned auth record.
 *
 * Exported for unit testing — production wires `deleter` to
 * `(u) => admin.auth().deleteUser(u)`.
 */
export async function deleteAuthUserWithRetry(
  uid: string,
  deleter: (uid: string) => Promise<void>,
  options: {attempts?: number; backoffMs?: number} = {}
): Promise<void> {
  const attempts = options.attempts ?? 3;
  const backoffMs = options.backoffMs ?? 250;
  let lastError: unknown;

  for (let attempt = 1; attempt <= attempts; attempt++) {
    try {
      logger.info("deleteUserAccount auth.attempt", {
        op: "deleteUserAccount",
        uid,
        stage: STAGE_AUTH,
        attempt,
      });
      await deleter(uid);
      logger.info("deleteUserAccount auth.complete", {
        op: "deleteUserAccount",
        uid,
        stage: STAGE_AUTH,
        attempt,
      });
      return;
    } catch (err) {
      lastError = err;
      logger.warn("deleteUserAccount auth.attempt-failed", {
        op: "deleteUserAccount",
        uid,
        stage: STAGE_AUTH,
        attempt,
        error: err instanceof Error ? err.message : String(err),
      });
      if (attempt < attempts) {
        await new Promise<void>((resolve) =>
          setTimeout(resolve, backoffMs)
        );
      }
    }
  }
  throw lastError;
}

/**
 * Deletes an event and all its subcollections (messages, expenses,
 * tasks). Bounded memory via paged streaming deletes — safe for events
 * with arbitrarily large subcollections.
 */
async function deleteEventCompletely(
  eventRef: FirebaseFirestore.DocumentReference
): Promise<void> {
  for (const sub of ["messages", "expenses", "tasks"]) {
    await streamDeleteSubcollection(eventRef, sub);
  }
  await eventRef.delete();
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
 * Server-side account deletion in the order specified by the spec:
 * 1. Verify the caller (`request.auth.uid`).
 * 2. Firestore: delete solo events / anonymize shared events / transfer
 *    ownership / delete `users/{uid}/private/profile` / delete
 *    `users/{uid}`. Wrapped — failure throws `HttpsError` with
 *    `details.stage = 'firestore'`, `details.code = 'firestore-cleanup-failed'`.
 * 3. Storage: delete `users/{uid}/`. Failure is **non-fatal** — logged
 *    as a structured warning, function continues to the auth stage.
 * 4. Auth: `admin.auth().deleteUser(uid)` with bounded retry (3 attempts,
 *    250 ms linear backoff). Final failure throws `HttpsError` with
 *    `details.stage = 'auth'`, `details.code = 'auth-delete-failed'`.
 * 5. Return `{success: true}`.
 *
 * The retry only wraps the auth stage because that is where the
 * partial-deletion bug surfaces — Firestore + Storage are already
 * gone, so retrying the auth deletion is the cheapest path to a
 * fully-clean account state.
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

    return withStructuredLogs(
      {op: "deleteUserAccount", uid, args: {}},
      async () => {
        // ----- Stage 1: Firestore wipe / anonymize ----- //
        try {
          logger.info("deleteUserAccount firestore.start", {
            op: "deleteUserAccount",
            uid,
            stage: STAGE_FIRESTORE,
          });
          const eventsSnapshot = await db
            .collection("events")
            .where("memberIds", "array-contains", uid)
            .get();

          logger.info(
            `deleteUserAccount found ${eventsSnapshot.size} events for ${uid}`,
            {
              op: "deleteUserAccount",
              uid,
              stage: STAGE_FIRESTORE,
              eventCount: eventsSnapshot.size,
            }
          );

          for (const eventDoc of eventsSnapshot.docs) {
            const eventData = eventDoc.data();
            const memberIds: string[] = eventData.memberIds || [];

            if (memberIds.length <= 1) {
              await deleteEventCompletely(eventDoc.ref);
            } else {
              await anonymizeUserInEvent(eventDoc.ref, eventData, uid);
            }
          }

          // Firestore does NOT cascade-delete subcollections, so we
          // explicitly tear down the private/profile subdoc before
          // deleting the parent user doc. Idempotent on retry.
          await db
            .collection("users")
            .doc(uid)
            .collection("private")
            .doc("profile")
            .delete()
            .catch((err: unknown) => {
              logger.warn(
                `deleteUserAccount private subdoc cleanup warning for ${uid}`,
                {
                  op: "deleteUserAccount",
                  uid,
                  stage: STAGE_FIRESTORE,
                  error: err instanceof Error ? err.message : String(err),
                }
              );
            });
          await db.collection("users").doc(uid).delete();

          logger.info("deleteUserAccount firestore.complete", {
            op: "deleteUserAccount",
            uid,
            stage: STAGE_FIRESTORE,
          });
        } catch (err) {
          if (err instanceof HttpsError) throw err;
          logger.error("deleteUserAccount firestore.failed", {
            op: "deleteUserAccount",
            uid,
            stage: STAGE_FIRESTORE,
            error: err instanceof Error ? err.message : String(err),
          });
          throw new HttpsError(
            "internal",
            "Account deletion failed during data cleanup. Please try again.",
            {stage: STAGE_FIRESTORE, code: CODE_FIRESTORE_CLEANUP_FAILED}
          );
        }

        // ----- Stage 2: Storage wipe (non-fatal) ----- //
        try {
          logger.info("deleteUserAccount storage.start", {
            op: "deleteUserAccount",
            uid,
            stage: STAGE_STORAGE,
          });
          await deleteUserStorage(uid);
          logger.info("deleteUserAccount storage.complete", {
            op: "deleteUserAccount",
            uid,
            stage: STAGE_STORAGE,
          });
        } catch (storageError) {
          logger.warn(`deleteUserAccount storage cleanup warning for ${uid}`, {
            op: "deleteUserAccount",
            uid,
            stage: STAGE_STORAGE,
            error:
              storageError instanceof Error
                ? storageError.message
                : String(storageError),
          });
        }

        // ----- Stage 3: Auth deletion with bounded retry ----- //
        try {
          await deleteAuthUserWithRetry(uid, (u) => auth.deleteUser(u));
        } catch (authError) {
          logger.error("deleteUserAccount auth.exhausted", {
            op: "deleteUserAccount",
            uid,
            stage: STAGE_AUTH,
            error:
              authError instanceof Error
                ? authError.message
                : String(authError),
          });
          throw new HttpsError(
            "internal",
            "Your data was deleted but the sign-in record could not " +
              "be removed. Please try again — your data is gone, only " +
              "the auth record remains.",
            {stage: STAGE_AUTH, code: CODE_AUTH_DELETE_FAILED}
          );
        }

        return {success: true};
      }
    );
  }
);
