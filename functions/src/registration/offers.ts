import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {onDocumentUpdated} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import {FieldValue, Firestore, getFirestore} from "firebase-admin/firestore";
import {clock} from "../utils/clock";
import {withStructuredLogs} from "../utils/logging";
import {enqueueEmail, normaliseEmail} from "../mail/outbox";
import {hostingDomain} from "../account/signInLink";
import {requirePermission} from "../events/members";
import {registrationOf} from "./registrationSettings";
import {eventBySlug} from "./registrationForm";
import {applyRegistrationMembership} from "./membership";
import {expireOffers, Offer, planOffers, WaitingGroup} from "./allocate";

/**
 * Waitlist offers (Spec #233 Req 32, 32a, 34, 52, 65; TD 11; #248). When
 * places free up, the first waiting group that fits is offered them for
 * `offerHours`: the offer sits in `registrationTally/current.offers`
 * (holding its places) and on the registration as `offer` (`offeredAt`,
 * `expiresAt`, in milliseconds), and `offerQueue/{eventId}.nextExpiry`
 * (server only) tells the 15-minute job when to look. The registration
 * stays `waitlisted` until the group accepts. An offer that runs out sends
 * the group to the end of the queue; a group that says No thanks leaves
 * the waitlist; either way the places are offered onward at once. Nothing
 * is offered by itself after the deadline; organizers may still offer by
 * hand. A nightly recount corrects the tally.
 */

const db = () => getFirestore();
type Data = FirebaseFirestore.DocumentData;
type Ref = FirebaseFirestore.DocumentReference;

const tallyRef = (eventRef: Ref) => eventRef.collection("registrationTally").doc("current");
const queueRef = (eventId: string) => db().collection("offerQueue").doc(eventId);

function offersOf(tally: Data | undefined): Offer[] {
  return Array.isArray(tally?.offers) ? (tally!.offers as Offer[]).filter((o) => typeof o?.registrationId === "string") : [];
}

/** Waiting registrations, read in [tx] before any write. */
async function readWaitlist(tx: FirebaseFirestore.Transaction, eventRef: Ref): Promise<WaitingGroup[]> {
  const snap = await tx.get(eventRef.collection("registrations").where("status", "==", "waitlisted"));
  return snap.docs.map((d) => ({
    registrationId: d.id,
    size: typeof d.data().size === "number" ? d.data().size : 1,
    position: typeof d.data().waitlistPosition === "number" ? d.data().waitlistPosition : Number.MAX_SAFE_INTEGER,
  }));
}

