import {onCall, HttpsError} from "firebase-functions/v2/https";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {withStructuredLogs} from "../utils/logging";
import {registrationOf} from "./registrationSettings";
import {checkOpen, eventBySlug} from "./registrationForm";

const db = () => getFirestore();

/** A draft is the form as typed; this keeps it to a sensible size. */
const MAX_DRAFT_BYTES = 100_000;

/**
 * saveRegistrationDraft — the server copy of a registration form as typed
 * (Spec #233 Req 23-25, TD 8; #243), for the signed-in contact, by slug:
 * one `registrations` document per contact with status `draft`, the form
 * in `draft` and the device's time in `draftSavedAt`. An older copy never
 * replaces a newer one; the reply says which time is kept. Drafts take no
 * places and write no Participants; Submit turns the draft into the
 * registration on the same document. Refused like the form when the event
 * is not open, and with `already-exists` (`alreadyRegistered`) once sent.
 */
export const saveRegistrationDraft = onCall({timeoutSeconds: 30}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Must be signed in.");
  const data = (request.data ?? {}) as {slug?: unknown; draft?: unknown; savedAt?: unknown};
  const draft = data.draft;
  const savedAt = data.savedAt;
  if (typeof draft !== "object" || draft === null || Array.isArray(draft) ||
    typeof savedAt !== "number" || !Number.isFinite(savedAt)) {
    throw new HttpsError("invalid-argument", "A draft and the time it was saved are required.");
  }
  if (JSON.stringify(draft).length > MAX_DRAFT_BYTES) {
    throw new HttpsError("invalid-argument", "This draft is too large.");
  }

  return withStructuredLogs({op: "saveRegistrationDraft", uid, args: {slug: data.slug, savedAt}}, async () => {
    const {slug, ref} = await eventBySlug(data.slug);
    return db().runTransaction(async (tx) => {
      const eventDoc = await tx.get(ref);
      if (!eventDoc.exists) throw new HttpsError("not-found", "We couldn't find this event.");
      const event = eventDoc.data()!;
      const settings = registrationOf(event);
      if (settings.slug !== slug) throw new HttpsError("not-found", "We couldn't find this event.");
      checkOpen(event, settings);

      const mine = await tx.get(ref.collection("registrations").where("contactUid", "==", uid).limit(1));
      const existing = mine.docs[0];
      if (existing && existing.data().status !== "draft") {
        throw new HttpsError("already-exists", "You have already registered for this event.",
          {reason: "alreadyRegistered"});
      }
      const kept = existing?.data().draftSavedAt;
      if (typeof kept === "number" && kept > savedAt) return {savedAt: kept};

      const now = FieldValue.serverTimestamp();
      tx.set(existing?.ref ?? ref.collection("registrations").doc(), {
        contactUid: uid, groupId: null, status: "draft", draft, draftSavedAt: savedAt, updatedAt: now,
        ...(existing ? {} : {createdAt: now}),
      }, {merge: true});
      return {savedAt};
    });
  });
});
