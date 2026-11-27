import {createHash} from "crypto";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";
import {withStructuredLogs} from "../utils/logging";
import {normaliseEmail} from "../mail/outbox";
import {countryForTimeZone, normalisePhone} from "../participants/phone";
import {registrationOf} from "./registrationSettings";
import {eventBySlug} from "./registrationForm";
import {loadFormInputs, privateDetails, readForm} from "./submitRegistration";
import {offerOnwardNow} from "./offers";
import {acceptedAs, acceptedOf, requiredProblems, writeAcceptances} from "./waiverAcceptance";
import {diffRegistration, FieldChange, PersonSnapshot, RegistrationSnapshot} from "./changeLog";

const db = () => getFirestore();

const NO_ROOM = "There's no room to add more people. Please contact the organizer.";
const CLOSED = "Registration is closed. Please contact the organizer to make changes.";

const isRecord = (v: unknown): v is Record<string, unknown> =>
  typeof v === "object" && v !== null && !Array.isArray(v);
const millis = (v: unknown): number | null => (v instanceof Timestamp ? v.toMillis() : null);

/** Kept out of the log's values: these show only as "changed" (Req 22). */
const PRIVATE_MARK = "private:";
const hidden = (v: unknown) =>
  v === undefined || v === null ? null : PRIVATE_MARK + createHash("sha256").update(JSON.stringify(v)).digest("hex");

/** The log's entries, private values replaced by `null` and `private: true`. */
function logged(changes: FieldChange[]): Array<FieldChange & {private?: boolean}> {
  return changes.map((c) => {
    const isPrivate = [c.before, c.after].some((v) => typeof v === "string" && v.startsWith(PRIVATE_MARK));
    return isPrivate ? {...c, before: null, after: null, private: true} : c;
  });
}

/**
 * updateRegistration — the contact or a linked adult changes their group's
 * registration (Spec #233 Req 32a, 35, 36; #244, B-02, B-03, B-06, B-13),
 * by the event's link name, sending the whole form as `submitRegistration`
 * takes it, existing people with their `id`.
 *
 * Before the deadline anything may change: people added, removed or
 * edited (names, birth dates, answers, arrival and departure times, session
 * sign-ups and meal opt-outs), the group's answers and the contact details.
 * Adding people to a submitted or pending group needs room in
 * `registrationTally/current`, else `failed-precondition` `noRoom` with
 * "There's no room to add more people. Please contact the organizer." and
 * nothing changes; removing people frees their places. A waitlisted group
 * holds no places and may grow. After the deadline only the contact
 * details may change; anything else is `failed-precondition` `closed`, as
 * is every change on an ended or archived event.
 *
 * Every change is logged in `changes/{id}` (`action: "edited"`, who, when,
 * and each field before and after from `diffRegistration`); private
 * answers, birth dates and contact details are logged as changed without
 * their values. Returns how many fields changed.
 */
