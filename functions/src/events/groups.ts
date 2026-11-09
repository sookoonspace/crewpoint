import {onCall, HttpsError} from "firebase-functions/v2/https";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {requireString, withStructuredLogs} from "../utils/logging";
import {assertNotArchived} from "./eventStatus";
import {expenseAccessOf} from "./expenseAccess";
import {memberRef, readEventRoles, readPermissions, rebuildMember} from "./members";

const db = getFirestore();

/** Matches the participant name limit in `firestore.rules`. */
const MAX_NAME = 120;
const MAX_ADULTS = 50;
const ID_PATTERN = /^[A-Za-z0-9_-]{1,40}$/;

function requireGroupId(value: unknown): string {
  const groupId = requireString(value, "groupId");
  if (!ID_PATTERN.test(groupId)) {
    throw new HttpsError("invalid-argument", "groupId is not valid.");
  }
  return groupId;
}

/** Reads the event and refuses unless the caller holds `participants.edit`. */
async function openForGroups(
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
  if (!mine.includes("participants.edit")) {
    throw new HttpsError(
      "permission-denied",
      "Only people who manage attendees can change groups."
    );
  }
  return eventData;
}

/**
 * Rewrites the member documents of [changes]: each uid's new `groupIds`, with
 * `group.editOwn` granted while they are in any group (Req 26b). Reads come
 * first, so this runs inside the caller's transaction before its writes.
 */
async function prepareGroupLinks(
  tx: FirebaseFirestore.Transaction,
  eventRef: FirebaseFirestore.DocumentReference,
  eventData: FirebaseFirestore.DocumentData,
  changes: Map<string, (groupIds: string[]) => string[]>
): Promise<() => void> {
  const uids = [...changes.keys()];
  const [roles, ...docs] = await Promise.all([
    readEventRoles(tx, eventRef),
    ...uids.map((u) => tx.get(memberRef(eventRef, u))),
  ]);
  const access = expenseAccessOf(eventData);
  return () => {
    docs.forEach((doc, i) => {
      if (!doc.exists) return;
      const current = doc.data()!;
      const before: string[] = Array.isArray(current.groupIds) ? current.groupIds : [];
      const groupIds = changes.get(uids[i])!(before);
      tx.set(
        doc.ref,
        rebuildMember(
          doc.id,
          {...current, groupIds, editsOwnGroup: groupIds.length > 0},
          roles,
          access
        )
      );
    });
  };
}

/**
 * saveGroup — creates a group of participants, such as a household, team or
 * foursome, or renames one (Req 40). Needs `participants.edit`.
 */
export const saveGroup = onCall({timeoutSeconds: 30}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const uid = request.auth.uid;
  const data = (request.data ?? {}) as Record<string, unknown>;
  const eventId = requireString(data.eventId, "eventId");
  const groupId = requireGroupId(data.groupId);
  const name = requireString(data.name, "name").trim();
  if (name.length === 0 || name.length > MAX_NAME) {
    throw new HttpsError(
      "invalid-argument",
      `A group name needs 1 to ${MAX_NAME} characters.`
    );
  }

  return withStructuredLogs(
    {op: "saveGroup", uid, args: {eventId, groupId}},
    async () => {
      const eventRef = db.collection("events").doc(eventId);
      await db.runTransaction(async (tx) => {
        await openForGroups(tx, eventRef, uid);
        const ref = eventRef.collection("groups").doc(groupId);
        const existing = await tx.get(ref);
        tx.set(
          ref,
          {
            name,
            sortName: name.toLowerCase(),
            updatedAt: FieldValue.serverTimestamp(),
            ...(existing.exists ?
              {} :
              {
                adultUids: [],
                createdAt: FieldValue.serverTimestamp(),
                createdBy: uid,
              }),
          },
          {merge: true}
        );
      });
      return {success: true};
    }
  );
});

/**
 * setGroupAdults — sets exactly which members with accounts are linked adults
 * of a group (Req 26b, 40). They can then see the group and add or edit its
 * people, including children. Needs `participants.edit`. Linking by verified
 * email arrives in #78.
 */
