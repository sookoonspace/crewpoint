import {createHmac, randomBytes} from "crypto";
import {getFirestore} from "firebase-admin/firestore";

/**
 * One-way match keys for unnamed entries (Req 14a, decided in #78). When a
 * linked account is deleted, its record in an event that has not ended keeps
 * scrambled forms of the email and import ID in
 * `events/{id}/participantKeys/{participantId}`, which no client can read.
 * A new account with the same verified email links back to it, and a
 * re-import with the same ID refills it, so nobody is counted twice. The
 * secret lives in `serverSecrets/participantKeys`, which no rule opens.
 */

/** The scrambled form of [value], under [secret]. Pure, for tests. */
export function keyWith(secret: string, kind: string, value: string): string {
  return createHmac("sha256", secret)
    .update(`${kind}:${value.trim().toLowerCase()}`)
    .digest("hex")
    .slice(0, 40);
}

let cached: string | null = null;

async function secret(): Promise<string> {
  if (cached) return cached;
  const db = getFirestore();
  const ref = db.collection("serverSecrets").doc("participantKeys");
  cached = await db.runTransaction(async (tx) => {
    const existing = await tx.get(ref);
    if (existing.exists) return existing.data()!.value as string;
    const value = randomBytes(32).toString("hex");
    tx.set(ref, {value});
    return value;
  });
  return cached;
}

/** The same in every event, so linking can look across events. */
export async function emailMatchKey(email: string): Promise<string> {
  return keyWith(await secret(), "email", email);
}

/** Import IDs only mean something within one event. */
export async function externalIdMatchKey(eventId: string, externalId: string): Promise<string> {
  return keyWith(await secret(), `externalId:${eventId}`, externalId);
}

/** A synchronous scrambler for one event's import IDs, for a whole file. */
export async function externalIdKeyer(eventId: string): Promise<(externalId: string) => string> {
  const value = await secret();
  return (externalId) => keyWith(value, `externalId:${eventId}`, externalId);
}