/** Writes [offers] (all open ones) to the tally and the offer queue, and [made] to their registrations. */
function writeOffers(tx: FirebaseFirestore.Transaction, eventRef: Ref, offers: Offer[], made: Offer[]): void {
  tx.set(tallyRef(eventRef), {offers, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
  for (const o of made) {
    tx.update(eventRef.collection("registrations").doc(o.registrationId), {
      offer: {offeredAt: o.offeredAt, expiresAt: o.expiresAt}, updatedAt: FieldValue.serverTimestamp(),
    });
  }
  if (offers.length === 0) {
    tx.delete(queueRef(eventRef.id));
  } else {
    tx.set(queueRef(eventRef.id), {eventId: eventRef.id, nextExpiry: Math.min(...offers.map((o) => o.expiresAt))});
  }
}

/** What emails need, read once after a transaction. */
async function emailContext(eventId: string) {
  const event = (await db().collection("events").doc(eventId).get()).data() ?? {};
  const slug = registrationOf(event).slug;
  return {
    title: String(event.title ?? ""),
    timeZone: typeof event.timeZone === "string" ? event.timeZone : "UTC",
    link: `https://${hostingDomain()}/e/${slug}/registration`,
  };
}

/** The contact's address and account for a registration, or null. */
async function contactOf(eventId: string, registrationId: string): Promise<{to: string; uid: string} | null> {
  const eventRef = db().collection("events").doc(eventId);
  const reg = (await eventRef.collection("registrations").doc(registrationId).get()).data();
  if (!reg?.contactUid) return null;
  const contact = await eventRef.collection("participants")
    .where("registrationId", "==", registrationId).where("uid", "==", reg.contactUid).limit(1).get();
  const details = contact.docs[0] ?
    (await contact.docs[0].ref.collection("private").doc("details").get()).data() : undefined;
  const to = normaliseEmail(details?.email);
  return to ? {to, uid: reg.contactUid} : null;
}

function formatIn(ms: number, timeZone: string): string {
  return new Intl.DateTimeFormat("en-US", {
    timeZone, weekday: "short", month: "short", day: "numeric", hour: "numeric", minute: "2-digit", timeZoneName: "short",
  }).format(new Date(ms));
}

/** Emails (and pushes) each new offer, and each expired one (Req 52). */
async function sendOfferMail(eventId: string, made: Offer[], expired: Offer[] = []): Promise<void> {
  if (made.length === 0 && expired.length === 0) return;
  const ctx = await emailContext(eventId);
  for (const [o, template] of [
    ...made.map((o) => [o, "registrationOffer"] as const),
    ...expired.map((o) => [o, "registrationOfferExpired"] as const),
  ]) {
    const contact = await contactOf(eventId, o.registrationId);
    if (!contact) continue;
    await enqueueEmail(db(), {
      to: contact.to, uid: contact.uid, template, eventId, push: true, deepLink: ctx.link,
      data: {eventTitle: ctx.title, until: formatIn(o.expiresAt, ctx.timeZone), link: ctx.link},
    });
  }
}

/**
 * Offers free places onward now, in its own transaction, and emails the
 * groups offered. Called after anything frees places: a cancellation, a
 * smaller group, a higher capacity, No thanks, an expiry.
 */
export async function offerOnwardNow(firestore: Firestore, eventId: string, now = clock.now()): Promise<Offer[]> {
  const eventRef = firestore.collection("events").doc(eventId);
  const made = await firestore.runTransaction(async (tx) => {
    const [eventDoc, tally] = await Promise.all([tx.get(eventRef), tx.get(tallyRef(eventRef))]);
    if (!eventDoc.exists) return [];
    const event = eventDoc.data()!;
    const settings = registrationOf(event);
    const waitlist = await readWaitlist(tx, eventRef);
    if (waitlist.length === 0) return [];
    const open = offersOf(tally.data());
    const planned = planOffers({
      capacity: typeof event.capacity === "number" ? event.capacity : null,
      placesUsed: typeof tally.data()?.placesUsed === "number" ? tally.data()!.placesUsed : 0,
      offers: open, queue: waitlist, now, offerHours: settings.offerHours, deadline: settings.deadline,
    });
    if (planned.length === 0) return [];
    writeOffers(tx, eventRef, [...open, ...planned], planned);
    return planned;
  });
  await sendOfferMail(eventId, made);
  return made;
}

/** The caller's registration, as its contact or a linked adult; null when none. */
async function findMine(
  tx: FirebaseFirestore.Transaction, eventRef: Ref, uid: string
): Promise<FirebaseFirestore.DocumentSnapshot | null> {
  const mine = await tx.get(eventRef.collection("registrations").where("contactUid", "==", uid).limit(1));
  const own = mine.docs.find((d) => d.data().status !== "draft");
  if (own) return own;
  const member = await tx.get(eventRef.collection("members").doc(uid));
  const groupIds: string[] = (member.data()?.groupIds ?? []).slice(0, 10);
  if (groupIds.length === 0) return null;
  const asAdult = await tx.get(eventRef.collection("registrations").where("groupId", "in", groupIds).limit(1));
  return asAdult.docs[0] ?? null;
}

/** Marks a registration, its group and people with [status] in [tx]. */
async function setStatus(
  tx: FirebaseFirestore.Transaction, eventRef: Ref, reg: FirebaseFirestore.DocumentSnapshot,
  status: string, extra: Record<string, unknown>, people: FirebaseFirestore.QuerySnapshot
): Promise<void> {
  const now = FieldValue.serverTimestamp();
  tx.update(reg.ref, {status, offer: null, waitlistPosition: null, updatedAt: now, ...extra});
  tx.update(eventRef.collection("groups").doc(String(reg.data()!.groupId)), {registrationStatus: status, updatedAt: now});
  people.docs.forEach((p) => tx.update(p.ref, {registrationStatus: status, updatedAt: now}));
}

/**
 * respondToOffer — the group's contact or linked adult accepts an open
 * offer (`accept: true`: the registration becomes `submitted`, its places
 * move from held to used, membership is given and the confirmation sent)
 * or says No thanks (`accept: false`: the registration is cancelled with
 * `cancelReason: declinedOffer` and the places are offered onward at
 * once). Refuses with `failed-precondition` and `details.reason`
 * `noOffer`, or `expired` once the offer has run out (Req 32, TD 11).
 */
export const respondToOffer = onCall({timeoutSeconds: 60}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Must be signed in.");
  const data = (request.data ?? {}) as {slug?: unknown; accept?: unknown};
  const accept = data.accept === true;
  return withStructuredLogs({op: "respondToOffer", uid, args: {slug: data.slug, accept}}, async () => {
    const {ref: eventRef} = await eventBySlug(data.slug);
    const now = clock.now();
    const outcome = await db().runTransaction(async (tx) => {
      const [eventDoc, tally] = await Promise.all([tx.get(eventRef), tx.get(tallyRef(eventRef))]);
      if (!eventDoc.exists) throw new HttpsError("not-found", "We couldn't find this event.");
      const event = eventDoc.data()!;
      const reg = await findMine(tx, eventRef, uid);
      if (!reg) throw new HttpsError("not-found", "You haven't registered for this event.");
      const open = offersOf(tally.data());
      const offer = open.find((o) => o.registrationId === reg.id);
      if (reg.data()!.status !== "waitlisted" || !offer) {
        throw new HttpsError("failed-precondition", "There's no place on offer for your group.", {reason: "noOffer"});
      }
      if (offer.expiresAt <= now) {
        throw new HttpsError("failed-precondition", "This offer has expired.", {reason: "expired"});
      }
      const [people, group] = await Promise.all([
        tx.get(eventRef.collection("participants").where("registrationId", "==", reg.id)),
        tx.get(eventRef.collection("groups").doc(String(reg.data()!.groupId))),
      ]);
      const membership = accept ? await applyRegistrationMembership.read(tx, eventRef, reg.ref, {
        event, groupId: group.id, adults: group.data()?.adultUids ?? [], contactUid: reg.data()!.contactUid,
      }) : null;
      const rest = open.filter((o) => o.registrationId !== reg.id);
      const used = typeof tally.data()?.placesUsed === "number" ? tally.data()!.placesUsed : 0;
      tx.set(tallyRef(eventRef), {
        offers: rest, placesUsed: accept ? used + people.size : used, updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      if (rest.length === 0) tx.delete(queueRef(eventRef.id));
      else tx.set(queueRef(eventRef.id), {eventId: eventRef.id, nextExpiry: Math.min(...rest.map((o) => o.expiresAt))});
      if (accept) {
        await setStatus(tx, eventRef, reg, "submitted", {}, people);
        applyRegistrationMembership.write(tx, membership!, "submitted");
      } else {
        await setStatus(tx, eventRef, reg, "cancelled", {cancelReason: "declinedOffer"}, people);
      }
      tx.set(reg.ref.collection("changes").doc(), {
        at: FieldValue.serverTimestamp(), by: uid, action: accept ? "offerAccepted" : "offerDeclined",
        status: accept ? "submitted" : "cancelled",
      });
      return {registrationId: reg.id, names: people.docs.map((p) => String(p.data().name ?? ""))};
    });
    if (accept) {
      const ctx = await emailContext(eventRef.id);
      const contact = await contactOf(eventRef.id, outcome.registrationId);
      if (contact) {
        await enqueueEmail(db(), {
          to: contact.to, uid: contact.uid, template: "registrationConfirmation", eventId: eventRef.id,
          data: {eventTitle: ctx.title, people: outcome.names.map((n) => `• ${n}`).join("\n"), position: "", link: ctx.link},
        });
      }
    } else {
      await offerOnwardNow(db(), eventRef.id, now);
    }
    return {status: accept ? "submitted" : "cancelled"};
  });
});

/**
 * manageOffer — `registrations.manage` withdraws an open offer (the group
 * keeps its place in the queue, and the places wait for the next
 * opening), extends one by `hours`, or offers a place by hand to a waiting
 * group that fits (`offer`, which works after the deadline too), with
 * `noRoom` when it does not (Req 32).
 */
export const manageOffer = onCall({timeoutSeconds: 60}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Must be signed in.");
  const data = (request.data ?? {}) as Record<string, unknown>;
  const eventId = typeof data.eventId === "string" ? data.eventId : "";
  const registrationId = typeof data.registrationId === "string" ? data.registrationId : "";
  const action = data.action;
  if (!eventId || !registrationId || !["withdraw", "extend", "offer"].includes(String(action))) {
    throw new HttpsError("invalid-argument", "eventId, registrationId and action are required.");
  }
  const hours = typeof data.hours === "number" && Number.isInteger(data.hours) && data.hours > 0 && data.hours <= 14 * 24 ?
    data.hours : null;
  if (action === "extend" && hours === null) throw new HttpsError("invalid-argument", "hours must be 1 to 336.");

  return withStructuredLogs({op: "manageOffer", uid, args: {eventId, registrationId, action}}, async () => {
    const eventRef = db().collection("events").doc(eventId);
    const now = clock.now();
    const made = await db().runTransaction(async (tx) => {
      const [eventDoc, tally, reg] = await Promise.all([
        tx.get(eventRef), tx.get(tallyRef(eventRef)), tx.get(eventRef.collection("registrations").doc(registrationId)),
      ]);
      if (!eventDoc.exists) throw new HttpsError("not-found", "We couldn't find this event.");
      const event = eventDoc.data()!;
      await requirePermission(tx, eventRef, event, uid, "registrations.manage",
        "You don't have permission to manage registrations.");
      if (!reg.exists || reg.data()!.status !== "waitlisted") {
        throw new HttpsError("failed-precondition", "This group isn't on the waitlist.", {reason: "notWaiting"});
      }
      const open = offersOf(tally.data());
      const current = open.find((o) => o.registrationId === registrationId);
      const log = (what: string, extra: object = {}) => tx.set(reg.ref.collection("changes").doc(), {
        at: FieldValue.serverTimestamp(), by: uid, action: what, ...extra,
      });
      if (action === "offer") {
        if (current) throw new HttpsError("failed-precondition", "This group already has an offer.", {reason: "offered"});
        const used = typeof tally.data()?.placesUsed === "number" ? tally.data()!.placesUsed : 0;
        const held = open.reduce((n, o) => n + o.size, 0);
        const size = typeof reg.data()!.size === "number" ? reg.data()!.size : 1;
        const capacity = typeof event.capacity === "number" ? event.capacity : null;
        if (capacity !== null && used + held + size > capacity) {
          throw new HttpsError("failed-precondition", "There's no room for this group.", {reason: "noRoom"});
        }
        const offer: Offer = {
          registrationId, size, offeredAt: now, expiresAt: now + registrationOf(event).offerHours * 3600_000,
        };
        writeOffers(tx, eventRef, [...open, offer], [offer]);
        log("offerMade");
        return [offer];
      }
      if (!current) throw new HttpsError("failed-precondition", "This group has no open offer.", {reason: "noOffer"});
      if (action === "withdraw") {
        writeOffers(tx, eventRef, open.filter((o) => o.registrationId !== registrationId), []);
        tx.update(reg.ref, {offer: null, updatedAt: FieldValue.serverTimestamp()});
        log("offerWithdrawn");
      } else {
        const extended = {...current, expiresAt: current.expiresAt + hours! * 3600_000};
        writeOffers(tx, eventRef, open.map((o) => o.registrationId === registrationId ? extended : o), [extended]);
        log("offerExtended", {expiresAt: extended.expiresAt});
      }
      return [];
    });
    await sendOfferMail(eventId, made);
    return {success: true};
  });
});

/**
 * Expires late offers in every event whose queue says one is due: each
 * group moves to the end of the queue and is emailed, then the places are
 * offered onward. Returns how many offers expired.
 */
export async function runOfferExpiry(firestore: Firestore, now = clock.now()): Promise<number> {
  const due = await firestore.collection("offerQueue").where("nextExpiry", "<=", now).get();
  let count = 0;
  for (const q of due.docs) {
    const eventRef = firestore.collection("events").doc(q.id);
    try {
      const expired = await firestore.runTransaction(async (tx) => {
        const tally = await tx.get(tallyRef(eventRef));
        const {open, expired} = expireOffers(offersOf(tally.data()), now);
        const regs = await Promise.all(expired.map((o) => tx.get(eventRef.collection("registrations").doc(o.registrationId))));
        let next = typeof tally.data()?.nextWaitlist === "number" ? tally.data()!.nextWaitlist : 1;
        regs.forEach((r) => {
          if (!r.exists || r.data()!.status !== "waitlisted") return;
          tx.update(r.ref, {offer: null, waitlistPosition: next++, updatedAt: FieldValue.serverTimestamp()});
          tx.set(r.ref.collection("changes").doc(), {at: FieldValue.serverTimestamp(), by: "system", action: "offerExpired"});
        });
        tx.set(tallyRef(eventRef), {nextWaitlist: next}, {merge: true});
        writeOffers(tx, eventRef, open, []);
        return expired;
      });
      count += expired.length;
      await sendOfferMail(q.id, [], expired);
      await offerOnwardNow(firestore, q.id, now);
    } catch (e) {
      logger.error(`Expiring offers for ${q.id} failed`, e);
    }
  }
  return count;
}

/** onOffersScheduled — expires late offers every 15 minutes (Req 32). */
export const onOffersScheduled = onSchedule(
  {schedule: "every 15 minutes", retryCount: 0, timeoutSeconds: 300},
  async () => {
    const expired = await runOfferExpiry(getFirestore());
    if (expired > 0) logger.info(`Offers expired: ${expired}`);
  }
);

/**
 * Counts [eventId]'s places again from its people (those in submitted and
 * pending registrations, still active) and drops offers whose group is no
 * longer waiting, logging any correction in the tally's `corrections`.
 * Returns whether anything changed.
 */
export async function recountTally(firestore: Firestore, eventId: string, now = clock.now()): Promise<boolean> {
  const eventRef = firestore.collection("events").doc(eventId);
  return firestore.runTransaction(async (tx) => {
    const [tally, counted, waiting] = await Promise.all([
      tx.get(tallyRef(eventRef)),
      tx.get(eventRef.collection("participants").where("registrationStatus", "in", ["submitted", "pending"])),
      tx.get(eventRef.collection("registrations").where("status", "==", "waitlisted")),
    ]);
    if (!tally.exists) return false;
    const placesUsed = counted.docs.filter((d) => d.data().status !== "cancelled").length;
    const waitingIds = new Set(waiting.docs.map((d) => d.id));
    const offers = offersOf(tally.data());
    const kept = offers.filter((o) => waitingIds.has(o.registrationId));
    const before = typeof tally.data()?.placesUsed === "number" ? tally.data()!.placesUsed : 0;
    if (before === placesUsed && kept.length === offers.length) return false;
    tx.set(tally.ref, {placesUsed, offers: kept, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
    tx.set(tally.ref.collection("corrections").doc(), {
      at: now, placesUsed: {from: before, to: placesUsed},
      offersDropped: offers.filter((o) => !waitingIds.has(o.registrationId)).map((o) => o.registrationId),
    });
    logger.warn(`Tally corrected for ${eventId}: places ${before} -> ${placesUsed}`);
    return true;
  });
}

/** onTallyRecountScheduled — the nightly recount of every event's places (TD 11). */
export const onTallyRecountScheduled = onSchedule(
  {schedule: "every day 03:00", timeZone: "America/Chicago", retryCount: 0, timeoutSeconds: 540},
  async () => {
    const firestore = getFirestore();
    const tallies = await firestore.collectionGroup("registrationTally").get();
    let corrected = 0;
    for (const t of tallies.docs) {
      const eventId = t.ref.parent.parent?.id;
      if (!eventId) continue;
      try {
        if (await nightlyUpkeep(firestore, eventId)) corrected++;
      } catch (e) {
        logger.error(`Recounting ${eventId} failed`, e);
      }
    }
    logger.info(`Tallies recounted: ${tallies.size}, corrected: ${corrected}`);
  }
);

/**
 * getWaitlist — the waitlist for `registrations.manage` (#248): waiting
 * groups in queue order with their name, size, number and any open offer,
 * plus the event's capacity, places used and held, so the screen can say
 * how far over a lowered capacity the event is. Never names people.
 */
export const getWaitlist = onCall({timeoutSeconds: 60}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Must be signed in.");
  const eventId = typeof request.data?.eventId === "string" ? request.data.eventId : "";
  if (!eventId) throw new HttpsError("invalid-argument", "eventId is required.");
  return withStructuredLogs({op: "getWaitlist", uid, args: {eventId}}, async () => {
    const eventRef = db().collection("events").doc(eventId);
    const eventDoc = await eventRef.get();
    if (!eventDoc.exists) throw new HttpsError("not-found", "We couldn't find this event.");
    const event = eventDoc.data()!;
    await requirePermission(null, eventRef, event, uid, "registrations.manage",
      "You don't have permission to manage registrations.");
    const [tally, waiting] = await Promise.all([
      tallyRef(eventRef).get(),
      eventRef.collection("registrations").where("status", "==", "waitlisted").get(),
    ]);
    const offers = offersOf(tally.data());
    const groups = waiting.empty ? [] :
      await db().getAll(...waiting.docs.map((d) => eventRef.collection("groups").doc(String(d.data().groupId))));
    const names = new Map(groups.map((g) => [g.id, String(g.data()?.name ?? "")]));
    const entries = waiting.docs.map((d) => {
      const r = d.data();
      const offer = offers.find((o) => o.registrationId === d.id);
      return {
        registrationId: d.id,
        groupName: names.get(String(r.groupId)) ?? "",
        size: typeof r.size === "number" ? r.size : 1,
        position: typeof r.waitlistPosition === "number" ? r.waitlistPosition : null,
        offerExpiresAt: offer?.expiresAt ?? null,
      };
    }).sort((a, b) => (a.position ?? Number.MAX_SAFE_INTEGER) - (b.position ?? Number.MAX_SAFE_INTEGER));
    return {
      capacity: typeof event.capacity === "number" ? event.capacity : null,
      placesUsed: typeof tally.data()?.placesUsed === "number" ? tally.data()!.placesUsed : 0,
      held: offers.reduce((n, o) => n + o.size, 0),
      deadline: registrationOf(event).deadline,
      timeZone: typeof event.timeZone === "string" ? event.timeZone : "UTC",
      waiting: entries,
    };
  });
});

/**
 * The nightly upkeep of one event (TD 11): the recount, then offering any
 * places left free, so an opening missed by every other path is still
 * offered. Returns whether the recount corrected anything.
 */
export async function nightlyUpkeep(firestore: Firestore, eventId: string, now = clock.now()): Promise<boolean> {
  const corrected = await recountTally(firestore, eventId, now);
  await offerOnwardNow(firestore, eventId, now);
  return corrected;
}

/** Whether a capacity change from [before] to [after] frees places. */
export function capacityRaised(before: unknown, after: unknown): boolean {
  const b = typeof before === "number" ? before : null;
  const a = typeof after === "number" ? after : null;
  if (b === null) return false;
  return a === null || a > b;
}

/**
 * onCapacityRaised — an event's capacity went up or was removed, however
 * it was changed (Event settings, Registration settings or the console),
 * so the freed places are offered to the waitlist at once (Req 32).
 */
export const onCapacityRaised = onDocumentUpdated("events/{eventId}", async (event) => {
  if (!capacityRaised(event.data?.before.data()?.capacity, event.data?.after.data()?.capacity)) return;
  await offerOnwardNow(getFirestore(), event.params.eventId);
});
