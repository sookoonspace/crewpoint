/**
 * The chat summary (Req 57a): `events/{eventId}/chatSummary/current` holds
 * the message count, the latest message, and the latest urgent message's
 * time and sender. The inbox reads it with each person's
 * `users/{uid}/chatReads/{eventId}` (`lastReadAt`, `readCount`) instead of
 * loading every event's messages. The text is copied as written, so a
 * settlement notice shows an amount only when the message itself does
 * (Req 39, #73).
 */
import {Firestore, Timestamp} from "firebase-admin/firestore";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {getFirestore} from "firebase-admin/firestore";

export interface SummaryMessage {
  id: string;
  senderId: string;
  text: string;
  timestamp: Timestamp;
  isHighPriority: boolean;
  kind: string | null;
}

export interface ChatSummary {
  count: number;
  latest: SummaryMessage | null;
  lastUrgentAt: Timestamp | null;
  lastUrgentSenderId: string | null;
  lastUrgentId: string | null;
}

const EMPTY: ChatSummary = {
  count: 0, latest: null, lastUrgentAt: null, lastUrgentSenderId: null, lastUrgentId: null,
};

/** A stored message as the summary keeps it. */
export function toSummaryMessage(id: string, data: FirebaseFirestore.DocumentData): SummaryMessage {
  return {
    id,
    senderId: String(data.senderId ?? ""),
    text: String(data.text ?? ""),
    timestamp: data.timestamp instanceof Timestamp ? data.timestamp : Timestamp.now(),
    isHighPriority: data.isHighPriority === true,
    kind: typeof data.kind === "string" ? data.kind : null,
  };
}

export function summaryAfterCreate(before: ChatSummary | null, m: SummaryMessage): ChatSummary {
  const s = before ?? EMPTY;
  const newer = (a: Timestamp | null) => a == null || m.timestamp.toMillis() >= a.toMillis();
  const urgent = m.isHighPriority && newer(s.lastUrgentAt);
  return {
    count: s.count + 1,
    latest: newer(s.latest?.timestamp ?? null) ? m : s.latest,
    lastUrgentAt: urgent ? m.timestamp : s.lastUrgentAt,
    lastUrgentSenderId: urgent ? m.senderId : s.lastUrgentSenderId,
    lastUrgentId: urgent ? m.id : s.lastUrgentId,
  };
}

/**
 * After deleting [id]: one fewer, and [next] (the newest message left) as
 * latest when the deleted one was. A deleted urgent mark is cleared.
 */
export function summaryAfterDelete(
  before: ChatSummary,
  id: string,
  next: SummaryMessage | null,
): ChatSummary {
  const urgentGone = before.lastUrgentId === id;
  return {
    count: Math.max(0, before.count - 1),
    latest: before.latest?.id === id ? next : before.latest,
    lastUrgentAt: urgentGone ? null : before.lastUrgentAt,
    lastUrgentSenderId: urgentGone ? null : before.lastUrgentSenderId,
    lastUrgentId: urgentGone ? null : before.lastUrgentId,
  };
}

const summaryRef = (db: Firestore, eventId: string) =>
  db.collection("events").doc(eventId).collection("chatSummary").doc("current");

function read(data: FirebaseFirestore.DocumentData | undefined): ChatSummary | null {
  return data ? {...EMPTY, ...data} as ChatSummary : null;
}

/** Counts a new message, and moves the sender's read marker past it. */
export async function applyMessageCreated(db: Firestore, eventId: string, m: SummaryMessage): Promise<void> {
  await db.runTransaction(async (tx) => {
    const ref = summaryRef(db, eventId);
    const next = summaryAfterCreate(read((await tx.get(ref)).data()), m);
    tx.set(ref, next);
    if (m.senderId) {
      tx.set(db.doc(`users/${m.senderId}/chatReads/${eventId}`), {
        lastReadAt: m.timestamp,
        readCount: next.count,
      }, {merge: true});
    }
  });
}

/** Keeps the latest message current when it changes. */
export async function applyMessageUpdated(db: Firestore, eventId: string, m: SummaryMessage): Promise<void> {
  await db.runTransaction(async (tx) => {
    const ref = summaryRef(db, eventId);
    const s = read((await tx.get(ref)).data());
    if (s?.latest?.id === m.id) tx.set(ref, {...s, latest: m});
  });
}

/** Uncounts a deleted message, finding the next newest when needed. */
export async function applyMessageDeleted(db: Firestore, eventId: string, id: string): Promise<void> {
  const messages = db.collection("events").doc(eventId).collection("messages");
  await db.runTransaction(async (tx) => {
    const ref = summaryRef(db, eventId);
    const s = read((await tx.get(ref)).data());
    if (!s) return;
    let next: SummaryMessage | null = null;
    if (s.latest?.id === id) {
      const newest = await tx.get(messages.orderBy("timestamp", "desc").limit(1));
      next = newest.empty ? null : toSummaryMessage(newest.docs[0].id, newest.docs[0].data());
    }
    tx.set(ref, summaryAfterDelete(s, id, next));
  });
}

/** onChatMessageWritten — keeps the chat summary in step (Req 57a). */
export const onChatMessageWritten = onDocumentWritten(
  "events/{eventId}/messages/{messageId}",
  async (event) => {
    const db = getFirestore();
    const {eventId, messageId} = event.params;
    const before = event.data?.before;
    const after = event.data?.after;
    if (!after?.exists) {
      if (before?.exists) await applyMessageDeleted(db, eventId, messageId);
      return;
    }
    const m = toSummaryMessage(messageId, after.data()!);
    if (!before?.exists) {
      await applyMessageCreated(db, eventId, m);
    } else {
      await applyMessageUpdated(db, eventId, m);
    }
  }
);
