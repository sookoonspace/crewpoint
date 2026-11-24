import {getFirestore} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import {logger} from "firebase-functions/v2";
import {commitInChunks, BatchOperation} from "../utils/batch";

/**
 * Deletes an event completely: every subcollection, including checklists and
 * any added later, its invite codes and link name, members' personal
 * documents for it, and its cover photo.
 * The event goes last, so a retry after a failure can still find its members.
 */
export async function deleteEventCompletely(
  eventRef: FirebaseFirestore.DocumentReference,
  eventData: FirebaseFirestore.DocumentData
): Promise<void> {
  const db = getFirestore();
  const memberIds: string[] = eventData.memberIds || [];

  const ops: BatchOperation[] = [];
  for (const uid of memberIds) {
    const user = db.collection("users").doc(uid);
    ops.push({type: "delete", ref: user.collection("chatReads").doc(eventRef.id)});
    ops.push({type: "delete", ref: user.collection("eventMutes").doc(eventRef.id)});
  }
  const invites = await db
    .collection("event_invites")
    .where("eventId", "==", eventRef.id)
    .get();
  invites.docs.forEach((invite) => ops.push({type: "delete", ref: invite.ref}));
  // Its link name, so another event can take it (#239).
  const slugs = await db.collection("eventSlugs").where("eventId", "==", eventRef.id).get();
  slugs.docs.forEach((slug) => ops.push({type: "delete", ref: slug.ref}));
  await commitInChunks(ops);

  // The cover photo (Spec #186 Req 41). A failure here must not keep the
  // event: once its member documents are gone nobody can read the file, and
  // the warning shows what to clean up.
  try {
    await getStorage()
      .bucket()
      .file(`events/${eventRef.id}/cover.jpg`)
      .delete({ignoreNotFound: true});
  } catch (error) {
    logger.warn("deleteEvent cover cleanup failed", {
      eventId: eventRef.id,
      error: error instanceof Error ? error.message : String(error),
    });
  }

  await db.recursiveDelete(eventRef);
}
