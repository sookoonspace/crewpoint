import {onCall, HttpsError} from "firebase-functions/v2/https";
import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {clock} from "../utils/clock";
import {requireString, withStructuredLogs} from "../utils/logging";
import {requirePermission} from "../events/members";
import {toCsv} from "../imports/csv";
import {recalculateEvent} from "./recalculate";

/** A time as `YYYY-MM-DD HH:mm` where the event is. */
function local(value: unknown, zone: string): string {
  if (!(value instanceof Timestamp)) return "";
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: zone, year: "numeric", month: "2-digit", day: "2-digit",
    hour: "2-digit", minute: "2-digit", hourCycle: "h23",
  }).formatToParts(value.toDate());
  const get = (t: string) => parts.find((p) => p.type === t)?.value ?? "";
  return `${get("year")}-${get("month")}-${get("day")} ${get("hour")}:${get("minute")}`;
}

/** An answer as text: lists joined, yes/no spelled out. */
function answerText(value: unknown): string {
  if (value == null) return "";
  if (typeof value === "boolean") return value ? "Yes" : "No";
  if (Array.isArray(value)) return value.map(String).join("; ");
  return String(value);
}

/**
 * exportRoster — the event's active people as CSV (Req 53): name, group,
 * category, arrival, departure and standard answers. Private answers and
 * birth dates are added only with `includePrivate`, which needs
 * `participants.readPrivate`. Needs `reports.export` and `participants.read`
 * (owner's decision, 2026-11-11). Every cell is neutralised.
 */
export const exportRoster = onCall({timeoutSeconds: 120, memory: "512MiB"}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Must be signed in.");
  const uid = request.auth.uid;
  const data = (request.data ?? {}) as Record<string, unknown>;
  const eventId = requireString(data.eventId, "eventId");
  const includePrivate = data.includePrivate === true;
  return withStructuredLogs({op: "exportRoster", uid, args: {eventId, includePrivate}}, async () => {
    const db = getFirestore();
    const eventRef = db.collection("events").doc(eventId);
    const event = await eventRef.get();
    if (!event.exists) throw new HttpsError("not-found", "Event not found.");
    const held = await requirePermission(null, eventRef, event.data()!, uid, "reports.export",
      "Only people who export reports can export the roster.");
    if (!held.includes("participants.read")) {
      throw new HttpsError("permission-denied", "Exporting the roster needs participants.read.");
    }
    if (includePrivate && !held.includes("participants.readPrivate")) {
      throw new HttpsError("permission-denied", "Private details need participants.readPrivate.");
    }

    const zone = String(event.data()!.timeZone ?? "UTC");
    const categories = new Map<string, string>(
      ((event.data()!.settings?.categories ?? []) as {id: string; name: string}[]).map((c) => [c.id, c.name]));
    const [fieldSnap, peopleSnap, groupSnap] = await Promise.all([
      eventRef.collection("fields").get(),
      eventRef.collection("participants").where("status", "==", "active").get(),
      eventRef.collection("groups").get(),
    ]);
    const fields = fieldSnap.docs
      .map((d) => ({id: d.id, label: String(d.data().label ?? d.id), order: Number(d.data().order ?? 0),
        scope: d.data().scope ?? "participant", private: d.data().visibility === "private"}))
      .filter((f) => f.scope === "participant")
      .sort((a, b) => a.order - b.order);
    const standard = fields.filter((f) => !f.private);
    const privates = includePrivate ? fields.filter((f) => f.private) : [];
    const groups = new Map(groupSnap.docs.map((d) => [d.id, String(d.data().name ?? "")]));
    const people = [...peopleSnap.docs].sort((a, b) =>
      String(a.data().sortName ?? "").localeCompare(String(b.data().sortName ?? "")));

    const details = new Map<string, FirebaseFirestore.DocumentData>();
    if (includePrivate) {
      for (let i = 0; i < people.length; i += 300) {
        const refs = people.slice(i, i + 300).map((p) => p.ref.collection("private").doc("details"));
        if (refs.length === 0) continue;
        for (const snap of await db.getAll(...refs)) {
          if (snap.exists) details.set(snap.ref.parent.parent!.id, snap.data()!);
        }
      }
    }

    const rows: string[][] = [[
      "Name", "Group", "Category", "Arrives", "Leaves",
      ...standard.map((f) => f.label),
      ...(includePrivate ? ["Birth date", ...privates.map((f) => f.label)] : []),
    ]];
    for (const doc of people) {
      const p = doc.data();
      const priv = details.get(doc.id);
      rows.push([
        String(p.name ?? ""),
        groups.get(p.groupId) ?? "",
        categories.get(p.categoryId) ?? "",
        local(p.arrivalAt, zone),
        local(p.departureAt, zone),
        ...standard.map((f) => answerText(p.fields?.[f.id])),
        ...(includePrivate ?
          [String(priv?.birthDate ?? ""), ...privates.map((f) => answerText(priv?.fields?.[f.id]))] :
          []),
      ]);
    }
    return {csv: toCsv(rows), rows: rows.length - 1};
  });
});

/**
 * freezeCounts — counts the event now and keeps those numbers in
 * `countFreezes/{id}` with the time, who froze them and an optional label
 * (Req 54). Freezing again adds another; earlier ones stay. Needs
 * `reports.export` (owner's decision, 2026-11-11).
 */
export const freezeCounts = onCall({timeoutSeconds: 120}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Must be signed in.");
  const uid = request.auth.uid;
  const data = (request.data ?? {}) as Record<string, unknown>;
  const eventId = requireString(data.eventId, "eventId");
  const label = typeof data.label === "string" ? data.label.trim() : "";
  if (label.length > 80) throw new HttpsError("invalid-argument", "The label is too long.");
  return withStructuredLogs({op: "freezeCounts", uid, args: {eventId}}, async () => {
    const db = getFirestore();
    const eventRef = db.collection("events").doc(eventId);
    const event = await eventRef.get();
    if (!event.exists) throw new HttpsError("not-found", "Event not found.");
    await requirePermission(null, eventRef, event.data()!, uid, "reports.export",
      "Only people who export reports can freeze counts.");
    const now = new Date(clock.now());
    await recalculateEvent(db, eventId, now);
    const stats = (await eventRef.collection("stats").doc("current").get()).data() ?? {};
    const ref = eventRef.collection("countFreezes").doc();
    await ref.set({
      event: stats.event ?? {},
      sessions: stats.sessions ?? {},
      frozenAt: Timestamp.fromDate(now),
      frozenBy: uid,
      label: label || null,
    });
    return {freezeId: ref.id};
  });
});
