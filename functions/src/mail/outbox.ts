import {FieldValue, Firestore} from "firebase-admin/firestore";

/**
 * The email outbox (Spec #233 Req 51). Only server code adds messages, and
 * rules give clients no access. Each document is also the message's
 * delivery log: `onMailQueued` moves its `status` from `queued` to `sent`,
 * `failed` or `notSent`, with a `reason`, the provider's ID and the time.
 */
export const OUTBOX = "mailOutbox";

/** Server-only mail settings: `deliveryEnabled`, `from`, `allowedRecipients`. */
export const MAIL_SETTINGS = "serverConfig/mail";

export type MailStatus = "queued" | "sending" | "sent" | "failed" | "notSent";

export interface QueuedEmail {
  /** Recipient address. People without the app get every email (N-22). */
  to: string;
  /** The recipient's account, when they have one: for language and push. */
  uid?: string | null;
  /** `en` or `gu`; when missing, the account's `language`, else English. */
  language?: string | null;
  template: string;
  /** Placeholder values. Never money (Req 53). */
  data?: Record<string, string>;
  /** The event, for its words and the push's mute check. */
  eventId?: string | null;
  /** Also push to the recipient's devices when the email is sent (Req 54). */
  push?: boolean;
  /** Where a tapped push opens in the app. */
  deepLink?: string | null;
}

const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

/** Lower-cased and trimmed, or null when it is not an email address. */
export function normaliseEmail(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const email = value.trim().toLowerCase();
  return EMAIL.test(email) ? email : null;
}

/**
 * Adds a message to the outbox and returns its ID. Throws for an address
 * that is not an email, so a caller's bug never queues an unsendable message.
 */
export async function enqueueEmail(db: Firestore, message: QueuedEmail): Promise<string> {
  const to = normaliseEmail(message.to);
  if (!to) throw new Error("enqueueEmail needs a valid recipient address");
  const ref = db.collection(OUTBOX).doc();
  await ref.set({
    to,
    uid: message.uid ?? null,
    language: message.language ?? null,
    template: message.template,
    data: message.data ?? {},
    eventId: message.eventId ?? null,
    push: message.push === true,
    deepLink: message.deepLink ?? null,
    status: "queued" satisfies MailStatus,
    attempts: 0,
    createdAt: FieldValue.serverTimestamp(),
  });
  return ref.id;
}
