import {FieldValue, Firestore, getFirestore} from "firebase-admin/firestore";
import {logger} from "firebase-functions/v2";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {defineSecret} from "firebase-functions/params";
import {sendCategorizedPush} from "../notifications/sendPush";
import {MAIL_SETTINGS, MailStatus, OUTBOX, normaliseEmail} from "./outbox";
import {MailRenderError, renderEmail} from "./render";
import {
  EmailTransport,
  RefusingTransport,
  ResendTransport,
  TransportRefused,
  isTestEnvironment,
} from "./transport";

/** Resend's API key, kept in Secret Manager (Technical Decision 6). */
export const RESEND_API_KEY = defineSecret("RESEND_API_KEY");

/** The only project that emails everyone; dev and staging use the allowed list. */
export const PROD_PROJECT = "crewpoint-prod";

export const NOT_ON_ALLOWED_LIST = "Not sent: not on the dev allowed list";
export const DELIVERY_OFF = "Not sent: delivery is off";
export const NO_SENDER = "Not sent: no sending address";
export const TEST_ENVIRONMENT = "Not sent: test environment";

type PushFn = typeof sendCategorizedPush;

export interface SendDeps {
  transport: EmailTransport;
  projectId: string;
  push?: PushFn;
}

export interface MailSettings {
  deliveryEnabled: boolean;
  from: string | null;
  allowedRecipients: string[];
}

export function mailSettingsOf(data: FirebaseFirestore.DocumentData | undefined): MailSettings {
  const allowed = Array.isArray(data?.allowedRecipients) ? data.allowedRecipients : [];
  return {
    deliveryEnabled: data?.deliveryEnabled === true,
    from: typeof data?.from === "string" && data.from.trim() ? data.from.trim() : null,
    allowedRecipients: allowed.map(normaliseEmail).filter((e: string | null): e is string => e !== null),
  };
}

/**
 * Why [to] must not be emailed, or null when it may be. Outside prod only
 * the allowed list is emailed (Req 51a); nothing goes until delivery is
 * turned on, which waits for the sending domain's SPF, DKIM and DMARC.
 */
export function blockedReason(to: string, settings: MailSettings, projectId: string): string | null {
  if (projectId !== PROD_PROJECT && !settings.allowedRecipients.includes(to)) return NOT_ON_ALLOWED_LIST;
  if (!settings.deliveryEnabled) return DELIVERY_OFF;
  if (!settings.from) return NO_SENDER;
  return null;
}

/**
 * Sends one outbox message and records the outcome on it. A message that
 * is not `queued` is left alone, so a repeated trigger never sends twice.
 * Returns the final status, or null when the message was already handled.
 */
export async function processOutboxMessage(
  db: Firestore,
  messageId: string,
  deps: SendDeps,
): Promise<MailStatus | null> {
  const ref = db.collection(OUTBOX).doc(messageId);
  const message = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists || snap.get("status") !== "queued") return null;
    tx.update(ref, {status: "sending", attempts: FieldValue.increment(1), updatedAt: FieldValue.serverTimestamp()});
    return snap.data() as FirebaseFirestore.DocumentData;
  });
  if (!message) return null;

  const finish = async (status: MailStatus, extra: Record<string, unknown> = {}) => {
    await ref.update({status, ...extra, updatedAt: FieldValue.serverTimestamp()});
    logger.info("mail finished", {op: "onMailQueued", messageId, status, reason: extra.reason ?? null});
    return status;
  };

  const uid = typeof message.uid === "string" ? message.uid : null;
  const eventId = typeof message.eventId === "string" ? message.eventId : null;
  const [settingsSnap, eventSnap, userSnap] = await Promise.all([
    db.doc(MAIL_SETTINGS).get(),
    eventId ? db.collection("events").doc(eventId).get() : Promise.resolve(null),
    uid && !message.language ? db.collection("users").doc(uid).get() : Promise.resolve(null),
  ]);
  const language = message.language ?? userSnap?.get("language") ?? "en";

  let rendered;
  try {
    rendered = renderEmail({
      template: String(message.template),
      language,
      data: (message.data ?? {}) as Record<string, string>,
      labels: eventSnap?.get("labels") as Record<string, unknown> | undefined,
    });
  } catch (err) {
    if (err instanceof MailRenderError) return finish("failed", {reason: err.message});
    throw err;
  }

  const to = String(message.to);
  const settings = mailSettingsOf(settingsSnap.data());
  const blocked = blockedReason(to, settings, deps.projectId);
  if (blocked) return finish("notSent", {reason: blocked, subject: rendered.subject});

  try {
    const {providerId} = await deps.transport.send({
      from: settings.from as string,
      to,
      subject: rendered.subject,
      text: rendered.text,
      html: rendered.html,
      messageId,
    });
    await finish("sent", {providerId, subject: rendered.subject, sentAt: FieldValue.serverTimestamp()});
  } catch (err) {
    if (err instanceof TransportRefused) return finish("notSent", {reason: TEST_ENVIRONMENT, subject: rendered.subject});
    return finish("failed", {reason: err instanceof Error ? err.message : String(err), subject: rendered.subject});
  }

  // Push goes alongside a sent email to anyone with the app (Req 54).
  if (message.push === true && uid && eventId) {
    try {
      await (deps.push ?? sendCategorizedPush)({
        recipientUids: [uid],
        category: "registration",
        eventId,
        title: rendered.push.title,
        body: rendered.push.body,
        deepLink: typeof message.deepLink === "string" ? message.deepLink : "",
        extraData: {eventId},
      });
    } catch (err) {
      logger.error("mail push failed", {op: "onMailQueued", messageId, error: err instanceof Error ? err.message : String(err)});
    }
  }
  return "sent";
}

/** The transport for this environment: never a real one under test. */
export function defaultTransport(): EmailTransport {
  return isTestEnvironment() ? new RefusingTransport() : new ResendTransport(RESEND_API_KEY.value());
}

/** Sends each message added to the outbox. Not retried: a failure is logged on the message. */
export const onMailQueued = onDocumentCreated(
  {document: `${OUTBOX}/{messageId}`, secrets: [RESEND_API_KEY], retry: false},
  async (event) => {
    await processOutboxMessage(getFirestore(), event.params.messageId, {
      transport: defaultTransport(),
      projectId: process.env.GCLOUD_PROJECT ?? "",
    });
  },
);
