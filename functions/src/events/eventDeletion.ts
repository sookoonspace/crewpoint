import {getFirestore} from "firebase-admin/firestore";
import {commitInChunks, BatchOperation} from "../utils/batch";

/**
 * Deletes an event completely: every subcollection, including checklists and
 * any added later, its invite codes, and members' personal documents for it.
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
  await commitInChunks(ops);

  await db.recursiveDelete(eventRef);
}
