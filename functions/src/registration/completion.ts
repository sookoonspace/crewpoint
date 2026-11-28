import {onCall, HttpsError, CallableRequest} from "firebase-functions/v2/https";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {withStructuredLogs} from "../utils/logging";
import {enqueueEmail, normaliseEmail} from "../mail/outbox";
import {hostingDomain} from "../account/signInLink";
import {requirePermission} from "../events/members";
import {registrationOf} from "./registrationSettings";
import {checkOpen} from "./registrationForm";
import {allocate} from "./allocate";
import {applyRegistrationMembership} from "./membership";
import {loadFormInputs, privateDetails, readConsent, readForm} from "./submitRegistration";
import {acceptedAs, acceptedOf, requiredProblems, writeAcceptances} from "./waiverAcceptance";

/**
 * "Complete your registration" (Spec #233 Req 5, 66; #249). A group the
 * organizer added by hand or by import has no registration. With
 * `registrations.manage`, `sendCompletionLink` makes a `draft`
 * registration for it (`groupId` set, `contactUid` null, `completion:
 * {email, by, at}`) and emails that address a link to
 * `/e/{slug}/register?complete={registrationId}`. Whoever signs in with
 * that verified email gets the group's people on the form
 * (`getRegistrationForm` with `complete`) and submits them
 * (`submitRegistration` with `completeRegistrationId`): the draft becomes
 * their registration, attached to the existing group and people, placed
 * as any other (submitted, pending or waitlisted), and they become its
 * contact. Refusals carry `details.reason`: `completionNotFound`,
 * `completionUsed`, or `completionEmail` when the signed-in email is not
 * the one the link was sent to (or is not verified).
 */

const db = () => getFirestore();
type Ref = FirebaseFirestore.DocumentReference;
const isRecord = (v: unknown): v is Record<string, unknown> => typeof v === "object" && v !== null && !Array.isArray(v);

/**
 * The completion draft [completeId] in [eventRef], checked against the
 * caller's verified email. Reads through [tx] when given.
 */
export async function readCompletion(
  tx: FirebaseFirestore.Transaction | null,
  eventRef: Ref,
  completeId: string,
  auth: CallableRequest["auth"]
): Promise<{ref: Ref; data: FirebaseFirestore.DocumentData}> {
  const ref = eventRef.collection("registrations").doc(completeId);
  const snap = tx ? await tx.get(ref) : await ref.get();
  const data = snap.data();
  if (!snap.exists || !data?.completion) {
    throw new HttpsError("not-found", "We couldn't find this registration link.", {reason: "completionNotFound"});
  }
  if (data.status !== "draft" || data.contactUid) {
    throw new HttpsError("failed-precondition", "This group has already registered.", {reason: "completionUsed"});
  }
  const email = auth?.token?.email_verified === true ? normaliseEmail(auth.token.email) : null;
  if (!email || email !== data.completion.email) {
    throw new HttpsError("permission-denied",
      "Please sign in with the email address this link was sent to.", {reason: "completionEmail"});
  }
  return {ref, data};
}

/**
 * sendCompletionLink — `registrations.manage` sends a group added by hand
 * a link to complete its registration, to [email] (Req 5). Sending again
 * to the same group replaces the address and sends a new email. Refused
 * with `alreadyRegistered` for a group with a registration.
 */
export const sendCompletionLink = onCall({timeoutSeconds: 60}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Must be signed in.");
  const data = isRecord(request.data) ? request.data : {};
  const eventId = typeof data.eventId === "string" ? data.eventId : "";
  const groupId = typeof data.groupId === "string" ? data.groupId : "";
  const email = normaliseEmail(data.email);
  if (!eventId || !groupId) throw new HttpsError("invalid-argument", "eventId and groupId are required.");
  if (!email) throw new HttpsError("invalid-argument", "Please enter a valid email address.", {reason: "invalidEmail"});
  return withStructuredLogs({op: "sendCompletionLink", uid, args: {eventId}}, async () => {
    const eventRef = db().collection("events").doc(eventId);
    const result = await db().runTransaction(async (tx) => {
      const eventDoc = await tx.get(eventRef);
      if (!eventDoc.exists) throw new HttpsError("not-found", "We couldn't find this event.");
      const event = eventDoc.data()!;
      await requirePermission(tx, eventRef, event, uid, "registrations.manage",
        "You don't have permission to manage registrations.");
      const groupRef = eventRef.collection("groups").doc(groupId);
      const [group, pending] = await Promise.all([
        tx.get(groupRef),
        tx.get(eventRef.collection("registrations").where("groupId", "==", groupId).limit(5)),
      ]);
      if (!group.exists) throw new HttpsError("not-found", "We couldn't find this group.");
      if (group.data()!.registrationId) {
        throw new HttpsError("failed-precondition", "This group already has a registration.", {reason: "alreadyRegistered"});
      }
      const slug = registrationOf(event).slug;
      if (!slug) throw new HttpsError("failed-precondition", "Choose a link name for the event first.", {reason: "noLink"});
      const earlier = pending.docs.find((d) => d.data().completion && d.data().status === "draft");
      const ref = earlier?.ref ?? eventRef.collection("registrations").doc();
      const now = FieldValue.serverTimestamp();
      tx.set(ref, {
        groupId, contactUid: null, status: "draft", completion: {email, by: uid, at: now}, updatedAt: now,
        ...(earlier ? {} : {createdAt: now}),
      }, {merge: true});
      tx.set(ref.collection("changes").doc(), {at: now, by: uid, action: "completionSent"});
      return {registrationId: ref.id, slug, title: String(event.title ?? ""), groupName: String(group.data()!.name ?? "")};
    });
    await enqueueEmail(db(), {
      to: email, eventId, template: "registrationComplete",
      data: {
        eventTitle: result.title, groupName: result.groupName,
        link: `https://${hostingDomain()}/e/${result.slug}/register?complete=${result.registrationId}`,
      },
    });
    return {registrationId: result.registrationId};
  });
});

