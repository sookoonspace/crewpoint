import {onCall, HttpsError} from "firebase-functions/v2/https";
import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {withStructuredLogs} from "../utils/logging";
import {normaliseSlug} from "./settings";
import {registrationOf} from "./registrationSettings";
import {signUpChoices} from "./sessionChoices";

const db = () => getFirestore();

/** Why registering is refused now, as `details.reason`. */
export type GateReason = "notOpen" | "closed" | "invitedOnly";

/**
 * Throws unless an event registers by its link now (Spec #233 Req 8, 14,
 * 35): published or live, before its deadline, open to anyone with the
 * link. Shared by the form and the submit, so they never disagree.
 */
export function checkOpen(event: FirebaseFirestore.DocumentData, settings: ReturnType<typeof registrationOf>): void {
  const refuse = (code: "failed-precondition" | "permission-denied", reason: GateReason, message: string) => {
    throw new HttpsError(code, message, {reason});
  };
  if (event.status === "draft") refuse("failed-precondition", "notOpen", "Registration isn't open yet.");
  if (!["published", "live"].includes(event.status) ||
    (settings.deadline !== null && Date.now() > settings.deadline)) {
    refuse("failed-precondition", "closed", "Registration is closed.");
  }
  if (settings.mode !== "open") {
    refuse("permission-denied", "invitedOnly", "This event registers by personal link only.");
  }
}

/** The event a link name leads to, or `not-found`. */
export async function eventBySlug(rawSlug: unknown): Promise<{
  slug: string;
  ref: FirebaseFirestore.DocumentReference;
}> {
  const slug = typeof rawSlug === "string" ? normaliseSlug(rawSlug) : null;
  const mapping = slug ? await db().collection("eventSlugs").doc(slug).get() : null;
  const eventId = mapping?.data()?.eventId;
  if (!slug || typeof eventId !== "string") throw new HttpsError("not-found", "We couldn't find this event.");
  return {slug, ref: db().collection("events").doc(eventId)};
}

const millis = (v: unknown): number | null => (v instanceof Timestamp ? v.toMillis() : null);

/**
 * getRegistrationForm — what the registration form needs (Spec #233 Req
 * 16-18, 20; #242), for a signed-in visitor who need not be a member yet,
 * by the event's link name: its title, dates and time zone, the blocks,
 * the sections and only the questions in them, conditions, categories,
 * the session choices (by-sign-up sessions at the same time as one
 * either/or), its words, and the caller's registration if they have one.
 * Never the event's ID. Refuses as `submitRegistration` does.
 */
export const getRegistrationForm = onCall({timeoutSeconds: 30}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Must be signed in.");
  const data = (request.data ?? {}) as {slug?: unknown};
  return withStructuredLogs({op: "getRegistrationForm", uid, args: {slug: data.slug}}, async () => {
    const {slug, ref} = await eventBySlug(data.slug);
    const eventDoc = await ref.get();
    if (!eventDoc.exists) throw new HttpsError("not-found", "We couldn't find this event.");
    const event = eventDoc.data()!;
    const settings = registrationOf(event);
    if (settings.slug !== slug) throw new HttpsError("not-found", "We couldn't find this event.");

    const [fieldSnap, sessionSnap, mine, member] = await Promise.all([
      ref.collection("fields").get(),
      ref.collection("sessions").get(),
      ref.collection("registrations").where("contactUid", "==", uid).limit(1).get(),
      ref.collection("members").doc(uid).get(),
    ]);
    // Their registration, as its contact or a linked adult (#244).
    let registered = mine.docs.find((d) => !["draft", "cancelled"].includes(d.data().status));
    const groupIds: string[] = Array.isArray(member.data()?.groupIds) ? member.data()!.groupIds.slice(0, 10) : [];
    if (!registered && groupIds.length > 0) {
      const asAdult = await ref.collection("registrations").where("groupId", "in", groupIds).limit(1).get();
      registered = asAdult.docs.find((d) => d.data().status !== "cancelled");
    }
    // Someone registered may still change contact details after the
    // deadline (Req 35); everyone else needs registration open.
    let editable: "all" | "contact" | null = null;
    if (registered) {
      if (["ended", "archived"].includes(event.status)) {
        throw new HttpsError("failed-precondition", "Registration is closed.", {reason: "closed"});
      }
      editable = settings.deadline !== null && Date.now() > settings.deadline ? "contact" : "all";
    } else {
      checkOpen(event, settings);
    }
    const asked = new Set(settings.sections.flatMap((s) => s.fieldIds));
    const fields = fieldSnap.docs
      .filter((d) => asked.has(d.id))
      .sort((a, b) => (Number(a.data().order ?? 0) - Number(b.data().order ?? 0)) || a.id.localeCompare(b.id))
      .map((d) => {
        const f = d.data();
        return {
          id: d.id,
          label: String(f.label ?? ""),
          type: String(f.type ?? "text"),
          options: Array.isArray(f.options) ? f.options : [],
          required: f.required === true,
          scope: f.scope === "group" ? "group" : "participant",
          visibility: f.visibility === "private" ? "private" : "standard",
        };
      });
    const sessions = sessionSnap.docs.map((d) => ({id: d.id, ...d.data()}) as {
      id: string; title?: string; startAt: Timestamp; endAt?: Timestamp | null;
      attendance?: string | null; hidden?: boolean;
    });
    const byId = new Map(sessions.map((s) => [s.id, s]));
    const choices = settings.blocks.sessionChoices ?
      signUpChoices(event.settings?.attendancePolicy, sessions.map((s) => ({
        id: s.id, startAt: s.startAt.toMillis(), endAt: millis(s.endAt),
        attendance: s.attendance ?? null, hidden: s.hidden === true,
      }))).map((ids) => ids.map((id) => {
        const s = byId.get(id)!;
        return {id, title: String(s.title ?? ""), startAt: s.startAt.toMillis(), endAt: millis(s.endAt)};
      })) : [];
    const mineData = mine.docs[0]?.data();
    const isDraft = mineData?.status === "draft";
    const registration = registered?.data();
    const current = registered ? await currentRegistration(ref, registered) : null;
    // Sessions everyone attends, which a person may opt out of (#244, B-03).
    const policy = event.settings?.attendancePolicy;
    const attending = settings.blocks.sessionChoices ? sessions
      .filter((s) => s.hidden !== true && (s.attendance ?? policy) !== "bySession")
      .sort((a, b) => a.startAt.toMillis() - b.startAt.toMillis() || a.id.localeCompare(b.id))
      .map((s) => ({id: s.id, title: String(s.title ?? ""), startAt: s.startAt.toMillis(), endAt: millis(s.endAt)})) :
      [];

    return {
      slug,
      title: String(event.title ?? ""),
      timeZone: typeof event.timeZone === "string" ? event.timeZone : "UTC",
      startDate: millis(event.startDate),
      endDate: millis(event.endDate),
      dateOnly: event.dateOnly === true,
      deadline: settings.deadline,
      review: settings.review,
      blocks: settings.blocks,
      sections: settings.sections,
      conditions: settings.conditions,
      categories: Array.isArray(event.settings?.categories) ? event.settings.categories : [],
      fields,
      choices,
      labels: event.labels ?? {},
      registration: registration ?
        {status: registration.status, waitlistPosition: registration.waitlistPosition ?? null} : null,
      attending,
      editable,
      current,
      contactLine: settings.contactLine,
      // Waivers to read and accept (#246), with each one's current version.
      waivers: settings.blocks.waivers ? await waiverList(ref) : [],
      // The server copy of the form as typed (#243), to restore when newer.
      draft: isDraft ? {data: mineData!.draft ?? {}, savedAt: mineData!.draftSavedAt ?? 0} : null,
    };
  });
});

