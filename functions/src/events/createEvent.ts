import {onCall, HttpsError} from "firebase-functions/v2/https";
import {expenseAccessOf} from "./expenseAccess";
import {FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";
import {requireString, withStructuredLogs} from "../utils/logging";
import {preparePersonalOrganizer} from "./organizers";
import {memberDoc, memberRef} from "./members";
import {PRESET_ROLES} from "./permissions";
import {systemTemplate} from "./templates";

const db = getFirestore();

function invalid(message: string): HttpsError {
  return new HttpsError("invalid-argument", message);
}

function optionalString(value: unknown, field: string): string | null {
  if (value === undefined || value === null) return null;
  if (typeof value !== "string") throw invalid(`${field} must be text.`);
  return value;
}

function optionalDate(value: unknown, field: string): Timestamp | null {
  const text = optionalString(value, field);
  if (text === null) return null;
  const date = new Date(text);
  if (Number.isNaN(date.getTime())) throw invalid(`${field} is not a date.`);
  return Timestamp.fromDate(date);
}

function isTimeZone(value: string): boolean {
  try {
    new Intl.DateTimeFormat("en", {timeZone: value});
    return true;
  } catch {
    return false;
  }
}

/**
 * createEvent — the only way to create an event, with the caller as Owner.
 * Membership never comes from the client, so nobody can be listed as a member
 * without their own action.
 *
 * The client chooses the ID, so a retry after a lost response changes nothing.
 * Everything is written in one transaction, so a failed creation leaves nothing
 * behind. Only a title is required, and the first event also creates the
 * caller's personal organizer.
 */
export const createEvent = onCall({timeoutSeconds: 30}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const uid = request.auth.uid;
  const data = (request.data ?? {}) as Record<string, unknown>;

  const eventId = requireString(data.eventId, "eventId");
  if (eventId.includes("/")) throw invalid("eventId is not valid.");
  const title = requireString(data.title, "title").trim();
  if (title.length === 0) throw invalid("title cannot be blank.");
  const description = optionalString(data.description, "description");
  const currency = optionalString(data.currency, "currency") ?? "USD";
  if (!/^[A-Z]{3}$/.test(currency)) throw invalid("currency is not a code.");
  // Phones can report zones the server does not know. That should not stop
  // someone creating an event, and an organizer can correct it in settings.
  const deviceZone = optionalString(data.timeZone, "timeZone");
  const timeZone = deviceZone && isTimeZone(deviceZone) ? deviceZone : "UTC";
  const startDate = optionalDate(data.startDate, "startDate");
  const endDate = optionalDate(data.endDate, "endDate");
  const templateId = optionalString(data.templateId, "templateId") ?? "blank";
  const template = systemTemplate(templateId);
  if (!template) throw invalid("templateId is not a template.");

  return withStructuredLogs(
    {op: "createEvent", uid, args: {eventId}},
    async () => {
      const eventRef = db.collection("events").doc(eventId);
      await db.runTransaction(async (tx) => {
        const existing = await tx.get(eventRef);
        if (existing.exists) {
          if (existing.data()!.creatorId === uid) return;
          throw new HttpsError("already-exists", "This ID is already in use.");
        }
        const writeOrganizer = await preparePersonalOrganizer(db, tx, uid);
        writeOrganizer();
        const now = FieldValue.serverTimestamp();
        tx.set(eventRef, {
          id: eventId,
          title,
          description,
          // A copy of the template, so a later version never changes it.
          templateId: template.id,
          templateVersion: template.version,
          creatorId: uid,
          organizerId: uid,
          adminIds: [uid],
          memberIds: [uid],
          memberCount: 1,
          status: "draft",
          currency,
          timeZone,
          dateOnly: data.dateOnly === true,
          venues: [],
          languages: ["en"],
          modules: {tasks: true, budget: true, chat: true, schedule: true, ...template.modules},
          labels: template.labels,
          settings: template.settings,
          capacity: null,
          memberLimit: null,
          startDate,
          endDate,
          createdAt: now,
          updatedAt: now,
        });
        // The template's fields and renamed roles, in the same
        // transaction, so a failed creation leaves nothing behind.
        for (const f of template.fields) {
          const {id, ...field} = f;
          tx.set(eventRef.collection("fields").doc(id), {...field, updatedAt: now});
        }
        const roles: Record<string, {name: string; permissions: string[]; preset: boolean}> = {};
        for (const [roleId, role] of Object.entries(template.roles)) {
          roles[roleId] = {
            name: role.name,
            permissions: [...PRESET_ROLES[role.base].permissions],
            preset: Boolean(PRESET_ROLES[roleId]),
          };
          tx.set(eventRef.collection("roles").doc(roleId), {...roles[roleId], updatedAt: now});
        }
        tx.set(
          memberRef(eventRef, uid),
          memberDoc(uid, {roleIds: ["owner"]}, roles, expenseAccessOf({settings: template.settings}))
        );
      });
      return {success: true};
    }
  );
});