export const setGroupAdults = onCall({timeoutSeconds: 60}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const uid = request.auth.uid;
  const data = (request.data ?? {}) as Record<string, unknown>;
  const eventId = requireString(data.eventId, "eventId");
  const groupId = requireGroupId(data.groupId);
  const uids = data.uids;
  const valid =
    Array.isArray(uids) &&
    uids.length <= MAX_ADULTS &&
    uids.every((u) => typeof u === "string" && u.length > 0) &&
    new Set(uids).size === uids.length;
  if (!valid) {
    throw new HttpsError(
      "invalid-argument",
      `uids must be a list of up to ${MAX_ADULTS} different people.`
    );
  }
  const wanted = new Set(uids as string[]);

  return withStructuredLogs(
    {op: "setGroupAdults", uid, args: {eventId, groupId, count: wanted.size}},
    async () => {
      const eventRef = db.collection("events").doc(eventId);
      await db.runTransaction(async (tx) => {
        const eventData = await openForGroups(tx, eventRef, uid);
        const groupRef = eventRef.collection("groups").doc(groupId);
        const groupDoc = await tx.get(groupRef);
        if (!groupDoc.exists) {
          throw new HttpsError("not-found", "This group no longer exists.");
        }
        const memberIds: string[] = eventData.memberIds ?? [];
        if ([...wanted].some((u) => !memberIds.includes(u))) {
          throw new HttpsError(
            "failed-precondition",
            "Everyone linked to a group must be a member of the event."
          );
        }
        const before: string[] = groupDoc.data()!.adultUids ?? [];
        const changes = new Map<string, (ids: string[]) => string[]>();
        for (const u of wanted) {
          if (!before.includes(u)) {
            changes.set(u, (ids) => [...new Set([...ids, groupId])]);
          }
        }
        for (const u of before) {
          if (!wanted.has(u)) {
            changes.set(u, (ids) => ids.filter((g) => g !== groupId));
          }
        }
        const write = await prepareGroupLinks(tx, eventRef, eventData, changes);
        write();
        tx.update(groupRef, {
          adultUids: [...wanted],
          updatedAt: FieldValue.serverTimestamp(),
        });
      });
      return {success: true};
    }
  );
});

/**
 * deleteGroup — deletes an empty group, unlinking its adults. Refuses while
 * participants are still in it, so nobody's group is lost by accident. Safe
 * to repeat. Needs `participants.edit`.
 */
export const deleteGroup = onCall({timeoutSeconds: 30}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const uid = request.auth.uid;
  const data = (request.data ?? {}) as Record<string, unknown>;
  const eventId = requireString(data.eventId, "eventId");
  const groupId = requireGroupId(data.groupId);

  return withStructuredLogs(
    {op: "deleteGroup", uid, args: {eventId, groupId}},
    async () => {
      const eventRef = db.collection("events").doc(eventId);
      await db.runTransaction(async (tx) => {
        const eventData = await openForGroups(tx, eventRef, uid);
        const groupRef = eventRef.collection("groups").doc(groupId);
        const [groupDoc, people] = await Promise.all([
          tx.get(groupRef),
          tx.get(
            eventRef.collection("participants").where("groupId", "==", groupId).limit(1)
          ),
        ]);
        if (!groupDoc.exists) return;
        if (!people.empty) {
          throw new HttpsError(
            "failed-precondition",
            "Move or remove the people in this group first."
          );
        }
        const adults: string[] = groupDoc.data()!.adultUids ?? [];
        const changes = new Map<string, (ids: string[]) => string[]>(
          adults.map((u) => [u, (ids) => ids.filter((g) => g !== groupId)])
        );
        const write = await prepareGroupLinks(tx, eventRef, eventData, changes);
        write();
        tx.delete(groupRef.collection("private").doc("details"));
        tx.delete(groupRef);
      });
      return {success: true};
    }
  );
});
