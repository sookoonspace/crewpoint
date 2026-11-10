import {FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";
import {BatchOperation, commitInChunks} from "../utils/batch";
import {mapLegacyStatus} from "../events/eventStatus";
import {emailMatchKey, externalIdMatchKey} from "./matchKeys";

const db = () => getFirestore();

/** An unnamed entry sorts after every name in the roster. */
export const UNNAMED_SORT = "";

function hasEnded(event: FirebaseFirestore.DocumentData | undefined): boolean {
  if (!event) return true;
  const end = (event.endDate as Timestamp | null | undefined)?.toDate();
  return ["ended", "archived"].includes(mapLegacyStatus(event.status, end, new Date()));
}

/**
 * Removes a deleting account's participant data (Req 14a, decided in #78).
 * Safe to repeat: each step finds its work by the person's ID, which the step
 * itself removes.
 *
 * 1. Groups they are a linked adult of lose them. If nobody else is linked,
 *    the children they entered there by hand go too. Imported records, and
 *    children they entered for other groups, stay.
 * 2. Records linked to them become unnamed entries: age band, status, group
 *    and choice answers stay, so counts do not change, while the name, import
 *    ID, answers and private details go. In an event that has not ended, a
 *    server-only match key of the email and import ID is kept, so a new
 *    account or a re-import finds the entry again instead of adding a second.
 * 3. Their link requests and any member documents left go.
 */
export async function removeParticipantData(uid: string): Promise<void> {
  const groups = await db().collectionGroup("groups")
    .where("adultUids", "array-contains", uid).get();
  for (const group of groups.docs) {
    const ops: BatchOperation[] = [];
    const others = (group.data().adultUids as string[]).filter((u) => u !== uid);
    if (others.length === 0) {
      const people = group.ref.parent.parent!.collection("participants");
      const children = await people.where("groupId", "==", group.id)
        .where("createdBy", "==", uid).get();
      for (const child of children.docs) {
        if (child.data().isChild !== true || child.data().imported === true) continue;
        ops.push({type: "delete", ref: child.ref.collection("private").doc("details")});
        ops.push({type: "delete", ref: child.ref});
      }
    }
    ops.push({type: "update", ref: group.ref, data: {
      adultUids: FieldValue.arrayRemove(uid), updatedAt: FieldValue.serverTimestamp(),
    }});
    await commitInChunks(ops);
  }

  const linked = await db().collectionGroup("participants").where("uid", "==", uid).get();
  for (const record of linked.docs) {
    const eventRef = record.ref.parent.parent!;
    const [eventDoc, details] = await Promise.all([
      eventRef.get(),
      record.ref.collection("private").doc("details").get(),
    ]);
    const data = record.data();
    const ops: BatchOperation[] = [];
    if (!hasEnded(eventDoc.data())) {
      const email = details.data()?.email;
      const keys: Record<string, string> = {};
      if (typeof email === "string" && email) keys.emailKey = await emailMatchKey(email);
      if (typeof data.externalId === "string" && data.externalId) {
        keys.externalIdKey = await externalIdMatchKey(eventRef.id, data.externalId);
      }
      if (Object.keys(keys).length > 0) {
        ops.push({type: "set", ref: eventRef.collection("participantKeys").doc(record.id), data: keys});
      }
    }
    ops.push({type: "delete", ref: details.ref});
    ops.push({type: "update", ref: record.ref, data: {
      name: "",
      sortName: UNNAMED_SORT,
      anonymised: true,
      uid: FieldValue.delete(),
      externalId: FieldValue.delete(),
      fields: FieldValue.delete(),
      ...(data.createdBy === uid ? {createdBy: null} : {}),
      updatedAt: FieldValue.serverTimestamp(),
    }});
    await commitInChunks(ops);
  }

  const [requests, members] = await Promise.all([
    db().collectionGroup("linkRequests").where("uid", "==", uid).get(),
    db().collectionGroup("members").where("uid", "==", uid).get(),
  ]);
  await commitInChunks([...requests.docs, ...members.docs]
    .map((d) => ({type: "delete", ref: d.ref}) as BatchOperation));
}
