import {createHash} from "crypto";
import {Timestamp} from "firebase-admin/firestore";

/**
 * A fixed-window rate limit for public calls (Spec #233 Req 13a): at most
 * [limit] requests per [windowMs] for one [subject], such as an address,
 * in [bucket]. Counts live in `rateLimits/{key}` (no client access), keyed
 * by a hash so no address is stored, with `expiresAt` for a TTL policy to
 * remove them. Returns false once the window is used up.
 */
export async function allowRequest(
  db: FirebaseFirestore.Firestore,
  {bucket, subject, limit, windowMs, now = Date.now()}: {
    bucket: string;
    subject: string;
    limit: number;
    windowMs: number;
    now?: number;
  }
): Promise<boolean> {
  const window = Math.floor(now / windowMs);
  const key = createHash("sha256").update(`${bucket}:${subject}`).digest("hex").slice(0, 32);
  const ref = db.collection("rateLimits").doc(`${bucket}_${key}_${window}`);
  return db.runTransaction(async (tx) => {
    const doc = await tx.get(ref);
    const count = ((doc.data()?.count as number | undefined) ?? 0) + 1;
    if (count > limit) return false;
    tx.set(ref, {count, expiresAt: Timestamp.fromMillis((window + 2) * windowMs)});
    return true;
  });
}

/** The caller's address, as Hosting and Cloud Run pass it on. */
export function callerAddress(raw: {headers?: Record<string, unknown>; ip?: string} | undefined): string {
  const forwarded = raw?.headers?.["x-forwarded-for"];
  const first = typeof forwarded === "string" ? forwarded.split(",")[0].trim() : "";
  return first || raw?.ip || "unknown";
}
