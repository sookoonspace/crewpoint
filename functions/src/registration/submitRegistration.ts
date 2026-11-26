import {onCall, HttpsError} from "firebase-functions/v2/https";
import {FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";
import {withStructuredLogs} from "../utils/logging";
import {enqueueEmail, normaliseEmail} from "../mail/outbox";
import {countryForTimeZone, normalisePhone} from "../participants/phone";
import {ageOn, CategoryDef, categoryForAge, FieldDef, filterTagsFor} from "../imports/plan";
import {expenseAccessOf} from "../events/expenseAccess";
import {memberDoc, memberRef, readEventRoles, rebuildMember} from "../events/members";
import {legacyRoleIds} from "../events/permissions";
import {hostingDomain} from "../account/signInLink";
import {normaliseSlug} from "./settings";
import {registrationOf} from "./registrationSettings";
import {allocate, AllocatedStatus} from "./allocate";
import {isShown} from "./conditions";
import {signUpChoices, validSignUps} from "./sessionChoices";
import {checkOpen} from "./registrationForm";

const db = () => getFirestore();

/** One person as the form sends them. */
interface PersonInput {
  name?: unknown;
  /** `YYYY-MM-DD`, or [age] when the event asks for age only. */
  birthDate?: unknown;
  age?: unknown;
  /** Standard and private answers together, by question ID. */
  answers?: unknown;
  /** Milliseconds since the epoch, with the Stay block. */
  arrivalAt?: unknown;
  departureAt?: unknown;
  /** Session IDs, with the Session choices block. */
  signUps?: unknown;
}

/** What `submitRegistration` returns, and returns again for a repeat. */
export interface SubmitResult {
  registrationId: string;
  status: AllocatedStatus;
  waitlistPosition: number | null;
}

type Reason = "noPeople" | "invalid" | "alreadyRegistered";

function refuse(code: "invalid-argument" | "already-exists",
  reason: Reason, message: string, extra: Record<string, unknown> = {}): never {
  throw new HttpsError(code, message, {reason, ...extra});
}

const DATE = /^\d{4}-\d{2}-\d{2}$/;
const isRecord = (v: unknown): v is Record<string, unknown> =>
  typeof v === "object" && v !== null && !Array.isArray(v);

/** Whether [value] is a valid answer to [field]; empty is checked apart. */
function validAnswer(field: FieldDef, value: unknown): boolean {
  switch (field.type) {
  case "text": return typeof value === "string" && value.length <= 2000;
  case "number": return typeof value === "number" && Number.isFinite(value);
  case "date": return typeof value === "string" && DATE.test(value);
  case "yesNo": return typeof value === "boolean";
  case "singleChoice": return typeof value === "string" && field.options.includes(value);
  case "multiChoice":
    return Array.isArray(value) && value.every((v) => typeof v === "string" && field.options.includes(v));
  default: return false;
  }
}

const isEmpty = (v: unknown) =>
  v === undefined || v === null || v === "" || (Array.isArray(v) && v.length === 0);

/** The event's first day as `YYYY-MM-DD`, for ages (Stage 1 categories). */
function firstDay(event: FirebaseFirestore.DocumentData): string {
  const start = event.startDate instanceof Timestamp ? event.startDate.toDate() : new Date();
  return start.toISOString().slice(0, 10);
}

/**
 * submitRegistration — a signed-in contact sends their group's registration
 * on an event open to anyone with the link (Spec #233 Req 1, 2, 4, 4a,
 * 17-22, 25, 32-33, 52, 60; #242). Reached by the event's link name, never
 * its ID.
 *
 * Idempotent by `submissionId`: a repeat returns the first result. In one
 * transaction with `registrationTally/current` (never a count query), the
 * whole group takes places (`submitted`, or `pending` when review is on)
 * or waits (`waitlisted`, with the next number); a group is never split.
 * It writes the registration, its group and its people as Participants,
 * the registration status mirrored onto both, private answers, birth dates
 * and contact details under each person's `private/details`, and a change
 * log entry. Questions a condition hides are dropped. A submitted contact
 * becomes a member with the event's registration role. The confirmation,
 * or the waitlist number, is emailed through the outbox.
 *
 * Refusals: `failed-precondition` `notOpen` (draft) or `closed` (ended,
 * archived, past the deadline); `permission-denied` `invitedOnly`;
 * `invalid-argument` `noPeople` or `invalid` with `problems`;
 * `already-exists` `alreadyRegistered` for a second registration (edits
 * come with #244).
 */
export const submitRegistration = onCall({timeoutSeconds: 60}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Must be signed in.");
  const data = isRecord(request.data) ? request.data : {};
  const slug = typeof data.slug === "string" ? normaliseSlug(data.slug) : null;
  const submissionId = typeof data.submissionId === "string" ? data.submissionId.trim() : "";
  if (!slug) throw new HttpsError("not-found", "We couldn't find this event.");
  if (!submissionId || submissionId.length > 100) {
    throw new HttpsError("invalid-argument", "A submission ID is required.");
  }

  return withStructuredLogs({op: "submitRegistration", uid, args: {slug, submissionId}}, async () => {
    const mapping = await db().collection("eventSlugs").doc(slug).get();
    const eventId = mapping.data()?.eventId;
    if (typeof eventId !== "string") throw new HttpsError("not-found", "We couldn't find this event.");
    const eventRef = db().collection("events").doc(eventId);

    // What the form needs to check answers; none of it changes capacity.
    const [fieldSnap, sessionSnap] = await Promise.all([
      eventRef.collection("fields").get(),
      eventRef.collection("sessions").get(),
    ]);
    const fields: FieldDef[] = fieldSnap.docs.map((d) => ({
      id: d.id,
      label: String(d.data().label ?? ""),
      type: String(d.data().type ?? "text"),
      options: Array.isArray(d.data().options) ? d.data().options : [],
      required: d.data().required === true,
      scope: String(d.data().scope ?? "participant"),
      visibility: String(d.data().visibility ?? "standard"),
    }));

    const outcome = await db().runTransaction(async (tx) => {
      const eventDoc = await tx.get(eventRef);
      if (!eventDoc.exists) throw new HttpsError("not-found", "We couldn't find this event.");
      const event = eventDoc.data()!;
      const settings = registrationOf(event);
      if (settings.slug !== slug) throw new HttpsError("not-found", "We couldn't find this event.");
      checkOpen(event, settings);

      const tallyRef = eventRef.collection("registrationTally").doc("current");
      const [existing, tallyDoc, memberSnap, roles] = await Promise.all([
        tx.get(eventRef.collection("registrations").where("contactUid", "==", uid).limit(1)),
        tx.get(tallyRef),
        tx.get(memberRef(eventRef, uid)),
        readEventRoles(tx, eventRef),
      ]);
      const previous = existing.docs[0];
      // A saved draft (#243) becomes the registration on the same document.
      const draftRef = previous?.data().status === "draft" ? previous.ref : null;
      if (previous && !draftRef) {
        const p = previous.data();
        if (p.lastSubmissionId === submissionId) {
          return {
            created: false,
            result: {registrationId: previous.id, status: p.status, waitlistPosition: p.waitlistPosition ?? null},
          };
        }
        refuse("already-exists", "alreadyRegistered", "You have already registered for this event.");
      }

      const form = readForm(data, {event, settings, fields, sessions: sessionSnap.docs});
      const tally = tallyDoc.data() ?? {};
      const placesUsed = typeof tally.placesUsed === "number" ? tally.placesUsed : 0;
      const nextWaitlist = typeof tally.nextWaitlist === "number" ? tally.nextWaitlist : 1;
      const held = Array.isArray(tally.offers) ?
        tally.offers.reduce((n: number, o: {size?: number}) => n + (o.size ?? 0), 0) : 0;
      const capacity = typeof event.capacity === "number" ? event.capacity : null;
      const decision = allocate({
        capacity, placesUsed, held, size: form.people.length, review: settings.review,
      });
      const waitlistPosition = decision.status === "waitlisted" ? nextWaitlist : null;

      const now = FieldValue.serverTimestamp();
      const registrationRef = draftRef ?? eventRef.collection("registrations").doc();
      const groupRef = eventRef.collection("groups").doc();
      const personRefs = form.people.map(() => eventRef.collection("participants").doc());
      const contactIndex = form.people.findIndex((p) => !p.isChild);
      const contactId = contactIndex >= 0 ? personRefs[contactIndex].id : null;

      tx.set(groupRef, {
        name: form.groupName, sortName: form.groupName.toLowerCase(), adultUids: [uid],
        fields: form.group.standard, filterTags: form.group.filterTags,
        registrationId: registrationRef.id, registrationStatus: decision.status,
        createdAt: now, updatedAt: now,
      });
      if (Object.keys(form.group.private).length > 0) {
        tx.set(groupRef.collection("private").doc("details"), {...form.group.private, updatedAt: now});
      }
      form.people.forEach((person, i) => {
        tx.set(personRefs[i], {
          name: person.name, sortName: person.name.toLowerCase(), groupId: groupRef.id,
          isChild: person.isChild, status: "active", categoryId: person.categoryId,
          fields: person.standard, filterTags: person.filterTags,
          ...(person.arrivalAt ? {arrivalAt: person.arrivalAt} : {}),
          ...(person.departureAt ? {departureAt: person.departureAt} : {}),
          ...(person.signUps.length ? {signUps: person.signUps} : {}),
          ...(i === contactIndex ? {uid} : {}),
          registrationId: registrationRef.id, registrationStatus: decision.status,
          createdAt: now, updatedAt: now,
        });
        const details = {
          ...person.private,
          ...(person.birthDate ? {birthDate: person.birthDate} : {}),
          ...(i === contactIndex && form.email ? {email: form.email} : {}),
          ...(i === contactIndex && form.phone ? {phone: form.phone} : {}),
        };
        if (Object.keys(details).length > 0) {
          tx.set(personRefs[i].collection("private").doc("details"), {...details, updatedAt: now});
        }
      });
      tx.set(registrationRef, {
        groupId: groupRef.id, contactUid: uid, status: decision.status, size: form.people.length,
        submittedAt: now, updatedAt: now, waitlistPosition, cancelReason: null, mergedInto: null,
        duplicateOf: null, extraGuestsAllowed: settings.extraGuests, lastSubmissionId: submissionId,
      });
      tx.set(registrationRef.collection("changes").doc(), {
        at: now, by: uid, action: "submitted", status: decision.status,
      });
      tx.set(tallyRef, {
        placesUsed: decision.placesUsed,
        nextWaitlist: waitlistPosition === null ? nextWaitlist : nextWaitlist + 1,
        updatedAt: now,
      }, {merge: true});

      // A submitted contact joins with the registration role (Req 60);
      // members keep their roles and gain it.
      if (decision.status === "submitted") {
        const memberIds: string[] = event.memberIds ?? [];
        const isMember = memberSnap.exists || memberIds.includes(uid);
        const current: FirebaseFirestore.DocumentData = memberSnap.exists ?
          memberSnap.data()! : {roleIds: isMember ? legacyRoleIds(event, uid) : []};
        const roleIds = [...new Set([...(current.roleIds ?? []), settings.registrationRoleId])];
        const groupIds = [...new Set([...(current.groupIds ?? []), groupRef.id])];
        const fields = {
          ...current, roleIds, groupIds, editsOwnGroup: true,
          participantId: current.participantId ?? contactId,
        };
        const access = expenseAccessOf(event);
        tx.set(memberRef(eventRef, uid), memberSnap.exists ?
          rebuildMember(uid, fields, roles, access) :
          memberDoc(uid, {roleIds, groupIds, editsOwnGroup: true, participantId: contactId}, roles, access));
        if (!isMember) {
          tx.update(eventRef, {
            memberIds: FieldValue.arrayUnion(uid), memberCount: memberIds.length + 1, updatedAt: now,
          });
        }
      }
      return {
        created: true,
        result: {registrationId: registrationRef.id, status: decision.status, waitlistPosition},
        email: form.email ?? normaliseEmail(request.auth?.token?.email),
        title: String(event.title ?? ""),
        names: form.people.map((p) => p.name),
      };
    });

    if (outcome.created && outcome.email) {
      const waiting = outcome.result.status === "waitlisted";
      await enqueueEmail(db(), {
        to: outcome.email,
        uid,
        template: waiting ? "registrationWaitlisted" : "registrationConfirmation",
        eventId,
        data: {
          eventTitle: outcome.title,
          people: outcome.names!.map((n) => `• ${n}`).join("\n"),
          position: String(outcome.result.waitlistPosition ?? ""),
          link: `https://${hostingDomain()}/e/${slug}/registration`,
        },
      });
    }
    return outcome.result as SubmitResult;
  });
});

