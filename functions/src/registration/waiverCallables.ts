import {onCall, HttpsError} from "firebase-functions/v2/https";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {withStructuredLogs} from "../utils/logging";
import {enqueueEmail, normaliseEmail} from "../mail/outbox";
import {hostingDomain} from "../account/signInLink";
import {requirePermission} from "../events/members";
import {registrationOf} from "./registrationSettings";
import {eventBySlug} from "./registrationForm";
import {WaiverAppliesTo} from "./waivers";
import {
  acceptanceWrites, acceptedAs, acceptedOf, loadWaivers, missingFor, waiverFields, WaiverDoc,
} from "./waiverAcceptance";

const db = () => getFirestore();

type LocalText = {en: string; gu?: string};

function readText(raw: unknown, name: string, max: number): LocalText {
  const r = raw && typeof raw === "object" ? raw as Record<string, unknown> : {};
  const en = typeof r.en === "string" ? r.en.trim() : "";
  const gu = typeof r.gu === "string" ? r.gu.trim() : "";
  if (!en || en.length > max || gu.length > max) {
    throw new HttpsError("invalid-argument", `Please check the ${name}.`, {reason: "invalid", problems: [name]});
  }
  return gu ? {en, gu} : {en};
}

function sameText(a: LocalText | undefined, b: LocalText): boolean {
  return a?.en === b.en && (a?.gu ?? "") === (b.gu ?? "");
}

/**
 * The missing list (`missingWaivers`, `waiversMissing`) of every registered
 * person, worked out again after a waiver changes; only changed records are
 * written. Cancelled people miss nothing.
 */
async function refreshMissing(eventRef: FirebaseFirestore.DocumentReference): Promise<void> {
  const [event, all, people] = await Promise.all([
    eventRef.get(),
    loadWaivers(eventRef),
    eventRef.collection("participants").where("registrationId", "!=", null).get(),
  ]);
  const waivers = registrationOf(event.data() ?? {}).blocks.waivers ? all : [];
  let batch = db().batch();
  let n = 0;
  for (const d of people.docs) {
    const p = d.data();
    const missing = p.registrationStatus === "cancelled" ? [] : missingFor(
      {categoryId: p.categoryId ?? null, signUps: p.signUps ?? []}, waivers, acceptedOf(p));
    const before: string[] = p.missingWaivers ?? [];
    if (before.length === missing.length && before.every((id, i) => id === missing[i])) continue;
    batch.update(d.ref, {missingWaivers: missing, waiversMissing: missing.length > 0});
    if (++n % 400 === 0) {
      await batch.commit();
      batch = db().batch();
    }
  }
  if (n % 400 !== 0) await batch.commit();
}

/**
 * saveWaiver — adds or changes a waiver (Spec #233 Req 26, 28; #246), with
 * `event.manage`. A waiver has a title and text (English, optional
 * Gujarati), an `appliesTo` (everyone, a category, or people signed up for
 * a session), `required` (to register) and `requireLatest` (whether people
 * who accepted an earlier version must accept again). A changed title or
 * text makes a new version, kept in `versions/{n}`; settings alone do not.
 * Every registered person's missing list is then worked out again.
 */
