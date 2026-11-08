import {onCall, HttpsError} from "firebase-functions/v2/https";
import {expenseAccessOf} from "./expenseAccess";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {requireString, withStructuredLogs} from "../utils/logging";
import {commitInChunks} from "../utils/batch";
import {assertNotArchived} from "./eventStatus";
import {memberDoc, memberRef, readEventRoles, readPermissions} from "./members";
import {legacyRoleIds} from "./permissions";

const db = getFirestore();

const MAX_NAME = 60;
const MAX_MEMBERS = 500;
const ID_PATTERN = /^[A-Za-z0-9_-]{1,40}$/;

function requireCrewId(value: unknown): string {
  const crewId = requireString(value, "crewId");
  if (!ID_PATTERN.test(crewId)) {
    throw new HttpsError("invalid-argument", "crewId is not valid.");
  }
  return crewId;
}

/** Reads the event and refuses unless the caller holds `members.manage`. */
async function openForCrews(
  tx: FirebaseFirestore.Transaction,
  eventRef: FirebaseFirestore.DocumentReference,
  uid: string
): Promise<FirebaseFirestore.DocumentData> {
  const eventDoc = await tx.get(eventRef);
  if (!eventDoc.exists) {
    throw new HttpsError("not-found", "Event not found.");
  }
  const eventData = eventDoc.data()!;
  assertNotArchived(eventData);
  const mine = await readPermissions(tx, eventRef, eventData, uid);
  if (!mine.includes("members.manage")) {
    throw new HttpsError(
      "permission-denied",
      "Only people who manage members can change crews."
    );
  }
  return eventData;
}

/**
 * saveCrew — creates a crew, or renames one (Req 33). Needs `members.manage`.
 */
export const saveCrew = onCall({timeoutSeconds: 30}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const uid = request.auth.uid;
  const data = (request.data ?? {}) as Record<string, unknown>;
  const eventId = requireString(data.eventId, "eventId");
  const crewId = requireCrewId(data.crewId);
  const name = requireString(data.name, "name").trim();
  if (name.length === 0 || name.length > MAX_NAME) {
    throw new HttpsError(
      "invalid-argument",
      `A crew name needs 1 to ${MAX_NAME} characters.`
    );
  }

  return withStructuredLogs(
    {op: "saveCrew", uid, args: {eventId, crewId}},
    async () => {
      const eventRef = db.collection("events").doc(eventId);
      await db.runTransaction(async (tx) => {
        await openForCrews(tx, eventRef, uid);
        const ref = eventRef.collection("crews").doc(crewId);
        const existing = await tx.get(ref);
        tx.set(
          ref,
          {
            name,
            updatedAt: FieldValue.serverTimestamp(),
            ...(existing.exists ?
              {} :
              {createdAt: FieldValue.serverTimestamp(), createdBy: uid}),
          },
          {merge: true}
        );
      });
      return {success: true};
    }
  );
});

/**
 * setCrewMembers — sets exactly who is in a crew, adding or removing it from
 * `crewIds` on each member document (Req 25, 33). Other crews, roles and
 * permissions are kept. Needs `members.manage`.
 */
export const setCrewMembers = onCall({timeoutSeconds: 60}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const uid = request.auth.uid;
  const data = (request.data ?? {}) as Record<string, unknown>;
  const eventId = requireString(data.eventId, "eventId");
  const crewId = requireCrewId(data.crewId);
  const uids = data.uids;
  const valid =
    Array.isArray(uids) &&
    uids.length <= MAX_MEMBERS &&
    uids.every((u) => typeof u === "string" && u.length > 0) &&
    new Set(uids).size === uids.length;
  if (!valid) {
    throw new HttpsError(
      "invalid-argument",
      "uids must be a list of different people."
    );
  }
  const wanted = new Set(uids as string[]);

  return withStructuredLogs(
    {op: "setCrewMembers", uid, args: {eventId, crewId, count: wanted.size}},
    async () => {
      const eventRef = db.collection("events").doc(eventId);
      await db.runTransaction(async (tx) => {
        const eventData = await openForCrews(tx, eventRef, uid);
        const crewDoc = await tx.get(eventRef.collection("crews").doc(crewId));
        if (!crewDoc.exists) {
          throw new HttpsError("not-found", "This crew no longer exists.");
        }
        const memberIds: string[] = eventData.memberIds ?? [];
        if ([...wanted].some((u) => !memberIds.includes(u))) {
          throw new HttpsError(
            "failed-precondition",
            "Everyone in a crew must be a member of the event."
          );
        }
        const [current, roles] = await Promise.all([
          tx.get(
            eventRef.collection("members").where("crewIds", "array-contains", crewId)
          ),
          readEventRoles(tx, eventRef),
        ]);
        const inCrew = new Set(current.docs.map((d) => d.id));
        const toAdd = [...wanted].filter((u) => !inCrew.has(u));
        const toRemove = [...inCrew].filter((u) => !wanted.has(u));
        const added = await Promise.all(
          toAdd.map((u) => tx.get(memberRef(eventRef, u)))
        );

        // ── writes ──
        added.forEach((doc, i) => {
          const target = toAdd[i];
          if (doc.exists) {
            tx.update(doc.ref, {crewIds: FieldValue.arrayUnion(crewId)});
          } else {
            // An event not yet migrated: write the member document now.
            tx.set(
              doc.ref,
              memberDoc(
                target,
                {roleIds: legacyRoleIds(eventData, target), crewIds: [crewId]},
                roles,
                expenseAccessOf(eventData)
              )
            );
          }
        });
        toRemove.forEach((u) =>
          tx.update(memberRef(eventRef, u), {
            crewIds: FieldValue.arrayRemove(crewId),
          })
        );
      });
      return {success: true};
    }
  );
});

/**
 * deleteCrew — deletes a crew, takes it off everyone in it, and clears it
 * from its tasks, which stay. Needs `members.manage`. Safe to retry.
 */
export const deleteCrew = onCall({timeoutSeconds: 120}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const uid = request.auth.uid;
  const data = (request.data ?? {}) as Record<string, unknown>;
  const eventId = requireString(data.eventId, "eventId");
  const crewId = requireCrewId(data.crewId);

  return withStructuredLogs(
    {op: "deleteCrew", uid, args: {eventId, crewId}},
    async () => {
      const eventRef = db.collection("events").doc(eventId);
      await db.runTransaction(async (tx) => {
        await openForCrews(tx, eventRef, uid);
        const members = await tx.get(
          eventRef.collection("members").where("crewIds", "array-contains", crewId)
        );
        tx.delete(eventRef.collection("crews").doc(crewId));
        members.docs.forEach((doc) =>
          tx.update(doc.ref, {crewIds: FieldValue.arrayRemove(crewId)})
        );
      });
      // Tasks can be many, so they are cleared after, in chunks. A retry
      // finishes the job, and rules let a task keep a crew ID it already has.
      const tasks = await eventRef
        .collection("tasks")
        .where("crewId", "==", crewId)
        .get();
      await commitInChunks(
        tasks.docs.map((doc) => ({
          type: "update" as const,
          ref: doc.ref,
          data: {crewId: null},
        }))
      );
      return {success: true};
    }
  );
});
