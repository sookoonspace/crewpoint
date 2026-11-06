import {memberRef, prepareRoleChange} from "../events/members";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {logger} from "firebase-functions/v2";
import {createHmac, randomBytes} from "crypto";
import {getAuth} from "firebase-admin/auth";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import {
  commitInChunks,
  streamDeleteSubcollection,
  BatchOperation,
} from "../utils/batch";
import {deleteEventCompletely} from "../events/eventDeletion";
import {ensurePersonalOrganizer} from "../events/organizers";
import {withStructuredLogs} from "../utils/logging";

const db = getFirestore();
const storage = getStorage();
const auth = getAuth();

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
 * Bounded retry helper around `getAuth().deleteUser(uid)`.
 *
 * Auth deletion failures are the source of the partial-deletion bug
 * fixed in this spec — Firestore + Storage have already been wiped by
 * the time we reach the auth stage, so retrying here keeps the function
 * idempotent over a transient Firebase Auth blip without leaving the
 * user with an orphaned auth record.
 *
 * Exported for unit testing — production wires `deleter` to
 * `(u) => getAuth().deleteUser(u)`.
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
 * The anonymous ID that stands in for a deleted person in one event.
 *
 * One person gets one ID per event, so a ledger still balances and two deleted
 * people are never merged. It comes from a per-event secret only the server can
 * read, so it cannot be traced back to the person, yet a retry after a partial
 * failure gets the same ID instead of splitting them in two.
 */
async function anonymousIdFor(
  eventRef: FirebaseFirestore.DocumentReference,
  uid: string
): Promise<string> {
  const secretRef = eventRef.collection("anonymisation").doc("secret");
  const secret = await db.runTransaction(async (tx) => {
    const existing = await tx.get(secretRef);
    if (existing.exists) return existing.data()!.value as string;
    const value = randomBytes(32).toString("hex");
    tx.set(secretRef, {value});
    return value;
  });
  const digest = createHmac("sha256", secret).update(uid).digest("hex");
  return `deleted_${digest.slice(0, 24)}`;
}

/**
 * Removes a person from a shared event:
 * - Replaces their ID with an anonymous one in expenses, tasks and messages
 * - Unassigns their tasks, and removes their urgent rate record
 * - Transfers creatorId and organizerId to the first admin, or else the first
 *   remaining member, who gets a personal organizer if they have none
 * - Removes them from memberIds and adminIds, and deletes their member
 *   document. A new owner's member document takes the Owner role.
 *
 * Membership changes last. A retry finds the event through memberIds, so it
 * must stay until the shared records are clean.
 */
export async function anonymizeUserInEvent(
  eventRef: FirebaseFirestore.DocumentReference,
  eventData: FirebaseFirestore.DocumentData,
  uid: string
): Promise<void> {
  const anonymousId = await anonymousIdFor(eventRef, uid);
  const swap = (id: string) => (id === uid ? anonymousId : id);

  // Several queries can match one document, so changes merge by path.
  const updates = new Map<string, BatchOperation>();
  const change = (
    ref: FirebaseFirestore.DocumentReference,
    data: Record<string, unknown>
  ) => {
    const existing = updates.get(ref.path);
    updates.set(ref.path, {
      type: "update",
      ref,
      data: {...existing?.data, ...data},
    });
  };

  const replaceIn = async (
    collection: string,
    field: string,
    replacement: string | null
  ) => {
    const matches = await eventRef
      .collection(collection)
      .where(field, "==", uid)
      .get();
    matches.docs.forEach((doc) => change(doc.ref, {[field]: replacement}));
  };

  await replaceIn("messages", "senderId", anonymousId);
  await replaceIn("messages", "payerId", anonymousId);
  await replaceIn("messages", "payeeId", anonymousId);
  await replaceIn("tasks", "createdBy", anonymousId);
  await replaceIn("tasks", "completedBy", anonymousId);
  await replaceIn("tasks", "assigneeId", null);

  // Older expenses have no involvedUids, and Firestore cannot query inside a
  // list of splits, so this reads the event's expenses.
  const expenses = await eventRef
    .collection("expenses")
    .select("payerId", "splits", "involvedUids")
    .get();
  for (const doc of expenses.docs) {
    const expense = doc.data();
    const splits: {userId: string; amount: number}[] = expense.splits ?? [];
    const involved: string[] = expense.involvedUids ?? [];
    const isInvolved =
      expense.payerId === uid ||
      involved.includes(uid) ||
      splits.some((split) => split.userId === uid);
    if (!isInvolved) continue;
    const data: Record<string, unknown> = {payerId: swap(expense.payerId)};
    if (expense.splits) {
      data.splits = splits.map((s) => ({...s, userId: swap(s.userId)}));
    }
    if (expense.involvedUids) data.involvedUids = involved.map(swap);
    change(doc.ref, data);
  }

  await commitInChunks([
    ...updates.values(),
    {type: "delete", ref: eventRef.collection("urgentRates").doc(uid)},
  ]);

  const memberIds: string[] = eventData.memberIds || [];
  const adminIds: string[] = eventData.adminIds || [];
  const remainingMembers = memberIds.filter((m: string) => m !== uid);
  const updateData: Record<string, unknown> = {
    memberIds: FieldValue.arrayRemove(uid),
    adminIds: FieldValue.arrayRemove(uid),
    memberCount: remainingMembers.length,
  };
  let nextOwner: string | null = null;
  if (remainingMembers.length > 0) {
    // Prefer first admin, fallback to first remaining member
    const remainingAdmins = adminIds.filter((a: string) => a !== uid);
    const successor = remainingAdmins[0] ?? remainingMembers[0];
    if (eventData.creatorId === uid) {
      updateData.creatorId = successor;
      nextOwner = successor;
    }
    if (eventData.organizerId === uid) {
      await ensurePersonalOrganizer(db, successor);
      updateData.organizerId = successor;
    }
  }
  await db.runTransaction(async (tx) => {
    // The next owner takes the Owner role in place of Admin or Participant.
    const writeOwner = nextOwner ?
      await prepareRoleChange(tx, eventRef, eventData, nextOwner, (ids) => [
        ...ids.filter((r) => !["owner", "admin", "participant"].includes(r)),
        "owner",
      ]) :
      () => undefined;
    writeOwner();
    tx.delete(memberRef(eventRef, uid));
    tx.update(eventRef, updateData);
  });
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
 *    ownership / delete personal subcollections / delete `users/{uid}`. Wrapped — failure throws `HttpsError` with
 *    `details.stage = 'firestore'`, `details.code = 'firestore-cleanup-failed'`.
 * 3. Storage: delete `users/{uid}/`. Failure is **non-fatal** — logged
 *    as a structured warning, function continues to the auth stage.
 * 4. Auth: `getAuth().deleteUser(uid)` with bounded retry (3 attempts,
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
              await deleteEventCompletely(eventDoc.ref, eventData);
            } else {
              await anonymizeUserInEvent(eventDoc.ref, eventData, uid);
            }
          }

          // Firestore does NOT cascade-delete subcollections, so personal
          // documents go before the parent user doc. Idempotent on retry.
          const userRef = db.collection("users").doc(uid);
          for (const sub of ["private", "chatReads", "eventMutes"]) {
            await streamDeleteSubcollection(userRef, sub);
          }
          await db.collection("organizers").doc(uid).delete();
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