interface ReadPerson {
  name: string;
  birthDate: string | null;
  isChild: boolean;
  categoryId: string | null;
  standard: Record<string, unknown>;
  private: Record<string, unknown>;
  filterTags: string[];
  arrivalAt: Timestamp | null;
  departureAt: Timestamp | null;
  signUps: string[];
}

/**
 * The form read and checked against the event's settings (Req 17, 18, 21,
 * 22): people, answers split into standard and private with hidden ones
 * dropped, stays, session choices and the contact's details. Throws
 * `invalid-argument` with the problems found.
 */
function readForm(data: Record<string, unknown>, {event, settings, fields, sessions}: {
  event: FirebaseFirestore.DocumentData;
  settings: ReturnType<typeof registrationOf>;
  fields: FieldDef[];
  sessions: FirebaseFirestore.QueryDocumentSnapshot[];
}) {
  const problems: string[] = [];
  const rawPeople = Array.isArray(data.people) ? data.people as PersonInput[] : [];
  if (rawPeople.length === 0) refuse("invalid-argument", "noPeople", "Add at least one person.");
  if (rawPeople.length > 50) problems.push("people");
  const categories: CategoryDef[] = Array.isArray(event.settings?.categories) ? event.settings.categories : [];
  const on = firstDay(event);
  // Only questions in a section are asked (Req 16).
  const asked = new Set(settings.sections.flatMap((s) => s.fieldIds));
  const participantFields = fields.filter((f) => f.scope === "participant" && asked.has(f.id));
  const choices = signUpChoices(event.settings?.attendancePolicy, sessions.map((s) => ({
    id: s.id,
    startAt: (s.data().startAt as Timestamp).toMillis(),
    endAt: s.data().endAt instanceof Timestamp ? (s.data().endAt as Timestamp).toMillis() : null,
    attendance: s.data().attendance ?? null,
    hidden: s.data().hidden === true,
  })));
  const time = (v: unknown, at: string) => {
    if (v === undefined || v === null) return null;
    if (typeof v !== "number" || !Number.isFinite(v)) {
      problems.push(at);
      return null;
    }
    return Timestamp.fromMillis(v);
  };

  const people: ReadPerson[] = rawPeople.map((raw, i) => {
    const at = `people.${i}`;
    const name = typeof raw?.name === "string" ? raw.name.trim().replace(/\s+/g, " ") : "";
    if (!name || name.length > 200) problems.push(`${at}.name`);
    let birthDate: string | null = null;
    let age: number | null = null;
    if (settings.blocks.ageOnly) {
      if (typeof raw.age === "number" && Number.isInteger(raw.age) && raw.age >= 0 && raw.age <= 130) {
        age = raw.age;
      } else if (settings.blocks.people) {
        problems.push(`${at}.age`);
      }
    } else if (typeof raw.birthDate === "string" && DATE.test(raw.birthDate)) {
      birthDate = raw.birthDate;
      age = ageOn(birthDate, on);
    } else if (settings.blocks.people) {
      problems.push(`${at}.birthDate`);
    }
    const category = age === null ? null : categoryForAge(age, categories);
    const answers = isRecord(raw.answers) ? raw.answers : {};
    const standard: Record<string, unknown> = {};
    const privateAnswers: Record<string, unknown> = {};
    for (const field of participantFields) {
      const shown = isShown(settings.conditions[field.id], {categoryId: category?.id ?? null, answers});
      const value = answers[field.id];
      if (!shown) continue;
      if (isEmpty(value)) {
        if (field.required) problems.push(`${at}.${field.id}`);
        continue;
      }
      if (!validAnswer(field, value)) {
        problems.push(`${at}.${field.id}`);
        continue;
      }
      (field.visibility === "private" ? privateAnswers : standard)[field.id] = value;
    }
    const signUps = settings.blocks.sessionChoices && Array.isArray(raw.signUps) ?
      [...new Set(raw.signUps.filter((s): s is string => typeof s === "string"))] : [];
    if (!validSignUps(choices, signUps)) problems.push(`${at}.signUps`);
    const arrivalAt = settings.blocks.stay ? time(raw.arrivalAt, `${at}.arrivalAt`) : null;
    const departureAt = settings.blocks.stay ? time(raw.departureAt, `${at}.departureAt`) : null;
    if (arrivalAt && departureAt && departureAt.toMillis() < arrivalAt.toMillis()) {
      problems.push(`${at}.departureAt`);
    }
    return {
      name, birthDate, isChild: category?.isChild === true, categoryId: category?.id ?? null,
      standard, private: privateAnswers, filterTags: filterTagsFor(fields, standard),
      arrivalAt, departureAt, signUps,
    };
  });

  // The group's own questions, asked once (Req 16): conditions read the
  // group's answers only.
  const groupAnswers = isRecord(data.groupAnswers) ? data.groupAnswers : {};
  const group = {standard: {} as Record<string, unknown>, private: {} as Record<string, unknown>, filterTags: [] as string[]};
  for (const field of fields.filter((f) => f.scope === "group" && asked.has(f.id))) {
    if (!isShown(settings.conditions[field.id], {categoryId: null, answers: groupAnswers})) continue;
    const value = groupAnswers[field.id];
    if (isEmpty(value)) {
      if (field.required) problems.push(`group.${field.id}`);
      continue;
    }
    if (!validAnswer(field, value)) {
      problems.push(`group.${field.id}`);
      continue;
    }
    (field.visibility === "private" ? group.private : group.standard)[field.id] = value;
  }
  group.filterTags = filterTagsFor(fields, group.standard, "group");

  const contact = isRecord(data.contact) ? data.contact : {};
  let email: string | null = null;
  let phone: string | null = null;
  if (settings.blocks.contact) {
    if (!isEmpty(contact.email)) {
      email = normaliseEmail(contact.email);
      if (!email) problems.push("contact.email");
    }
    if (!isEmpty(contact.phone)) {
      phone = typeof contact.phone === "string" ?
        normalisePhone(contact.phone, countryForTimeZone(event.timeZone)) : null;
      if (!phone) problems.push("contact.phone");
    }
  }
  const rawGroupName = typeof data.groupName === "string" ? data.groupName.trim() : "";
  const groupName = (rawGroupName || people[0]?.name || "").slice(0, 200);
  if (problems.length > 0) {
    refuse("invalid-argument", "invalid", "Some answers need checking.", {problems});
  }
  return {people, email, phone, groupName, group};
}