/**
 * Submits a completion (called by `submitRegistration` when the form
 * carries `completeRegistrationId`): the form's people with an `id` must
 * be the group's; they are updated, new ones added, and the group's other
 * people stay and join the registration too. Placed like any submission.
 */
export async function submitCompletion(
  request: CallableRequest,
  eventRef: Ref,
  completeId: string
): Promise<{registrationId: string; status: string; waitlistPosition: number | null}> {
  const uid = request.auth!.uid;
  const data = request.data as Record<string, unknown>;
  const submissionId = String(data.submissionId);
  const {fields, sessions, waivers: allWaivers} = await loadFormInputs(eventRef);
  const outcome = await db().runTransaction(async (tx) => {
    const eventDoc = await tx.get(eventRef);
    if (!eventDoc.exists) throw new HttpsError("not-found", "We couldn't find this event.");
    const event = eventDoc.data()!;
    const settings = registrationOf(event);
    checkOpen(event, settings);
    const tallyRef = eventRef.collection("registrationTally").doc("current");
    const [mine, tallyDoc] = await Promise.all([
      tx.get(eventRef.collection("registrations").where("contactUid", "==", uid).limit(5)),
      tx.get(tallyRef),
    ]);
    // A repeat of this submission returns its first result.
    const done = mine.docs.find((d) => d.id === completeId && d.data().lastSubmissionId === submissionId);
    if (done) {
      return {registrationId: done.id, status: done.data().status, waitlistPosition: done.data().waitlistPosition ?? null, email: null};
    }
    if (mine.docs.some((d) => d.data().status !== "draft")) {
      throw new HttpsError("already-exists", "You have already registered for this event.", {reason: "alreadyRegistered"});
    }
    const {ref: regRef, data: completion} = await readCompletion(tx, eventRef, completeId, request.auth);
    const groupRef = eventRef.collection("groups").doc(String(completion.groupId));
    const [group, existing] = await Promise.all([
      tx.get(groupRef),
      tx.get(eventRef.collection("participants").where("groupId", "==", groupRef.id)),
    ]);
    if (!group.exists || group.data()!.registrationId) {
      throw new HttpsError("failed-precondition", "This group has already registered.", {reason: "completionUsed"});
    }
    const form = readForm(data, {event, settings, fields, sessions});
    const known = new Map(existing.docs.map((d) => [d.id, d]));
    if (form.people.some((p) => p.id !== null && !known.has(p.id))) {
      throw new HttpsError("invalid-argument", "Some answers need checking.", {reason: "invalid", problems: ["people.id"]});
    }
    const waivers = settings.blocks.waivers ? allWaivers : [];
    const missingRequired = requiredProblems(form.people, waivers,
      (i) => acceptedOf(known.get(form.people[i].id ?? "")?.data()));
    if (missingRequired.length > 0) {
      throw new HttpsError("invalid-argument", "Some answers need checking.", {reason: "invalid", problems: missingRequired});
    }
    const onForm = new Set(form.people.map((p) => p.id).filter((id): id is string => id !== null));
    const others = existing.docs.filter((d) => !onForm.has(d.id) && d.data().status !== "cancelled");
    const size = form.people.length + others.length;
    const tally = tallyDoc.data() ?? {};
    const placesUsed = typeof tally.placesUsed === "number" ? tally.placesUsed : 0;
    const nextWaitlist = typeof tally.nextWaitlist === "number" ? tally.nextWaitlist : 1;
    const held = Array.isArray(tally.offers) ?
      tally.offers.reduce((n: number, o: {size?: number}) => n + (o.size ?? 0), 0) : 0;
    const decision = allocate({
      capacity: typeof event.capacity === "number" ? event.capacity : null,
      placesUsed, held, size, review: settings.review,
    });
    const waitlistPosition = decision.status === "waitlisted" ? nextWaitlist : null;
    const adults = [...new Set([...(group.data()!.adultUids ?? []), uid])];
    const contactIndex = form.people.findIndex((p) => !p.isChild);
    const personRefs = form.people.map((p) => p.id ? eventRef.collection("participants").doc(p.id) :
      eventRef.collection("participants").doc());
    const membership = await applyRegistrationMembership.read(tx, eventRef, regRef, {
      event, groupId: groupRef.id, adults, contactUid: uid,
      contactParticipantId: contactIndex >= 0 ? personRefs[contactIndex].id : null,
    });
    const now = FieldValue.serverTimestamp();
    const email = isRecord(data.contact) ? normaliseEmail(data.contact.email) : null;

    tx.update(groupRef, {
      adultUids: adults, fields: form.group.standard, filterTags: form.group.filterTags,
      registrationId: regRef.id, registrationStatus: decision.status, updatedAt: now,
    });
    if (Object.keys(form.group.private).length > 0) {
      tx.set(groupRef.collection("private").doc("details"), {fields: form.group.private, updatedAt: now}, {merge: true});
    }
    form.people.forEach((person, i) => {
      const record = person.id ? known.get(person.id)!.data() : undefined;
      const waiverState = writeAcceptances(tx, personRefs[i], {
        accepting: person.acceptWaivers, accepted: acceptedOf(record), waivers, person, by: uid,
        as: acceptedAs({isChild: person.isChild, uid: i === contactIndex ? uid : record?.uid ?? null}, uid),
      });
      const fieldsNow = {
        ...waiverState,
        name: person.name, sortName: person.name.toLowerCase(), groupId: groupRef.id,
        isChild: person.isChild, categoryId: person.categoryId, fields: person.standard, filterTags: person.filterTags,
        ...(person.arrivalAt ? {arrivalAt: person.arrivalAt} : {}),
        ...(person.departureAt ? {departureAt: person.departureAt} : {}),
        ...(person.signUps.length ? {signUps: person.signUps} : {}),
        ...(person.optOuts.length ? {optOuts: person.optOuts} : {}),
        ...(i === contactIndex && !record?.uid ? {uid} : {}),
        registrationId: regRef.id, registrationStatus: decision.status, updatedAt: now,
      };
      if (record) tx.update(personRefs[i], fieldsNow);
      else tx.set(personRefs[i], {...fieldsNow, status: "active", createdAt: now});
      tx.set(personRefs[i].collection("private").doc("details"), {
        ...privateDetails(person),
        ...(person.birthDate ? {birthDate: person.birthDate} : {}),
        ...(i === contactIndex && email ? {email} : {}),
        updatedAt: now,
      }, {merge: true});
    });
    for (const d of others) {
      tx.update(d.ref, {registrationId: regRef.id, registrationStatus: decision.status, updatedAt: now});
    }
    const consent = readConsent(data.consent);
    tx.set(regRef, {
      groupId: groupRef.id, contactUid: uid, status: decision.status, size,
      submittedAt: now, updatedAt: now, waitlistPosition, cancelReason: null, mergedInto: null,
      duplicateOf: null, extraGuestsAllowed: settings.extraGuests, lastSubmissionId: submissionId,
      ...(consent ? {consent: {...consent, at: now}} : {}),
    }, {merge: true});
    tx.set(regRef.collection("changes").doc(), {at: now, by: uid, action: "submitted", status: decision.status});
    tx.set(tallyRef, {
      placesUsed: decision.placesUsed,
      nextWaitlist: waitlistPosition === null ? nextWaitlist : nextWaitlist + 1,
      updatedAt: now,
    }, {merge: true});
    applyRegistrationMembership.write(tx, membership, decision.status);
    return {registrationId: regRef.id, status: decision.status as string, waitlistPosition,
      email: email ?? normaliseEmail(request.auth?.token?.email), title: String(event.title ?? ""), slug: settings.slug,
      names: [...form.people.map((p) => p.name), ...others.map((d) => String(d.data().name ?? ""))]};
  });
  if (outcome.email && "names" in outcome) {
    const waiting = outcome.status === "waitlisted";
    await enqueueEmail(db(), {
      to: outcome.email, uid, eventId: eventRef.id,
      template: waiting ? "registrationWaitlisted" : "registrationConfirmation",
      data: {
        eventTitle: outcome.title, people: outcome.names!.map((n) => `• ${n}`).join("\n"),
        position: String(outcome.waitlistPosition ?? ""),
        link: `https://${hostingDomain()}/e/${outcome.slug}/registration`,
      },
    });
  }
  return {registrationId: outcome.registrationId, status: outcome.status, waitlistPosition: outcome.waitlistPosition};
}
