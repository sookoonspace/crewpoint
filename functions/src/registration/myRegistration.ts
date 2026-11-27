import {onCall, HttpsError} from "firebase-functions/v2/https";
import {Timestamp, getFirestore} from "firebase-admin/firestore";
import {withStructuredLogs} from "../utils/logging";
import {registrationOf} from "./registrationSettings";
import {eventBySlug, waiverList} from "./registrationForm";
import {LocalText} from "./settings";

const millis = (v: unknown): number | null => (v instanceof Timestamp ? v.toMillis() : null);

/**
 * The after-registration note a registration in [status] sees (Spec #233
 * Req 19; B-07, B-15): only `submitted` ones, and from `laterNoteFrom` the
 * replacement note when there is one.
 */
export function noteFor(
  status: string | null,
  settings: {afterNote: LocalText | null; laterNote: LocalText | null; laterNoteFrom: number | null},
  now = Date.now()
): LocalText | null {
  if (status !== "submitted") return null;
  if (settings.laterNote && settings.laterNoteFrom !== null && now >= settings.laterNoteFrom) {
    return settings.laterNote;
  }
  return settings.afterNote;
}

/**
 * getMyRegistration — "my registration" (`/e/:eventSlug/registration`;
 * Spec #233 Req 9, 19, 35; #242) for the signed-in contact or a linked
 * adult of the group, by the event's link name: its status and waitlist
 * number, the group's name and people (name and category only), and the
 * after-registration note for submitted groups. Still shown after the
 * deadline. Never the event's ID. Anyone else gets `registration: null`.
 */
export const getMyRegistration = onCall({timeoutSeconds: 30}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Must be signed in.");
  const data = (request.data ?? {}) as {slug?: unknown};
  return withStructuredLogs({op: "getMyRegistration", uid, args: {slug: data.slug}}, async () => {
    const {slug, ref} = await eventBySlug(data.slug);
    const [eventDoc, asContact, member] = await Promise.all([
      ref.get(),
      ref.collection("registrations").where("contactUid", "==", uid).limit(1).get(),
      ref.collection("members").doc(uid).get(),
    ]);
    if (!eventDoc.exists) throw new HttpsError("not-found", "We couldn't find this event.");
    const event = eventDoc.data()!;
    const settings = registrationOf(event);
    if (settings.slug !== slug) throw new HttpsError("not-found", "We couldn't find this event.");

    // A draft (#243) is not sent yet: the form restores it.
    let found = asContact.docs.find((d) => d.data().status !== "draft");
    const groupIds: string[] = Array.isArray(member.data()?.groupIds) ? member.data()!.groupIds.slice(0, 10) : [];
    if (!found && groupIds.length > 0) {
      const asAdult = await ref.collection("registrations").where("groupId", "in", groupIds).limit(1).get();
      found = asAdult.docs[0];
    }
    const base = {
      title: String(event.title ?? ""),
      timeZone: typeof event.timeZone === "string" ? event.timeZone : "UTC",
      startDate: millis(event.startDate),
      endDate: millis(event.endDate),
      dateOnly: event.dateOnly === true,
      deadline: settings.deadline,
      labels: event.labels ?? {},
    };
    if (!found) return {...base, registration: null, note: null};

    const r = found.data();
    const [group, people] = await Promise.all([
      ref.collection("groups").doc(String(r.groupId)).get(),
      ref.collection("participants").where("registrationId", "==", found.id).get(),
    ]);
    const sorted = people.docs
      .map((d) => ({id: d.id, ...d.data()}) as FirebaseFirestore.DocumentData)
      .sort((a, b) => millis(a.createdAt)! - millis(b.createdAt)! || String(a.name).localeCompare(String(b.name)));
    return {
      ...base,
      registration: {
        status: r.status,
        waitlistPosition: r.waitlistPosition ?? null,
        submittedAt: millis(r.submittedAt),
        // An open waitlist offer (#248): until when the places are held.
        offerExpiresAt: r.status === "waitlisted" && typeof r.offer?.expiresAt === "number" ?
          r.offer.expiresAt : null,
        groupName: String(group.data()?.name ?? ""),
        // Each person's missing waivers (#246, W-06), to accept here.
        people: sorted.map((p) => ({
          id: p.id, name: String(p.name ?? ""), categoryId: p.categoryId ?? null, isChild: p.isChild === true,
          missingWaivers: p.registrationStatus === "cancelled" ? [] : p.missingWaivers ?? [],
        })),
      },
      waivers: settings.blocks.waivers ? await waiverList(ref) : [],
      note: noteFor(r.status, settings),
    };
  });
});

/**
 * getMyWaitingRegistrations — the caller's registrations that are not
 * confirmed yet (#292): `waitlisted` (with the number and any open
 * offer's expiry) or `pending`, as their contact, for home, since they are
 * not members of those events yet and "My events" lists only those. Each
 * gives the event's ID (to leave out events home already lists), link
 * name, title and dates; ended and archived events are left out.
 */
export const getMyWaitingRegistrations = onCall({timeoutSeconds: 30}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Must be signed in.");
  return withStructuredLogs({op: "getMyWaitingRegistrations", uid, args: {}}, async () => {
    const mine = await getFirestore().collectionGroup("registrations").where("contactUid", "==", uid).get();
    const waiting = mine.docs.filter((d) => ["waitlisted", "pending"].includes(d.data().status));
    const events = waiting.length === 0 ? [] :
      await getFirestore().getAll(...waiting.map((d) => d.ref.parent.parent!));
    const out = [];
    for (const [i, d] of waiting.entries()) {
      const event = events[i].data();
      if (!event || ["ended", "archived"].includes(String(event.status))) continue;
      const slug = registrationOf(event).slug;
      if (!slug) continue;
      const r = d.data();
      out.push({
        eventId: events[i].id,
        slug,
        title: String(event.title ?? ""),
        startDate: millis(event.startDate),
        endDate: millis(event.endDate),
        dateOnly: event.dateOnly === true,
        timeZone: typeof event.timeZone === "string" ? event.timeZone : "UTC",
        status: r.status,
        waitlistPosition: r.waitlistPosition ?? null,
        offerExpiresAt: r.status === "waitlisted" && typeof r.offer?.expiresAt === "number" ? r.offer.expiresAt : null,
      });
    }
    out.sort((a, b) => (a.startDate ?? Number.MAX_SAFE_INTEGER) - (b.startDate ?? Number.MAX_SAFE_INTEGER));
    return {registrations: out};
  });
});
