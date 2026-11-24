import {onCall, HttpsError} from "firebase-functions/v2/https";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {requireString, withStructuredLogs} from "../utils/logging";
import {assertNotArchived} from "../events/eventStatus";
import {readEventRoles, requirePermission} from "../events/members";
import {PRESET_ROLES, rolePermissions} from "../events/permissions";
import {systemTemplate} from "../events/templates";
import {
  RegistrationSettings,
  RegistrationSettingsError,
  normaliseSlug,
  parseRegistrationSettings,
  withRegistrationDefaults,
} from "./settings";

const db = getFirestore();

/** JSON with object keys sorted, so key order never makes two values differ. */
function stableJson(value: unknown): string {
  return JSON.stringify(value, (_, v) =>
    v && typeof v === "object" && !Array.isArray(v) ?
      Object.fromEntries(Object.keys(v).sort().map((k) => [k, v[k]])) :
      v);
}

/**
 * An event's registration settings, with anything missing taken from its
 * template and then the platform's defaults (#239), and its slug when one
 * has been claimed.
 */
export function registrationOf(
  event: FirebaseFirestore.DocumentData | undefined
): RegistrationSettings & {slug: string | null} {
  const stored = event?.settings?.registration;
  const template = systemTemplate(String(event?.templateId ?? "blank"));
  return {
    ...withRegistrationDefaults(stored, template?.settings.registration),
    slug: typeof stored?.slug === "string" ? stored.slug : null,
  };
}

function capacityFrom(value: unknown): number | null | undefined {
  if (value === undefined) return undefined;
  if (value === null) return null;
  if (typeof value !== "number" || !Number.isInteger(value) || value < 1) {
    throw new HttpsError("invalid-argument", "Capacity must be a whole number above zero.");
  }
  return value;
}

/**
 * saveRegistrationSettings — `event.manage` sets how the event registers
 * (Spec #233 Req 8, 16-19, 60, 67): the mode, deadline, review, extra
 * guests, the form's sections, blocks and question conditions, the
 * after-registration note and its replacement, the role for people who
 * register and the offer window, plus the event's `capacity`. Everything is
 * checked against the event's fields, categories and roles, and the change
 * is recorded in `settingsLog`. The slug is kept; only `claimEventSlug`
 * changes it. Saving the same settings again records nothing.
 */
export const saveRegistrationSettings = onCall({timeoutSeconds: 30}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const data = (request.data ?? {}) as {eventId?: unknown; registration?: unknown; capacity?: unknown};
  const eventId = requireString(data.eventId, "eventId");
  const capacity = capacityFrom(data.capacity);
  const uid = request.auth.uid;

  return withStructuredLogs(
    {op: "saveRegistrationSettings", uid, args: {eventId}},
    async () => {
      const eventRef = db.collection("events").doc(eventId);
      await db.runTransaction(async (tx) => {
        const eventDoc = await tx.get(eventRef);
        if (!eventDoc.exists) throw new HttpsError("not-found", "Event not found.");
        const eventData = eventDoc.data()!;
        assertNotArchived(eventData);
        await requirePermission(
          tx, eventRef, eventData, uid, "event.manage",
          "Only people who manage the event can change how it registers."
        );
        const [fields, eventRoles] = await Promise.all([
          tx.get(eventRef.collection("fields")),
          readEventRoles(tx, eventRef),
        ]);
        const roles: Record<string, string[]> = {};
        for (const roleId of new Set([...Object.keys(PRESET_ROLES), ...Object.keys(eventRoles)])) {
          roles[roleId] = rolePermissions(roleId, eventRoles).map(String);
        }
        let settings: RegistrationSettings;
        try {
          settings = parseRegistrationSettings(data.registration, {
            fields: fields.docs.map((d) => ({
              id: d.id,
              type: String(d.data().type ?? "text"),
              options: Array.isArray(d.data().options) ? d.data().options.map(String) : [],
            })),
            categoryIds: (eventData.settings?.categories ?? [])
              .map((c: {id?: unknown}) => c?.id)
              .filter((id: unknown): id is string => typeof id === "string"),
            roles,
          });
        } catch (e) {
          if (e instanceof RegistrationSettingsError) {
            throw new HttpsError("invalid-argument", e.message);
          }
          throw e;
        }
        const before = registrationOf(eventData);
        const {slug, ...beforeSettings} = before;
        const sameSettings = stableJson(beforeSettings) === stableJson(settings);
        const sameCapacity = capacity === undefined || capacity === (eventData.capacity ?? null);
        if (sameSettings && sameCapacity) return;
        tx.update(eventRef, {
          "settings.registration": {...settings, slug},
          ...(capacity === undefined ? {} : {capacity}),
          "updatedAt": FieldValue.serverTimestamp(),
        });
        tx.set(eventRef.collection("settingsLog").doc(), {
          setting: "registration",
          from: {...beforeSettings, capacity: eventData.capacity ?? null},
          to: {...settings, capacity: capacity === undefined ? eventData.capacity ?? null : capacity},
          changedBy: uid,
          changedAt: FieldValue.serverTimestamp(),
        });
      });
      return {success: true};
    }
  );
});