/**
 * A registration as the form edits it (#244): its people with their IDs,
 * answers (private ones too, which the family may read), times, sign-ups
 * and opt-outs, the group's answers and the contact details.
 */
async function currentRegistration(
  eventRef: FirebaseFirestore.DocumentReference,
  registration: FirebaseFirestore.QueryDocumentSnapshot
) {
  const r = registration.data();
  const groupRef = eventRef.collection("groups").doc(String(r.groupId));
  const [group, groupPrivate, people] = await Promise.all([
    groupRef.get(),
    groupRef.collection("private").doc("details").get(),
    eventRef.collection("participants").where("registrationId", "==", registration.id).get(),
  ]);
  const sorted = [...people.docs].sort((a, b) =>
    (millis(a.data().createdAt) ?? 0) - (millis(b.data().createdAt) ?? 0) || a.id.localeCompare(b.id));
  const privates = await Promise.all(sorted.map((d) => d.ref.collection("private").doc("details").get()));
  let email: string | null = null;
  let phone: string | null = null;
  const list = sorted.map((d, i) => {
    const p = d.data();
    const {birthDate, email: e, phone: ph, photoConsent, fields: privateAnswers} = privates[i].data() ?? {};
    if (p.uid === r.contactUid) {
      email = typeof e === "string" ? e : null;
      phone = typeof ph === "string" ? ph : null;
    }
    return {
      id: d.id,
      name: String(p.name ?? ""),
      birthDate: typeof birthDate === "string" ? birthDate : null,
      age: null,
      answers: {...(p.fields ?? {}), ...(privateAnswers ?? {})},
      arrivalAt: millis(p.arrivalAt),
      departureAt: millis(p.departureAt),
      signUps: p.signUps ?? [],
      optOuts: p.optOuts ?? [],
      waiverVersions: p.waiverVersions ?? {},
      photoConsent: typeof photoConsent === "boolean" ? photoConsent : null,
    };
  });
  const groupPrivateAnswers: Record<string, unknown> = groupPrivate.data()?.fields ?? {};
  return {
    groupName: String(group.data()?.name ?? ""),
    email,
    phone,
    groupAnswers: {...(group.data()?.fields ?? {}), ...groupPrivateAnswers},
    people: list,
  };
}

/** The event's waivers as the app shows them (#246), oldest first. */
export async function waiverList(eventRef: FirebaseFirestore.DocumentReference) {
  const snap = await eventRef.collection("waivers").get();
  return snap.docs
    .sort((a, b) => (millis(a.data().createdAt) ?? 0) - (millis(b.data().createdAt) ?? 0) || a.id.localeCompare(b.id))
    .map((d) => {
      const w = d.data();
      return {
        id: d.id, title: w.title ?? {en: ""}, text: w.text ?? {en: ""}, version: w.version ?? 1,
        appliesTo: w.appliesTo ?? {kind: "everyone"}, required: w.required === true,
        requireLatest: w.requireLatest !== false,
      };
    });
}
