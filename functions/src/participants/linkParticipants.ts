import {onCall, HttpsError} from "firebase-functions/v2/https";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {requireString, withStructuredLogs} from "../utils/logging";
import {expenseAccessOf} from "../events/expenseAccess";
import {memberDoc, memberRef, readEventRoles, readPermissions, rebuildMember} from "../events/members";
import {legacyRoleIds} from "../events/permissions";
import {decideLinks, MatchRecord} from "./linking";
import {emailMatchKey, phoneMatchKey} from "./matchKeys";
import {normalisePhone} from "./phone";

const db = () => getFirestore();

/**
 * Who is being linked: a signed-in account with its verified email, its
 * verified phone in E.164 (Spec #233 Req 13), or both.
 */
interface Account {
  uid: string;
  email: string | null;
  phone: string | null;
  name: string | null;
}

/** Why an event could not take the link now, or null once it is linked. */
type Refusal = "gone" | "closed" | "draft" | "full" | "taken" | "child";

/**
 * Links [account] in one event (Req 46): to a participant record, which also
 * makes them a linked adult of that record's group, or, when an organizer
 * picks a group because only children matched, to the group alone. Someone
 * new to the event becomes a member with the Participant role; anyone already
 * in it keeps their roles. Their access grows by their own group only.
 *
 * An unnamed entry left by a deleted account (Req 14a) takes the account's
 * name, email and phone back, and its match key goes.
 */
export async function linkInEvent(
  eventId: string,
  account: Account,
  target: {participantId?: string; groupId?: string}
): Promise<Refusal | null> {
  const eventRef = db().collection("events").doc(eventId);
  return db().runTransaction(async (tx) => {
    const eventDoc = await tx.get(eventRef);
    if (!eventDoc.exists) return "gone";
    const event = eventDoc.data()!;
    if (["ended", "archived"].includes(event.status)) return "closed";
    const personRef = target.participantId ?
      eventRef.collection("participants").doc(target.participantId) :
      null;
    const [memberSnap, personSnap, roles] = await Promise.all([
      tx.get(memberRef(eventRef, account.uid)),
      personRef ? tx.get(personRef) : Promise.resolve(null),
      readEventRoles(tx, eventRef),
    ]);
    const memberIds: string[] = event.memberIds ?? [];
    const isMember = memberSnap.exists || memberIds.includes(account.uid);
    // Plain members are never in a draft, because lists cannot hide it.
    if (!isMember && event.status === "draft") return "draft";
    const limit = event.memberLimit;
    if (!isMember && Number.isInteger(limit) && limit > 0 && memberIds.length >= limit) {
      return "full";
    }
    const person = personSnap?.data();
    if (personSnap && !person) return "gone";
    if (person && person.isChild === true) return "child";
    if (person && person.uid && person.uid !== account.uid) return "taken";

    const groupId: string | null = person ? person.groupId ?? null : target.groupId ?? null;
    const groupRef = groupId ? eventRef.collection("groups").doc(groupId) : null;
    const groupSnap = groupRef ? await tx.get(groupRef) : null;
    const keyRef = personRef ? eventRef.collection("participantKeys").doc(personRef.id) : null;

    const now = FieldValue.serverTimestamp();
    const current: FirebaseFirestore.DocumentData = memberSnap.exists ?
      memberSnap.data()! :
      {roleIds: isMember ? legacyRoleIds(event, account.uid) : ["participant"]};
    const before: string[] = Array.isArray(current.groupIds) ? current.groupIds : [];
    const groupIds = groupSnap?.exists ? [...new Set([...before, groupId!])] : before;
    const fields = {
      ...current,
      participantId: personRef?.id ?? current.participantId ?? null,
      groupIds,
      editsOwnGroup: groupIds.length > 0,
    };
    const access = expenseAccessOf(event);
    tx.set(
      memberRef(eventRef, account.uid),
      memberSnap.exists ?
        rebuildMember(account.uid, fields, roles, access) :
        memberDoc(account.uid, {
          roleIds: current.roleIds,
          participantId: fields.participantId,
          groupIds,
          editsOwnGroup: fields.editsOwnGroup,
        }, roles, access)
    );
    if (!isMember) {
      tx.update(eventRef, {
        memberIds: FieldValue.arrayUnion(account.uid),
        memberCount: memberIds.length + 1,
        updatedAt: now,
      });
    }
    if (groupSnap?.exists) {
      tx.update(groupRef!, {adultUids: FieldValue.arrayUnion(account.uid), updatedAt: now});
    }
    if (personRef && person) {
      const update: Record<string, unknown> = {uid: account.uid, updatedAt: now};
      if (person.anonymised === true) {
        update.anonymised = FieldValue.delete();
        if (account.name) {
          update.name = account.name;
          update.sortName = account.name.toLowerCase();
        }
        tx.set(personRef.collection("private").doc("details"), {
          ...(account.email ? {email: account.email} : {}),
          ...(account.phone ? {phone: account.phone} : {}),
          updatedAt: now,
        }, {merge: true});
      }
      tx.update(personRef, update);
      tx.delete(keyRef!);
    }
    tx.delete(eventRef.collection("linkRequests").doc(account.uid));
    return null;
  });
}