/**
 * claimEventSlug — `event.manage` chooses the name in the event's public
 * link (Spec #233 Req 11): letters, numbers and hyphens, unique across
 * CrewPoint and kept lower-case, so case never makes two. `eventSlugs/{slug}`
 * maps it to the event, written only here; the event's old name is
 * released, and `slug: null` releases it without a new one. A name another
 * event holds is refused with `already-exists` and `details.reason: "taken"`.
 */
export const claimEventSlug = onCall({timeoutSeconds: 30}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const data = (request.data ?? {}) as {eventId?: unknown; slug?: unknown};
  const eventId = requireString(data.eventId, "eventId");
  let slug: string | null = null;
  if (data.slug !== null && data.slug !== undefined) {
    if (typeof data.slug !== "string") throw new HttpsError("invalid-argument", "slug must be text.");
    slug = normaliseSlug(data.slug);
    if (!slug) {
      throw new HttpsError(
        "invalid-argument",
        "Use 3 to 40 letters, numbers and hyphens, starting and ending with a letter or number.",
        {reason: "invalid"}
      );
    }
  }
  const uid = request.auth.uid;

  return withStructuredLogs(
    {op: "claimEventSlug", uid, args: {eventId, slug}},
    async () => {
      const eventRef = db.collection("events").doc(eventId);
      await db.runTransaction(async (tx) => {
        const eventDoc = await tx.get(eventRef);
        if (!eventDoc.exists) throw new HttpsError("not-found", "Event not found.");
        const eventData = eventDoc.data()!;
        assertNotArchived(eventData);
        await requirePermission(
          tx, eventRef, eventData, uid, "event.manage",
          "Only people who manage the event can choose its link."
        );
        const current = registrationOf(eventData).slug;
        if (current === slug) return;
        const newRef = slug ? db.collection("eventSlugs").doc(slug) : null;
        const oldRef = current ? db.collection("eventSlugs").doc(current) : null;
        const [taken, old] = await Promise.all([
          newRef ? tx.get(newRef) : Promise.resolve(null),
          oldRef ? tx.get(oldRef) : Promise.resolve(null),
        ]);
        if (taken?.exists && taken.data()!.eventId !== eventId) {
          throw new HttpsError(
            "already-exists", "Another event already uses this link. Try another.", {reason: "taken"}
          );
        }
        if (old?.exists && old.data()!.eventId === eventId) tx.delete(oldRef!);
        if (newRef) {
          tx.set(newRef, {eventId, claimedBy: uid, claimedAt: FieldValue.serverTimestamp()});
        }
        tx.set(eventRef, {settings: {registration: {slug}}, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
        tx.set(eventRef.collection("settingsLog").doc(), {
          setting: "slug",
          from: current,
          to: slug,
          changedBy: uid,
          changedAt: FieldValue.serverTimestamp(),
        });
      });
      return {slug};
    }
  );
});
