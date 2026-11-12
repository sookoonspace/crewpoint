import {onCall, HttpsError} from "firebase-functions/v2/https";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {requireString, withStructuredLogs} from "../utils/logging";
import {requirePermission} from "./members";
import {TemplateField, templateFromEvent} from "./templates";

const MAX_NAME = 60;
const MAX_TEMPLATES = 50;

/**
 * saveAsTemplate — keeps an event's configuration as the caller's own
 * template in `users/{uid}/templates/{id}` (Req 65), which only they read.
 * Configuration only: never people, money or messages. Needs `event.manage`.
 */
export const saveAsTemplate = onCall({timeoutSeconds: 30}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Must be signed in.");
  const uid = request.auth.uid;
  const data = (request.data ?? {}) as Record<string, unknown>;
  const eventId = requireString(data.eventId, "eventId");
  const name = typeof data.name === "string" ? data.name.trim() : "";
  if (name.length === 0 || name.length > MAX_NAME) {
    throw new HttpsError("invalid-argument", `A template name needs 1 to ${MAX_NAME} characters.`);
  }
  return withStructuredLogs({op: "saveAsTemplate", uid, args: {eventId}}, async () => {
    const db = getFirestore();
    const eventRef = db.collection("events").doc(eventId);
    const event = await eventRef.get();
    if (!event.exists) throw new HttpsError("not-found", "Event not found.");
    await requirePermission(null, eventRef, event.data()!, uid, "event.manage",
      "Only organizers can save an event as a template.");
    const mine = db.collection("users").doc(uid).collection("templates");
    if ((await mine.count().get()).data().count >= MAX_TEMPLATES) {
      throw new HttpsError("resource-exhausted", `You can keep up to ${MAX_TEMPLATES} templates.`);
    }
    const [fields, roles] = await Promise.all([
      eventRef.collection("fields").get(),
      eventRef.collection("roles").get(),
    ]);
    const ref = mine.doc();
    const template = templateFromEvent({
      id: ref.id,
      name,
      event: event.data()!,
      fields: fields.docs.map((d) => ({id: d.id, ...d.data()}) as TemplateField),
      roles: Object.fromEntries(roles.docs.map((d) => [d.id, d.data()])),
    });
    await ref.set({...template, savedFrom: eventId, createdAt: FieldValue.serverTimestamp()});
    return {templateId: ref.id};
  });
});
