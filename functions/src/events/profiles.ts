import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {commitInChunks, BatchOperation} from "../utils/batch";
import {HANDLE_FIELDS, PROFILE_FIELDS, profileFrom} from "./profileFields";

export {profileFrom};

const db = getFirestore();

type Data = FirebaseFirestore.DocumentData | undefined;

export function profileRef(
  eventRef: FirebaseFirestore.DocumentReference,
  uid: string
): FirebaseFirestore.DocumentReference {
  return eventRef.collection("profiles").doc(uid);
}

/**
 * Someone joining gets a profile in the event, and someone leaving keeps
 * their name there, so older messages still show who wrote them, without
 * their handles.
 */
export async function handleMemberWritten({
  eventId,
  uid,
  before,
  after,
}: {
  eventId: string;
  uid: string;
  before: Data;
  after: Data;
}): Promise<void> {
  const ref = profileRef(db.collection("events").doc(eventId), uid);
  if (!before && after) {
    const user = await db.collection("users").doc(uid).get();
    await ref.set(profileFrom(uid, user.data()));
    return;
  }
  if (before && !after) {
    const drop = Object.fromEntries(
      HANDLE_FIELDS.map((f) => [f, FieldValue.delete()])
    );
    try {
      await ref.update(drop);
    } catch (e) {
      // NOT_FOUND: the account was deleted, which removes its profiles.
      if ((e as {code?: number}).code !== 5) throw e;
    }
  }
}

/**
 * A profile edit reaches every event the person is in. Events they have
 * left keep only the name they had. A deleted account is handled by
 * `deleteUserAccount`.
 */
export async function handleUserWritten({
  uid,
  before,
  after,
}: {
  uid: string;
  before: Data;
  after: Data;
}): Promise<void> {
  if (!after) return;
  const next = profileFrom(uid, after);
  const previous = profileFrom(uid, before);
  if (PROFILE_FIELDS.every((f) => next[f] === previous[f])) return;
  const memberships = await db
    .collectionGroup("members")
    .where("uid", "==", uid)
    .get();
  const ops: BatchOperation[] = memberships.docs.map((member) => ({
    type: "set",
    ref: profileRef(member.ref.parent.parent!, uid),
    data: next,
  }));
  await commitInChunks(ops);
}

export const onMemberProfileSync = onDocumentWritten(
  {document: "events/{eventId}/members/{uid}", timeoutSeconds: 30},
  async (event) => {
    await handleMemberWritten({
      eventId: event.params.eventId,
      uid: event.params.uid,
      before: event.data?.before.data(),
      after: event.data?.after.data(),
    });
  }
);

export const onUserProfileSync = onDocumentWritten(
  {document: "users/{uid}", timeoutSeconds: 60},
  async (event) => {
    await handleUserWritten({
      uid: event.params.uid,
      before: event.data?.before.data(),
      after: event.data?.after.data(),
    });
  }
);
