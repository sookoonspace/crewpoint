import {HttpsError} from "firebase-functions/v2/https";
import {DocumentData} from "firebase-admin/firestore";
import {eventStartMs} from "./eventStatus";

const MINUTE_MS = 60 * 1000;
const DAY_MS = 24 * 60 * MINUTE_MS;

/** Long enough for a whole registration period (Req 56). */
export const MAX_INVITE_DAYS = 400;
/** An organizer's expiry must leave time to share the link. */
const MIN_INVITE_MS = 5 * MINUTE_MS;

/** Templates whose invites last a day unless the organizer says otherwise. */
const SHORT_LIVED = ["blank", "party"];

/**
 * The expiry a new invite gets when the organizer has not set one (Req 56):
 * 24 hours on Blank and Party, and events from before templates, and until
 * the event starts on other templates. With no start ahead, 24 hours.
 */
export function defaultInviteExpiry(event: DocumentData, now: number): number {
  const day = now + DAY_MS;
  if (SHORT_LIVED.includes(event.templateId ?? "blank")) return day;
  const start = eventStartMs(event);
  if (start === null || start <= day) return day;
  return Math.min(start, now + MAX_INVITE_DAYS * DAY_MS);
}

/** An organizer's chosen expiry, in milliseconds, checked. */
export function checkInviteExpiry(value: unknown, now: number): number {
  if (
    typeof value !== "number" || !Number.isInteger(value) ||
    value < now + MIN_INVITE_MS || value > now + MAX_INVITE_DAYS * DAY_MS
  ) {
    throw new HttpsError(
      "invalid-argument",
      `An invite can last from 5 minutes to ${MAX_INVITE_DAYS} days.`
    );
  }
  return value;
}
