import {onCall, HttpsError} from "firebase-functions/v2/https";
import {FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";
import {requireString, withStructuredLogs} from "../utils/logging";
import {preparePersonalOrganizer} from "./organizers";

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
          templateId: "blank",
          creatorId: uid,
          organizerId: uid,
          adminIds: [uid],
          memberIds: [uid],
          memberCount: 1,
          status: "draft",
          currency,
          timeZone,
          venues: [],
          languages: ["en"],
          modules: {tasks: true, budget: true, chat: true},
          labels: {},
          settings: {},
          capacity: null,
          memberLimit: null,
          startDate,
          endDate,
          createdAt: now,
          updatedAt: now,
        });
      });
      return {success: true};
    }
  );
});