/**
 * Hands an ambiguous match to the event's organizers, unless they already
 * said it is not a match. Returns whether a request is open.
 */
async function askOrganizer(
  eventId: string,
  account: Account,
  participantIds: string[],
  groupIds: string[]
): Promise<boolean> {
  const eventRef = db().collection("events").doc(eventId);
  const ref = eventRef.collection("linkRequests").doc(account.uid);
  return db().runTransaction(async (tx) => {
    const [eventDoc, existing] = await Promise.all([tx.get(eventRef), tx.get(ref)]);
    const status = eventDoc.data()?.status;
    if (!eventDoc.exists || ["draft", "ended", "archived"].includes(status)) return false;
    if (existing.data()?.status === "dismissed") return false;
    tx.set(ref, {
      uid: account.uid,
      name: account.name,
      email: account.email ?? "",
      phone: account.phone,
      participantIds: [...participantIds].sort(),
      groupIds: [...groupIds].sort(),
      status: "open",
      createdAt: existing.data()?.createdAt ?? FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return true;
  });
}

/** `events/{e}/participants/{p}/private/details` → [e, p]. */
function detailsPath(path: string): [string, string] | null {
  const s = path.split("/");
  return s.length === 6 && s[0] === "events" && s[2] === "participants" &&
    s[4] === "private" && s[5] === "details" ? [s[1], s[3]] : null;
}

/**
 * Links [uid] wherever their verified email or phone matches (Req 46, Spec
 * #233 Req 13). Matches come from the email and phone in participants'
 * private details, and from the match keys of unnamed entries a deleted
 * account left behind (Req 14a).
 */
export async function linkAccount(
  uid: string,
  verified: {email: string | null; phone: string | null},
  tokenName: string | null
): Promise<{linked: string[]; asked: string[]}> {
  const {email, phone} = verified;
  const [emailKey, phoneKey] = await Promise.all([
    email ? emailMatchKey(email) : null,
    phone ? phoneMatchKey(phone) : null,
  ]);
  const none = Promise.resolve(null);
  const [byEmail, byPhone, byEmailKey, byPhoneKey, user] = await Promise.all([
    email ? db().collectionGroup("private").where("email", "==", email).get() : none,
    phone ? db().collectionGroup("private").where("phone", "==", phone).get() : none,
    emailKey ? db().collectionGroup("participantKeys").where("emailKey", "==", emailKey).get() : none,
    phoneKey ? db().collectionGroup("participantKeys").where("phoneKey", "==", phoneKey).get() : none,
    db().collection("users").doc(uid).get(),
  ]);
  // What each matched record carries, by event and participant.
  const found = new Map<string, Map<string, FirebaseFirestore.DocumentData>>();
  const add = (eventId: string, participantId: string, data: FirebaseFirestore.DocumentData) => {
    const people = found.get(eventId) ?? new Map<string, FirebaseFirestore.DocumentData>();
    people.set(participantId, {...people.get(participantId), ...data});
    found.set(eventId, people);
  };
  for (const snap of [byEmail, byPhone]) {
    snap?.docs.forEach((d) => {
      const at = detailsPath(d.ref.path);
      if (at) add(...at, {email: d.data().email ?? null, phone: d.data().phone ?? null});
    });
  }
  for (const snap of [byEmailKey, byPhoneKey]) {
    snap?.docs.forEach((d) => add(d.ref.parent.parent!.id, d.id,
      {emailKey: d.data().emailKey ?? null, phoneKey: d.data().phoneKey ?? null}));
  }

  const records: MatchRecord[] = [];
  for (const [eventId, people] of found) {
    const ref = db().collection("events").doc(eventId).collection("participants");
    const docs = await db().getAll(...[...people.keys()].map((id) => ref.doc(id)));
    for (const d of docs) {
      if (!d.exists) continue;
      records.push({
        ...people.get(d.id),
        eventId,
        participantId: d.id,
        groupId: d.data()!.groupId ?? null,
        isChild: d.data()!.isChild === true,
        linkedUid: d.data()!.uid ?? null,
        status: d.data()!.status ?? "active",
      });
    }
  }

  const displayName = (user.data()?.displayName as string | undefined)?.trim();
  const account: Account = {uid, email, phone, name: displayName || tokenName || null};
  const linked: string[] = [];
  const asked: string[] = [];
  const decisions = decideLinks(records, {email, phone, emailKey, phoneKey}, uid);
  for (const [eventId, decision] of Object.entries(decisions)) {
    if (decision.kind === "link") {
      if ((await linkInEvent(eventId, account, {participantId: decision.participantId})) === null) {
        linked.push(eventId);
      }
    } else if (decision.kind === "ask") {
      if (await askOrganizer(eventId, account, decision.participantIds, decision.groupIds)) {
        asked.push(eventId);
      }
    }
  }
  return {linked, asked};
}

/**
 * linkMyParticipants — the app calls this once a signed-in person's email is
 * verified, or they signed in with a phone code (Req 46, X-05, L-01, L-02,
 * Spec #233 Req 13). Verification is not enforced at sign-up, so an
 * unverified email links nothing. Firebase sets `phone_number` only once the
 * SMS code is entered, in E.164. Safe to repeat.
 */
export const linkMyParticipants = onCall({timeoutSeconds: 60}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const uid = request.auth.uid;
  const token = request.auth.token ?? {};
  const typed = String(token.email ?? "").trim().toLowerCase();
  const email = typed && token.email_verified === true ? typed : null;
  const phone = typeof token.phone_number === "string" ?
    normalisePhone(token.phone_number, "US") :
    null;
  if (!email && !phone) {
    return {linked: [], asked: [], unverified: true};
  }
  return withStructuredLogs({op: "linkMyParticipants", uid, args: {}}, () =>
    linkAccount(uid, {email, phone}, typeof token.name === "string" ? token.name : null));
});

/**
 * resolveLinkRequest — an organizer settles an ambiguous match (Req 46): links
 * the person to one adult record from the request, or to one of its groups
 * when only children matched, or says it is not a match, so it is not asked
 * again. Needs `participants.edit` and `participants.readPrivate`, because the
 * request shows the person's email.
 */
export const resolveLinkRequest = onCall({timeoutSeconds: 30}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const caller = request.auth.uid;
  const data = (request.data ?? {}) as Record<string, unknown>;
  const eventId = requireString(data.eventId, "eventId");
  const uid = requireString(data.uid, "uid");
  const participantId = typeof data.participantId === "string" ? data.participantId : null;
  const groupId = typeof data.groupId === "string" ? data.groupId : null;
  const dismiss = data.dismiss === true;
  if ([participantId !== null, groupId !== null, dismiss].filter(Boolean).length !== 1) {
    throw new HttpsError("invalid-argument", "Pick one record, one group, or not a match.");
  }

  return withStructuredLogs(
    {op: "resolveLinkRequest", uid: caller, args: {eventId, uid, participantId, groupId, dismiss}},
    async () => {
      const eventRef = db().collection("events").doc(eventId);
      const eventDoc = await eventRef.get();
      if (!eventDoc.exists) throw new HttpsError("not-found", "Event not found.");
      const mine = await readPermissions(null, eventRef, eventDoc.data()!, caller);
      if (!mine.includes("participants.edit") || !mine.includes("participants.readPrivate")) {
        throw new HttpsError("permission-denied", "Only organizers can link accounts.");
      }
      const ref = eventRef.collection("linkRequests").doc(uid);
      const pending = (await ref.get()).data();
      if (!pending || pending.status !== "open") {
        throw new HttpsError("not-found", "This request is no longer open.");
      }
      if (dismiss) {
        await ref.update({
          status: "dismissed", resolvedBy: caller, resolvedAt: FieldValue.serverTimestamp(),
        });
        return {success: true};
      }
      const allowed = participantId ?
        (pending.participantIds ?? []).includes(participantId) :
        (pending.groupIds ?? []).includes(groupId);
      if (!allowed) {
        throw new HttpsError("invalid-argument", "Pick from this request.");
      }
      const refused = await linkInEvent(
        eventId,
        {uid, email: pending.email || null, phone: pending.phone ?? null, name: pending.name ?? null},
        participantId ? {participantId} : {groupId: groupId!}
      );
      if (refused === "child") {
        throw new HttpsError("invalid-argument", "A child is never linked to an account.");
      }
      if (refused) {
        throw new HttpsError("failed-precondition", `This link cannot be made now (${refused}).`);
      }
      return {success: true};
    }
  );
});