export const saveWaiver = onCall({timeoutSeconds: 120}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Must be signed in.");
  const data = (request.data ?? {}) as Record<string, unknown>;
  const eventId = typeof data.eventId === "string" ? data.eventId : "";
  if (!eventId) throw new HttpsError("invalid-argument", "eventId is required.");

  return withStructuredLogs({op: "saveWaiver", uid, args: {eventId}}, async () => {
    const eventRef = db().collection("events").doc(eventId);
    const title = readText(data.title, "title", 200);
    const text = readText(data.text, "text", 20000);
    const appliesTo = data.appliesTo as WaiverAppliesTo | undefined;

    const result = await db().runTransaction(async (tx) => {
      const eventDoc = await tx.get(eventRef);
      if (!eventDoc.exists) throw new HttpsError("not-found", "We couldn't find this event.");
      const event = eventDoc.data()!;
      await requirePermission(tx, eventRef, event, uid, "event.manage",
        "You don't have permission to change this event.");
      if (event.status === "archived") throw new HttpsError("failed-precondition", "This event is archived.");

      const kind = appliesTo?.kind;
      const id = (appliesTo as {id?: unknown} | undefined)?.id;
      if (kind === "category") {
        const categories: Array<{id?: string}> = event.settings?.categories ?? [];
        if (typeof id !== "string" || !categories.some((c) => c.id === id)) {
          throw new HttpsError("invalid-argument", "Please choose who it applies to.", {reason: "invalid", problems: ["appliesTo"]});
        }
      } else if (kind === "session") {
        const session = typeof id === "string" && id ? await tx.get(eventRef.collection("sessions").doc(id)) : null;
        if (!session?.exists) {
          throw new HttpsError("invalid-argument", "Please choose who it applies to.", {reason: "invalid", problems: ["appliesTo"]});
        }
      } else if (kind !== "everyone") {
        throw new HttpsError("invalid-argument", "Please choose who it applies to.", {reason: "invalid", problems: ["appliesTo"]});
      }
      const applies: WaiverAppliesTo = kind === "everyone" ? {kind} : {kind, id: id as string};

      const waiverId = typeof data.waiverId === "string" && data.waiverId ? data.waiverId : null;
      const ref = waiverId ? eventRef.collection("waivers").doc(waiverId) : eventRef.collection("waivers").doc();
      const current = waiverId ? await tx.get(ref) : null;
      if (waiverId && !current?.exists) throw new HttpsError("not-found", "We couldn't find this waiver.");
      const before = current?.data();
      const changedText = !before || !sameText(before.title, title) || !sameText(before.text, text);
      const version = !before ? 1 : changedText ? (before.version ?? 1) + 1 : before.version ?? 1;
      const now = FieldValue.serverTimestamp();
      tx.set(ref, {
        title, text, version, appliesTo: applies,
        required: data.required === true, requireLatest: data.requireLatest !== false,
        updatedAt: now, updatedBy: uid, ...(before ? {} : {createdAt: now}),
      });
      if (changedText) {
        tx.set(ref.collection("versions").doc(String(version)), {title, text, savedAt: now, savedBy: uid});
      }
      return {waiverId: ref.id, version};
    });
    await refreshMissing(eventRef);
    return result;
  });
});

/**
 * acceptWaivers — accepts waivers for people in the caller's registration
 * (Req 27, 29; #246, W-06), at any time, including after the deadline: by
 * the contact or a linked adult of the person's group, as the person, as
 * guardian of a child, or on behalf of another adult. Each acceptance is
 * written once at the waiver's current version and never edited.
 */
