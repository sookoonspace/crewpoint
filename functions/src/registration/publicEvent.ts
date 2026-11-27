/**
 * What the public event page may show (Spec #233 Req 10, 14; #240): the
 * title, dates, time zone, venues, description, what is included, the
 * deadline and whether places remain. Never the event's ID, its people,
 * any count or money. A draft says only that it is not open yet. Pure, so
 * the callable and the server-rendered first page share it.
 */
import {mapLegacyStatus} from "../events/eventStatus";
import {LocalText, RegistrationMode, RegistrationSettings} from "./settings";

export type PublicEventState = "open" | "notOpen" | "closed";

export interface PublicVenue {
  name: string;
  address: string;
  mapUrl: string;
  directions: string;
}

export type PublicEvent =
  | {state: "notOpen"}
  | {
    state: "open" | "closed";
    slug: string;
    title: string;
    description: string;
    startDate: number | null;
    endDate: number | null;
    dateOnly: boolean;
    timeZone: string;
    venues: PublicVenue[];
    included: LocalText | null;
    /** How to reach the organizer, for the closed page (#244). */
    contactLine: LocalText | null;
    deadline: number | null;
    mode: RegistrationMode;
    /** Whether anyone registering now gets a place, not how many. */
    placesRemain: boolean;
    hasCover: boolean;
    /** The event's own words, so the page names things as the event does. */
    labels: Record<string, unknown>;
  };

const millis = (v: unknown): number | null =>
  v && typeof (v as {toMillis?: unknown}).toMillis === "function" ?
    (v as {toMillis: () => number}).toMillis() :
    null;

const text = (v: unknown): string => (typeof v === "string" ? v : "");

export function publicEventView({event, registration, placesUsed, now}: {
  event: FirebaseFirestore.DocumentData;
  registration: RegistrationSettings & {slug: string | null};
  placesUsed: number;
  now: number;
}): PublicEvent {
  const endDate = millis(event.endDate);
  const status = mapLegacyStatus(
    event.status, endDate === null ? null : new Date(endDate), new Date(now));
  if (status === "draft") return {state: "notOpen"};
  const deadline = registration.deadline;
  const open = (status === "published" || status === "live") &&
    (deadline === null || now < deadline);
  const capacity = Number.isInteger(event.capacity) && event.capacity > 0 ? event.capacity : null;
  return {
    state: open ? "open" : "closed",
    slug: registration.slug ?? "",
    title: text(event.title),
    description: text(event.description),
    startDate: millis(event.startDate),
    endDate,
    dateOnly: event.dateOnly === true,
    timeZone: text(event.timeZone) || "UTC",
    venues: (Array.isArray(event.venues) ? event.venues : []).map((v: Record<string, unknown>) => ({
      name: text(v?.name),
      address: text(v?.address),
      mapUrl: text(v?.mapUrl),
      directions: text(v?.directions),
    })),
    included: registration.included ?? null,
    contactLine: registration.contactLine ?? null,
    deadline,
    mode: registration.mode,
    placesRemain: capacity === null || placesUsed < capacity,
    hasCover: typeof event.cover?.path === "string",
    labels: typeof event.labels === "object" && event.labels !== null ? event.labels : {},
  };
}
