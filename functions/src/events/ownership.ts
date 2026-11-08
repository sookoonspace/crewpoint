import {onCall, HttpsError} from "firebase-functions/v2/https";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {requireString, withStructuredLogs} from "../utils/logging";
import {assertNotArchived} from "./eventStatus";
import {prepareRoleChange, readPermissions, readRoleIds} from "./members";
import {ensurePersonalOrganizer} from "./organizers";

const db = getFirestore();

/**
 * The pending offer, `events/{id}/ownership/offer`: `{from, to, createdAt}`.
 * Only the server writes it, and members can read it, so the person offered
 * sees it (Req 30).
 */
export function offerRef(
  eventRef: FirebaseFirestore.DocumentReference
): FirebaseFirestore.DocumentReference {
  return eventRef.collection("ownership").doc("offer");
}

async function readEvent(
  tx: FirebaseFirestore.Transaction,
  eventRef: FirebaseFirestore.DocumentReference
): Promise<FirebaseFirestore.DocumentData> {
  const doc = await tx.get(eventRef);
  if (!doc.exists) throw new HttpsError("not-found", "Event not found.");
  const data = doc.data()!;
  assertNotArchived(data);
  return data;
}

/**
 * offerOwnership — the Owner offers ownership to anyone else in the event,
 * whatever their role (Req 30). Nothing changes until they accept. A new
 * offer replaces any earlier one.
 */
export const offerOwnership = onCall({timeoutSeconds: 30}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const uid = request.auth.uid;
  const data = (request.data ?? {}) as Record<string, unknown>;
  const eventId = requireString(data.eventId, "eventId");
  const toUid = requireString(data.toUid, "toUid");
  if (toUid === uid) {
    throw new HttpsError("invalid-argument", "You are already the Owner.");
  }

  return withStructuredLogs(
    {op: "offerOwnership", uid, args: {eventId, toUid}},
    async () => {
      const eventRef = db.collection("events").doc(eventId);
      await db.runTransaction(async (tx) => {
        const eventData = await readEvent(tx, eventRef);
        const mine = await readPermissions(tx, eventRef, eventData, uid);
        if (!mine.includes("event.transfer")) {
          throw new HttpsError(
            "permission-denied",
            "Only the Owner can hand ownership on."
          );
        }
        if (!(eventData.memberIds ?? []).includes(toUid)) {
          throw new HttpsError(
            "failed-precondition",
            "The new owner must be in the event."
          );
        }
        tx.set(offerRef(eventRef), {
          from: uid,
          to: toUid,
          createdAt: FieldValue.serverTimestamp(),
        });
      });
      return {success: true};
    }
  );
});

/**
 * acceptOwnership — the person offered becomes the Owner, and the old owner
 * becomes a Co-owner, in one transaction, so an event always has exactly one
 * Owner. `creatorId` and `organizerId` move with ownership, and the old arrays
 * stay in step. Giving it back is another offer the same way.
 */
export const acceptOwnership = onCall({timeoutSeconds: 30}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const uid = request.auth.uid;
  const data = (request.data ?? {}) as Record<string, unknown>;
  const eventId = requireString(data.eventId, "eventId");

  return withStructuredLogs(
    {op: "acceptOwnership", uid, args: {eventId}},
    async () => {
      const eventRef = db.collection("events").doc(eventId);
      const before = await offerRef(eventRef).get();
      if (before.exists && before.data()!.to === uid) {
        // Outside the transaction, and safe to repeat: the new owner needs a
        // personal organizer if the event's organizer moves to them.
        await ensurePersonalOrganizer(db, uid);
      }
      await db.runTransaction(async (tx) => {
        const eventData = await readEvent(tx, eventRef);
        const offerDoc = await tx.get(offerRef(eventRef));
        if (!offerDoc.exists) {
          throw new HttpsError(
            "failed-precondition",
            "There is no ownership offer to accept."
          );
        }
        const offer = offerDoc.data()!;
        if (offer.to !== uid) {
          throw new HttpsError(
            "permission-denied",
            "Only the person offered ownership can accept it."
          );
        }
        const memberIds: string[] = eventData.memberIds ?? [];
        const fromRoles = await readRoleIds(tx, eventRef, eventData, offer.from);
        if (!memberIds.includes(uid) || !fromRoles.includes("owner")) {
          throw new HttpsError(
            "failed-precondition",
            "This offer is no longer valid. Ask the Owner for a new one."
          );
        }
        const writeNew = await prepareRoleChange(
          tx,
          eventRef,
          eventData,
          uid,
          (ids) => [
            ...ids.filter((r) => !["owner", "coOwner", "admin", "participant"].includes(r)),
            "owner",
          ]
        );
        const writeOld = await prepareRoleChange(
          tx,
          eventRef,
          eventData,
          offer.from,
          (ids) => [...ids.filter((r) => r !== "owner" && r !== "coOwner"), "coOwner"]
        );

        // ── writes ──
        writeNew();
        writeOld();
        tx.update(eventRef, {
          creatorId: uid,
          ...(eventData.organizerId === offer.from ? {organizerId: uid} : {}),
          adminIds: FieldValue.arrayUnion(uid, offer.from),
          updatedAt: FieldValue.serverTimestamp(),
        });
        tx.delete(offerDoc.ref);
      });
      return {success: true};
    }
  );
});

/**
 * cancelOwnershipOffer — the Owner withdraws the offer, or the person offered
 * declines it. Cancelling when there is none does nothing.
 */
export const cancelOwnershipOffer = onCall(
  {timeoutSeconds: 30},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }
    const uid = request.auth.uid;
    const data = (request.data ?? {}) as Record<string, unknown>;
    const eventId = requireString(data.eventId, "eventId");

    return withStructuredLogs(
      {op: "cancelOwnershipOffer", uid, args: {eventId}},
      async () => {
        const eventRef = db.collection("events").doc(eventId);
        await db.runTransaction(async (tx) => {
          const offerDoc = await tx.get(offerRef(eventRef));
          if (!offerDoc.exists) return;
          const offer = offerDoc.data()!;
          if (offer.from !== uid && offer.to !== uid) {
            throw new HttpsError(
              "permission-denied",
              "Only the Owner or the person offered can cancel this."
            );
          }
          tx.delete(offerDoc.ref);
        });
        return {success: true};
      }
    );
  }
);