export const acceptWaivers = onCall({timeoutSeconds: 60}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Must be signed in.");
  const data = (request.data ?? {}) as {slug?: unknown; acceptances?: unknown};
  const list = Array.isArray(data.acceptances) ? data.acceptances.slice(0, 500) : [];
  const wanted = new Map<string, string[]>();
  for (const a of list) {
    const r = a && typeof a === "object" ? a as Record<string, unknown> : {};
    if (typeof r.participantId !== "string" || typeof r.waiverId !== "string") {
      throw new HttpsError("invalid-argument", "Some answers need checking.", {reason: "invalid"});
    }
    wanted.set(r.participantId, [...(wanted.get(r.participantId) ?? []), r.waiverId]);
  }

  return withStructuredLogs({op: "acceptWaivers", uid, args: {slug: data.slug, count: list.length}}, async () => {
    const {ref: eventRef} = await eventBySlug(data.slug);
    const all = await loadWaivers(eventRef);
    return db().runTransaction(async (tx) => {
      const event = (await tx.get(eventRef)).data() ?? {};
      if (event.status === "archived") throw new HttpsError("failed-precondition", "This event is archived.");
      const waivers: WaiverDoc[] = registrationOf(event).blocks.waivers ? all : [];
      const refs = [...wanted.keys()].map((id) => eventRef.collection("participants").doc(id));
      const people = refs.length ? await tx.getAll(...refs) : [];
      const groupIds = [...new Set(people.map((p) => p.data()?.groupId).filter((g): g is string => typeof g === "string"))];
      const groups = groupIds.length ?
        await tx.getAll(...groupIds.map((g) => eventRef.collection("groups").doc(g))) : [];
      const adultsOf = new Map(groups.map((g) => [g.id, (g.data()?.adultUids ?? []) as string[]]));
      for (const p of people) {
        const d = p.data();
        if (!d || !d.registrationId || !(adultsOf.get(d.groupId) ?? []).includes(uid)) {
          throw new HttpsError("permission-denied", "You can accept waivers only for people in your registration.");
        }
        if (d.registrationStatus === "cancelled") {
          throw new HttpsError("failed-precondition", "This registration is cancelled.", {reason: "closed"});
        }
      }
      let accepted = 0;
      for (const p of people) {
        const d = p.data()!;
        const {entries, missing} = acceptanceWrites({
          accepting: wanted.get(p.id) ?? [], accepted: acceptedOf(d), waivers,
          person: {categoryId: d.categoryId ?? null, signUps: d.signUps ?? []},
          by: uid, as: acceptedAs({isChild: d.isChild === true, uid: d.uid ?? null}, uid),
        });
        accepted += Object.keys(entries).length;
        if (Object.keys(entries).length > 0) {
          tx.set(p.ref.collection("private").doc("waivers"), {accepted: entries}, {merge: true});
        }
        tx.update(p.ref, {...waiverFields(acceptedOf(d), entries, missing), updatedAt: FieldValue.serverTimestamp()});
      }
      return {accepted};
    });
  });
});

/**
 * sendWaiverReminders — emails each registration with someone missing a
 * waiver (Spec #233 Req 52, 65; #246, W-05), sent by hand with
 * `registrations.manage` from the Missing waiver list. The email names the
 * people and links to the registration; it goes to the contact's address.
 */
export const sendWaiverReminders = onCall({timeoutSeconds: 300}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Must be signed in.");
  const data = (request.data ?? {}) as Record<string, unknown>;
  const eventId = typeof data.eventId === "string" ? data.eventId : "";
  if (!eventId) throw new HttpsError("invalid-argument", "eventId is required.");

  return withStructuredLogs({op: "sendWaiverReminders", uid, args: {eventId}}, async () => {
    const eventRef = db().collection("events").doc(eventId);
    const eventDoc = await eventRef.get();
    if (!eventDoc.exists) throw new HttpsError("not-found", "We couldn't find this event.");
    const event = eventDoc.data()!;
    await requirePermission(null, eventRef, event, uid, "registrations.manage",
      "You don't have permission to manage registrations.");
    const slug = registrationOf(event).slug;

    const missing = await eventRef.collection("participants").where("waiversMissing", "==", true).get();
    const byRegistration = new Map<string, string[]>();
    for (const d of missing.docs) {
      const p = d.data();
      if (!p.registrationId || p.registrationStatus === "cancelled") continue;
      byRegistration.set(p.registrationId, [...(byRegistration.get(p.registrationId) ?? []), String(p.name ?? "")]);
    }
    let sent = 0;
    for (const [registrationId, names] of byRegistration) {
      const reg = (await eventRef.collection("registrations").doc(registrationId).get()).data();
      if (!reg?.contactUid) continue;
      const contact = await eventRef.collection("participants")
        .where("registrationId", "==", registrationId).where("uid", "==", reg.contactUid).limit(1).get();
      const details = contact.docs[0] ?
        (await contact.docs[0].ref.collection("private").doc("details").get()).data() : undefined;
      const to = normaliseEmail(details?.email);
      if (!to) continue;
      await enqueueEmail(db(), {
        to, uid: reg.contactUid, template: "waiverMissing", eventId,
        data: {
          eventTitle: String(event.title ?? ""),
          people: names.sort().map((n) => `• ${n}`).join("\n"),
          link: `https://${hostingDomain()}/e/${slug}/registration`,
        },
      });
      sent++;
    }
    return {sent};
  });
});