export const updateRegistration = onCall({timeoutSeconds: 60}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Must be signed in.");
  const data = isRecord(request.data) ? request.data : {};

  return withStructuredLogs({op: "updateRegistration", uid, args: {slug: data.slug}}, async () => {
    const {slug, ref: eventRef} = await eventBySlug(data.slug);
    const {fields, sessions, waivers: allWaivers} = await loadFormInputs(eventRef);
    const privateFields = new Set(fields.filter((f) => f.visibility === "private").map((f) => f.id));

    const result = await db().runTransaction(async (tx) => {
      const eventDoc = await tx.get(eventRef);
      if (!eventDoc.exists) throw new HttpsError("not-found", "We couldn't find this event.");
      const event = eventDoc.data()!;
      const settings = registrationOf(event);
      if (settings.slug !== slug) throw new HttpsError("not-found", "We couldn't find this event.");

      // The caller's registration, as its contact or a linked adult.
      const member = await tx.get(eventRef.collection("members").doc(uid));
      const groupIds: string[] = Array.isArray(member.data()?.groupIds) ? member.data()!.groupIds.slice(0, 10) : [];
      const asContact = await tx.get(eventRef.collection("registrations").where("contactUid", "==", uid).limit(1));
      let regDoc = asContact.docs.find((d) => d.data().status !== "draft");
      if (!regDoc && groupIds.length > 0) {
        const asAdult = await tx.get(eventRef.collection("registrations").where("groupId", "in", groupIds).limit(1));
        regDoc = asAdult.docs[0];
      }
      if (!regDoc) throw new HttpsError("not-found", "You haven't registered for this event.");
      const reg = regDoc.data();
      const refuseClosed = (): never => {
        throw new HttpsError("failed-precondition", CLOSED, {reason: "closed"});
      };
      if (["ended", "archived"].includes(event.status) || reg.status === "cancelled") refuseClosed();
      const pastDeadline = settings.deadline !== null && Date.now() > settings.deadline;

      // The registration as it stands.
      const groupRef = eventRef.collection("groups").doc(String(reg.groupId));
      const tallyRef = eventRef.collection("registrationTally").doc("current");
      const [groupDoc, groupPrivate, peopleSnap, tallyDoc] = await Promise.all([
        tx.get(groupRef),
        tx.get(groupRef.collection("private").doc("details")),
        tx.get(eventRef.collection("participants").where("registrationId", "==", regDoc.id)),
        tx.get(tallyRef),
      ]);
      const privates = await Promise.all(peopleSnap.docs.map((d) => tx.get(d.ref.collection("private").doc("details"))));
      const contactDoc = peopleSnap.docs.find((d) => d.data().uid === reg.contactUid) ?? null;
      const beforePeople: Record<string, PersonSnapshot> = {};
      peopleSnap.docs.forEach((d, i) => {
        const p = d.data();
        const {birthDate, fields: privateAnswers, photoConsent} = privates[i].data() ?? {};
        beforePeople[d.id] = {
          name: String(p.name ?? ""),
          birthDate: hidden(birthDate),
          answers: {
            ...(p.fields ?? {}),
            ...Object.fromEntries(Object.entries(privateAnswers ?? {}).map(([k, v]) => [k, hidden(v)])),
            ...(typeof photoConsent === "boolean" ? {photoConsent: hidden(photoConsent)} : {}),
          },
          arrivalAt: millis(p.arrivalAt),
          departureAt: millis(p.departureAt),
          signUps: p.signUps ?? [],
          optOuts: p.optOuts ?? [],
        };
      });
      const contactDetails = contactDoc ? privates[peopleSnap.docs.indexOf(contactDoc)].data() ?? {} : {};
      const groupPrivateAnswers: Record<string, unknown> = groupPrivate.data()?.fields ?? {};
      const before: RegistrationSnapshot = {
        groupName: String(groupDoc.data()?.name ?? ""),
        email: hidden(contactDetails.email ?? null),
        phone: hidden(contactDetails.phone ?? null),
        groupAnswers: {
          ...(groupDoc.data()?.fields ?? {}),
          ...Object.fromEntries(Object.entries(groupPrivateAnswers).map(([k, v]) => [k, hidden(v)])),
        },
        people: beforePeople,
      };

      // The contact details as sent, checked like the form's.
      const contact = isRecord(data.contact) ? data.contact : {};
      const email = contact.email === undefined || contact.email === "" ? null : normaliseEmail(contact.email);
      const phone = typeof contact.phone === "string" && contact.phone.trim() ?
        normalisePhone(contact.phone, countryForTimeZone(event.timeZone)) : null;
      if ((contact.email && !email) || (typeof contact.phone === "string" && contact.phone.trim() && !phone)) {
        throw new HttpsError("invalid-argument", "Some answers need checking.",
          {reason: "invalid", problems: ["contact"]});
      }
      const now = FieldValue.serverTimestamp();

      if (pastDeadline) {
        // After the deadline: only the contact details (Req 35, B-13).
        const form = readForm(data, {event, settings, fields, sessions});
        const after = snapshotOf(form, before, privateFields, email, phone);
        const changes = diffRegistration(before, after);
        if (changes.some((c) => c.field !== "email" && c.field !== "phone")) refuseClosed();
        if (changes.length > 0 && contactDoc) {
          tx.set(contactDoc.ref.collection("private").doc("details"), {
            email: email ?? FieldValue.delete(), phone: phone ?? FieldValue.delete(), updatedAt: now,
          }, {merge: true});
          tx.set(regDoc.ref.collection("changes").doc(), {at: now, by: uid, action: "edited", changes: logged(changes)});
          tx.update(regDoc.ref, {updatedAt: now});
        }
        return {registrationId: regDoc.id, status: reg.status, changed: changes.length};
      }

      const form = readForm(data, {event, settings, fields, sessions});
      const known = new Set(peopleSnap.docs.map((d) => d.id));
      if (form.people.some((p) => p.id !== null && !known.has(p.id))) {
        throw new HttpsError("invalid-argument", "Some answers need checking.",
          {reason: "invalid", problems: ["people.id"]});
      }
      // Required waivers (Req 29, #246), counting what each person accepted.
      const waivers = settings.blocks.waivers ? allWaivers : [];
      const recordOf = (id: string | null) => peopleSnap.docs.find((d) => d.id === id)?.data();
      const missingRequired = requiredProblems(form.people, waivers, (i) => acceptedOf(recordOf(form.people[i].id)));
      if (missingRequired.length > 0) {
        throw new HttpsError("invalid-argument", "Some answers need checking.",
          {reason: "invalid", problems: missingRequired});
      }
      // New people get their IDs now, so the log can name them.
      const ids = form.people.map((p) => p.id ?? eventRef.collection("participants").doc().id);
      const after = snapshotOf(form, before, privateFields, email, phone, ids);
      const changes = diffRegistration(before, after);
      if (changes.length === 0) return {registrationId: regDoc.id, status: reg.status, changed: 0};

      // Places (Req 32a): more people need room; fewer free theirs.
      const delta = form.people.length - peopleSnap.size;
      if (["submitted", "pending"].includes(reg.status) && delta !== 0) {
        const tally = tallyDoc.data() ?? {};
        const used = typeof tally.placesUsed === "number" ? tally.placesUsed : 0;
        const held = Array.isArray(tally.offers) ?
          tally.offers.reduce((n: number, o: {size?: number}) => n + (o.size ?? 0), 0) : 0;
        const capacity = typeof event.capacity === "number" ? event.capacity : null;
        if (delta > 0 && capacity !== null && used + held + delta > capacity) {
          throw new HttpsError("failed-precondition", NO_ROOM, {reason: "noRoom"});
        }
        tx.set(tallyRef, {placesUsed: Math.max(0, used + delta), updatedAt: now}, {merge: true});
      }

      const keep = new Set(ids);
      for (const d of peopleSnap.docs) {
        if (keep.has(d.id)) continue;
        tx.delete(d.ref.collection("private").doc("details"));
        tx.delete(d.ref.collection("private").doc("waivers"));
        tx.delete(d.ref);
      }
      form.people.forEach((person, i) => {
        const ref = eventRef.collection("participants").doc(ids[i]);
        const isContact = contactDoc?.id === ids[i];
        const record = recordOf(person.id);
        const waiverState = writeAcceptances(tx, ref, {
          accepting: person.acceptWaivers, accepted: acceptedOf(record), waivers, person, by: uid,
          as: acceptedAs({isChild: person.isChild, uid: record?.uid ?? null}, uid),
        });
        const fieldsNow = {
          ...waiverState,
          name: person.name, sortName: person.name.toLowerCase(), isChild: person.isChild,
          categoryId: person.categoryId, fields: person.standard, filterTags: person.filterTags,
          arrivalAt: person.arrivalAt ?? FieldValue.delete(),
          departureAt: person.departureAt ?? FieldValue.delete(),
          signUps: person.signUps.length ? person.signUps : FieldValue.delete(),
          optOuts: person.optOuts.length ? person.optOuts : FieldValue.delete(),
          updatedAt: now,
        };
        if (person.id) {
          tx.update(ref, fieldsNow);
        } else {
          tx.set(ref, {
            ...Object.fromEntries(Object.entries(fieldsNow).filter(([, v]) => !(v instanceof FieldValue))),
            groupId: groupRef.id, status: "active", registrationId: regDoc!.id,
            registrationStatus: reg.status, createdAt: now,
          });
        }
        tx.set(ref.collection("private").doc("details"), {
          ...privateDetails(person),
          ...(person.birthDate ? {birthDate: person.birthDate} : {}),
          ...(isContact && email ? {email} : {}),
          ...(isContact && phone ? {phone} : {}),
          updatedAt: now,
        });
      });
      tx.update(groupRef, {
        name: form.groupName, sortName: form.groupName.toLowerCase(),
        fields: form.group.standard, filterTags: form.group.filterTags, updatedAt: now,
      });
      tx.set(groupRef.collection("private").doc("details"), {fields: form.group.private, updatedAt: now});
      tx.update(regDoc.ref, {size: form.people.length, updatedAt: now});
      tx.set(regDoc.ref.collection("changes").doc(), {at: now, by: uid, action: "edited", changes: logged(changes)});
      return {registrationId: regDoc.id, status: reg.status, changed: changes.length};
    });
    // Fewer people free places for the waitlist (Req 32a, #248).
    if (result.changed > 0) await offerOnwardNow(db(), eventRef.id);
    return result;
  });
});

