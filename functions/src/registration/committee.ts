import {onCall, HttpsError} from "firebase-functions/v2/https";
import {AggregateField, FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";
import {getAuth} from "firebase-admin/auth";
import {withStructuredLogs} from "../utils/logging";
import {enqueueEmail, normaliseEmail} from "../mail/outbox";
import {hostingDomain} from "../account/signInLink";
import {readPermissions, requirePermission} from "../events/members";
import {registrationOf} from "./registrationSettings";
import {applyRegistrationMembership} from "./membership";
import {offerOnwardNow} from "./offers";
import {loadWaivers} from "./waiverAcceptance";

/**
 * The committee's registration tools (Spec #233 Req 4, 4a, 37, 52, 64,
 * 66; #249), all with `registrations.manage`: the Registration summary,
 * approve, waitlist and reinstate (cancelling is `cancelRegistration` by
 * `registrationId`), resending a confirmation, the closing reminder, and a
 * group's registration details. Every action works at any time, after the
 * deadline too, and going over capacity needs `confirmOverCapacity`.
 */

const db = () => getFirestore();
type Data = FirebaseFirestore.DocumentData;
type Ref = FirebaseFirestore.DocumentReference;
const millis = (v: unknown): number | null => (v instanceof Timestamp ? v.toMillis() : null);

const STATUSES = ["submitted", "pending", "waitlisted", "cancelled", "draft"] as const;

async function managed(uid: string | undefined, eventId: unknown) {
  if (!uid) throw new HttpsError("unauthenticated", "Must be signed in.");
  if (typeof eventId !== "string" || !eventId) throw new HttpsError("invalid-argument", "eventId is required.");
  const eventRef = db().collection("events").doc(eventId);
  const eventDoc = await eventRef.get();
  if (!eventDoc.exists) throw new HttpsError("not-found", "We couldn't find this event.");
  const event = eventDoc.data()!;
  const held = await requirePermission(null, eventRef, event, uid, "registrations.manage",
    "You don't have permission to manage registrations.");
  return {eventRef, event, held};
}

/**
 * getRegistrationSummary — the Registration summary (Req 64, 4a): groups
 * and people by status (drafts as groups only: they have no people yet),
 * capacity, places used and held, the deadline and the link name.
 */
export const getRegistrationSummary = onCall({timeoutSeconds: 60}, async (request) => {
  const uid = request.auth?.uid;
  return withStructuredLogs({op: "getRegistrationSummary", uid: uid ?? null, args: {eventId: request.data?.eventId}}, async () => {
    const {eventRef, event} = await managed(uid, request.data?.eventId);
    const registrations = eventRef.collection("registrations");
    // Drafts have no size yet, and a sum would leave them out of the count,
    // so they are only counted.
    const counts = await Promise.all(STATUSES.map((status) => status === "draft" ?
      registrations.where("status", "==", status).aggregate({groups: AggregateField.count()}).get() :
      registrations.where("status", "==", status)
        .aggregate({groups: AggregateField.count(), people: AggregateField.sum("size")}).get()));
    const byStatus = Object.fromEntries(STATUSES.map((status, i) => {
      const d = counts[i].data() as {groups: number; people?: number};
      return [status, {groups: d.groups, people: status === "draft" ? null : Number(d.people ?? 0)}];
    }));
    const tally = (await eventRef.collection("registrationTally").doc("current").get()).data() ?? {};
    const settings = registrationOf(event);
    return {
      byStatus,
      capacity: typeof event.capacity === "number" ? event.capacity : null,
      placesUsed: typeof tally.placesUsed === "number" ? tally.placesUsed : 0,
      held: Array.isArray(tally.offers) ? tally.offers.reduce((n: number, o: {size?: number}) => n + (o.size ?? 0), 0) : 0,
      deadline: settings.deadline,
      review: settings.review,
      slug: settings.slug,
      timeZone: typeof event.timeZone === "string" ? event.timeZone : "UTC",
    };
  });
});

type Action = "approve" | "waitlist" | "reinstate";
const ALLOWED_FROM: Record<Action, string[]> = {
  approve: ["pending"],
  waitlist: ["submitted", "pending"],
  reinstate: ["cancelled", "waitlisted"],
};

/**
 * manageRegistration — `registrations.manage` changes a registration's
 * status at any time (Req 37):
 * - `approve`: pending to submitted (its places are already counted);
 * - `waitlist`: submitted or pending to waitlisted, at the end of the
 *   queue, freeing its places and taking back what registering gave;
 * - `reinstate`: cancelled or waitlisted to submitted, taking places and
 *   giving membership; a waitlisted group's open offer is used up.
 * Taking places beyond capacity is refused with `overCapacity` (and how
 * many over) unless `confirmOverCapacity` is true. Each change is logged.
 */
export const manageRegistration = onCall({timeoutSeconds: 60}, async (request) => {
  const uid = request.auth?.uid;
  const data = (request.data ?? {}) as Record<string, unknown>;
  const action = data.action as Action;
  const registrationId = typeof data.registrationId === "string" ? data.registrationId : "";
  if (!ALLOWED_FROM[action] || !registrationId) {
    throw new HttpsError("invalid-argument", "registrationId and action are required.");
  }
  const confirm = data.confirmOverCapacity === true;
  return withStructuredLogs({op: "manageRegistration", uid: uid ?? null, args: {eventId: data.eventId, registrationId, action}}, async () => {
    const {eventRef} = await managed(uid, data.eventId);
    const outcome = await db().runTransaction(async (tx) => {
      const tallyRef = eventRef.collection("registrationTally").doc("current");
      const regRef = eventRef.collection("registrations").doc(registrationId);
      const [eventDoc, tally, reg] = await Promise.all([tx.get(eventRef), tx.get(tallyRef), tx.get(regRef)]);
      const event = eventDoc.data()!;
      if (!reg.exists) throw new HttpsError("not-found", "We couldn't find this registration.");
      const r = reg.data()!;
      if (!ALLOWED_FROM[action].includes(r.status)) {
        throw new HttpsError("failed-precondition", `A ${r.status} registration can't be changed that way.`,
          {reason: "wrongStatus", status: r.status});
      }
      const groupRef = eventRef.collection("groups").doc(String(r.groupId));
      const [people, group] = await Promise.all([
        tx.get(eventRef.collection("participants").where("registrationId", "==", registrationId)),
        tx.get(groupRef),
      ]);
      const membership = await applyRegistrationMembership.read(tx, eventRef, regRef, {
        event, groupId: groupRef.id, adults: group.data()?.adultUids ?? [], contactUid: r.contactUid,
      });
      const t = tally.data() ?? {};
      const used = typeof t.placesUsed === "number" ? t.placesUsed : 0;
      const offers: Array<{registrationId: string; size: number}> = Array.isArray(t.offers) ? t.offers : [];
      const size = people.size;
      const now = FieldValue.serverTimestamp();
      let status: string;
      const regUpdate: Record<string, unknown> = {updatedAt: now};
      const tallyUpdate: Record<string, unknown> = {updatedAt: now};
      if (action === "approve") {
        status = "submitted";
      } else if (action === "waitlist") {
        status = "waitlisted";
        const next = typeof t.nextWaitlist === "number" ? t.nextWaitlist : 1;
        regUpdate.waitlistPosition = next;
        tallyUpdate.nextWaitlist = next + 1;
        tallyUpdate.placesUsed = Math.max(0, used - size);
      } else {
        status = "submitted";
        const rest = offers.filter((o) => o.registrationId !== registrationId);
        const held = rest.reduce((n, o) => n + (o.size ?? 0), 0);
        const capacity = typeof event.capacity === "number" ? event.capacity : null;
        const over = capacity === null ? 0 : used + held + size - capacity;
        if (over > 0 && !confirm) {
          throw new HttpsError("failed-precondition", `This takes the event ${over} over capacity.`,
            {reason: "overCapacity", over});
        }
        tallyUpdate.placesUsed = used + size;
        tallyUpdate.offers = rest;
        regUpdate.waitlistPosition = null;
        regUpdate.cancelReason = null;
        regUpdate.offer = null;
      }
      regUpdate.status = status;
      tx.update(regRef, regUpdate);
      tx.set(tallyRef, tallyUpdate, {merge: true});
      if (group.exists) tx.update(groupRef, {registrationStatus: status, updatedAt: now});
      people.docs.forEach((p) => tx.update(p.ref, {registrationStatus: status, updatedAt: now}));
      tx.set(regRef.collection("changes").doc(), {
        at: now, by: uid, action: action === "approve" ? "approved" : action === "waitlist" ? "waitlisted" : "reinstated",
        status, from: r.status, ...(action === "reinstate" && confirm ? {overCapacity: true} : {}),
      });
      applyRegistrationMembership.write(tx, membership, status === "submitted" ? "submitted" : "cancelled");
      return {status, freed: action === "waitlist"};
    });
    if (outcome.freed) await offerOnwardNow(db(), eventRef.id);
    if (outcome.status === "submitted") await sendConfirmation(eventRef, registrationId);
    return {status: outcome.status};
  });
});

/** The contact's address for [registrationId], from their private details or account. */
async function contactEmail(eventRef: Ref, reg: Data, registrationId: string): Promise<string | null> {
  if (!reg.contactUid) return null;
  const contact = await eventRef.collection("participants")
    .where("registrationId", "==", registrationId).where("uid", "==", reg.contactUid).limit(1).get();
  const details = contact.docs[0] ?
    (await contact.docs[0].ref.collection("private").doc("details").get()).data() : undefined;
  const fromDraft = reg.draft?.email;
  let email = normaliseEmail(details?.email) ?? normaliseEmail(fromDraft);
  if (!email) {
    try {
      email = normaliseEmail((await getAuth().getUser(reg.contactUid)).email);
    } catch {
      email = null;
    }
  }
  return email;
}

/** Queues the confirmation (or the waitlist number) for a registration. */
async function sendConfirmation(eventRef: Ref, registrationId: string): Promise<boolean> {
  const [eventDoc, regDoc, people] = await Promise.all([
    eventRef.get(),
    eventRef.collection("registrations").doc(registrationId).get(),
    eventRef.collection("participants").where("registrationId", "==", registrationId).get(),
  ]);
  const reg = regDoc.data();
  if (!reg) return false;
  const to = await contactEmail(eventRef, reg, registrationId);
  if (!to) return false;
  const event = eventDoc.data() ?? {};
  await enqueueEmail(db(), {
    to, uid: reg.contactUid ?? null, eventId: eventRef.id,
    template: reg.status === "waitlisted" ? "registrationWaitlisted" : "registrationConfirmation",
    data: {
      eventTitle: String(event.title ?? ""),
      people: people.docs.map((p) => `• ${String(p.data().name ?? "")}`).join("\n"),
      position: String(reg.waitlistPosition ?? ""),
      link: `https://${hostingDomain()}/e/${registrationOf(event).slug}/registration`,
    },
  });
  return true;
}

/**
 * resendConfirmation — sends a submitted or pending registration's
 * confirmation, or a waitlisted one's number, again (Req 66). Refused for
 * drafts and cancelled registrations (`wrongStatus`), and with
 * `noContact` when there is no address to send to.
 */
export const resendConfirmation = onCall({timeoutSeconds: 60}, async (request) => {
  const uid = request.auth?.uid;
  const data = (request.data ?? {}) as Record<string, unknown>;
  return withStructuredLogs({op: "resendConfirmation", uid: uid ?? null, args: {eventId: data.eventId}}, async () => {
    const {eventRef} = await managed(uid, data.eventId);
    const registrationId = typeof data.registrationId === "string" ? data.registrationId : "";
    const reg = (await eventRef.collection("registrations").doc(registrationId).get()).data();
    if (!reg) throw new HttpsError("not-found", "We couldn't find this registration.");
    if (!["submitted", "pending", "waitlisted"].includes(reg.status)) {
      throw new HttpsError("failed-precondition", "Only a sent registration has a confirmation.", {reason: "wrongStatus"});
    }
    if (!(await sendConfirmation(eventRef, registrationId))) {
      throw new HttpsError("failed-precondition", "There's no email address to send to.", {reason: "noContact"});
    }
    return {sent: true};
  });
});

/**
 * sendClosingReminder — the closing reminder `registrations.manage` sends
 * by hand (Req 52): one email to the contact of each draft not yet sent,
 * with the deadline in the event's zone and a link to finish. Cancelled
 * and sent registrations get nothing (B-16). Returns how many were sent.
 */
export const sendClosingReminder = onCall({timeoutSeconds: 300}, async (request) => {
  const uid = request.auth?.uid;
  const data = (request.data ?? {}) as Record<string, unknown>;
  return withStructuredLogs({op: "sendClosingReminder", uid: uid ?? null, args: {eventId: data.eventId}}, async () => {
    const {eventRef, event} = await managed(uid, data.eventId);
    const settings = registrationOf(event);
    const zone = typeof event.timeZone === "string" ? event.timeZone : "UTC";
    const closes = settings.deadline === null ? "" : new Intl.DateTimeFormat("en-US", {
      timeZone: zone, weekday: "short", month: "short", day: "numeric", hour: "numeric", minute: "2-digit",
      timeZoneName: "short",
    }).format(new Date(settings.deadline));
    const drafts = await eventRef.collection("registrations").where("status", "==", "draft").get();
    let sent = 0;
    for (const d of drafts.docs) {
      const to = await contactEmail(eventRef, d.data(), d.id);
      if (!to) continue;
      await enqueueEmail(db(), {
        to, uid: d.data().contactUid ?? null, eventId: eventRef.id, template: "registrationClosing",
        data: {
          eventTitle: String(event.title ?? ""), closes,
          link: `https://${hostingDomain()}/e/${settings.slug}/register`,
        },
      });
      sent++;
    }
    return {sent};
  });
});

/**
 * getGroupRegistration — a group's registration for its detail (Req 66):
 * status, number, open offer, when sent, the change log (newest first, at
 * most 50), the contact and linked adults by name (the contact's email
 * only with `participants.readPrivate`), and each person's waivers with
 * the version accepted, when and as whom. Null `registration` for a group
 * added by hand or by import.
 */
export const getGroupRegistration = onCall({timeoutSeconds: 60}, async (request) => {
  const uid = request.auth?.uid;
  const data = (request.data ?? {}) as Record<string, unknown>;
  return withStructuredLogs({op: "getGroupRegistration", uid: uid ?? null, args: {eventId: data.eventId}}, async () => {
    const {eventRef, event} = await managed(uid, data.eventId);
    const groupId = typeof data.groupId === "string" ? data.groupId : "";
    const group = await eventRef.collection("groups").doc(groupId).get();
    if (!group.exists) throw new HttpsError("not-found", "We couldn't find this group.");
    const registrationId = group.data()!.registrationId;
    if (typeof registrationId !== "string") return {registration: null};
    const regRef = eventRef.collection("registrations").doc(registrationId);
    const [reg, changes, people, waivers, held] = await Promise.all([
      regRef.get(),
      regRef.collection("changes").orderBy("at", "desc").limit(50).get(),
      eventRef.collection("participants").where("registrationId", "==", registrationId).get(),
      loadWaivers(eventRef),
      readPermissions(null, eventRef, event, uid!),
    ]);
    const r = reg.data() ?? {};
    const adults: string[] = group.data()!.adultUids ?? [];
    const uids = [...new Set([r.contactUid, ...adults].filter((u): u is string => typeof u === "string"))];
    const profiles = uids.length ?
      await db().getAll(...uids.map((u) => eventRef.collection("profiles").doc(u))) : [];
    const nameOf = new Map(profiles.map((p) => [p.id, String(p.data()?.displayName ?? "")]));
    const waiverDocs = people.empty ? [] :
      await db().getAll(...people.docs.map((p) => p.ref.collection("private").doc("waivers")));
    const titles = new Map(waivers.map((w) => [w.id, w.title]));
    return {
      registration: {
        registrationId,
        status: r.status,
        waitlistPosition: r.waitlistPosition ?? null,
        offerExpiresAt: typeof r.offer?.expiresAt === "number" ? r.offer.expiresAt : null,
        submittedAt: millis(r.submittedAt),
        cancelReason: r.cancelReason ?? null,
        contact: r.contactUid ? {
          uid: r.contactUid, name: nameOf.get(r.contactUid) ?? "",
          email: held.includes("participants.readPrivate") ? await contactEmail(eventRef, r, registrationId) : null,
        } : null,
        linkedAdults: adults.map((u) => ({uid: u, name: nameOf.get(u) ?? ""})),
        changes: changes.docs.map((c) => ({
          at: millis(c.data().at), by: nameOf.get(c.data().by) ?? (c.data().by === "system" ? "" : String(c.data().by ?? "")),
          action: String(c.data().action ?? ""), changes: c.data().changes ?? [],
        })),
        people: people.docs.map((p, i) => {
          const accepted = (waiverDocs[i]?.data()?.accepted ?? {}) as Record<string, Data>;
          return {
            id: p.id, name: String(p.data().name ?? ""),
            missingWaivers: p.data().missingWaivers ?? [],
            waivers: Object.entries(accepted).map(([waiverId, a]) => ({
              waiverId, title: titles.get(waiverId) ?? {en: ""}, version: a.version ?? 1,
              at: millis(a.at), as: a.as ?? null,
            })),
          };
        }),
      },
    };
  });
});