/** The form as a snapshot to compare, private values hidden like [before]. */
function snapshotOf(
  form: ReturnType<typeof readForm>,
  before: RegistrationSnapshot,
  privateFields: Set<string>,
  email: string | null,
  phone: string | null,
  ids?: string[]
): RegistrationSnapshot {
  const people: Record<string, PersonSnapshot> = {};
  form.people.forEach((p, i) => {
    const id = ids?.[i] ?? p.id ?? `new-${i}`;
    people[id] = {
      name: p.name,
      birthDate: hidden(p.birthDate),
      answers: {
        ...p.standard,
        ...Object.fromEntries(Object.entries(p.private).map(([k, v]) => [k, privateFields.has(k) ? hidden(v) : v])),
        ...(p.photoConsent === null ? {} : {photoConsent: hidden(p.photoConsent)}),
      },
      arrivalAt: p.arrivalAt?.toMillis() ?? null,
      departureAt: p.departureAt?.toMillis() ?? null,
      signUps: p.signUps,
      optOuts: p.optOuts,
    };
  });
  return {
    groupName: form.groupName || before.groupName,
    email: hidden(email),
    phone: hidden(phone),
    groupAnswers: {
      ...form.group.standard,
      ...Object.fromEntries(Object.entries(form.group.private).map(([k, v]) => [k, hidden(v)])),
    },
    people,
  };
}
