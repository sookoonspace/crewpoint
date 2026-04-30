/**
 * One-shot, idempotent migration that splits PII off the public
 * `users/{uid}` doc into a self-only `users/{uid}/private/profile`
 * subdoc.
 *
 * Background: prior to Fix 1.B Option A (projection-split), the
 * Firestore rule `match /users/{uid} { allow read: if request.auth != null; }`
 * exposed every user's email + providerIds + fcmTokens + preferences
 * to every signed-in user. Tightening the rule alone is insufficient
 * because existing user docs still carry those PII fields at the top
 * level — the rule lets them be read by every authenticated user.
 *
 * This script:
 *   1. Streams every doc in `users/{uid}`,
 *   2. Skips any doc that already has `users/{uid}/private/profile` (idempotent),
 *   3. Writes PII fields (email, providerIds, fcmTokens, preferences,
 *      createdAt, updatedAt) into the new private subdoc,
 *   4. Removes those fields from the public doc with `FieldValue.delete()`,
 *   5. Records `migratedAt` on the private subdoc as a forward-looking
 *      idempotency marker.
 *
 * Usage (against the local emulator):
 *   FIRESTORE_EMULATOR_HOST=localhost:8080 \
 *   GCLOUD_PROJECT=crewpoint-dev \
 *   npx tsx scripts/migratePiiToPrivate.ts
 *
 * Usage (against production — requires service-account credentials):
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/to/sa.json \
 *   GCLOUD_PROJECT=crewpoint-prod \
 *   npx tsx scripts/migratePiiToPrivate.ts
 *
 * The script must run in the same maintenance window as the rule
 * deploy: deploying Fix 1.B before this migration completes briefly
 * leaves the email field readable to all authenticated users (rule
 * unchanged on the parent doc), but no NEW reads via UI are emitted
 * because the dart repository will already be reading the private
 * subdoc. Sequence preference: deploy migration → deploy rules.
 */

import * as admin from "firebase-admin";

const PII_FIELDS = [
  "email",
  "providerIds",
  "fcmTokens",
  "preferences",
  "createdAt",
  "updatedAt",
] as const;

const PAGE_SIZE = 500;

async function main(): Promise<void> {
  if (!admin.apps.length) {
    admin.initializeApp({
      projectId: process.env.GCLOUD_PROJECT,
    });
  }

  const db = admin.firestore();
  const usersRef = db.collection("users");

  let migrated = 0;
  let skipped = 0;
  let lastDocId: string | undefined;

  // Cursor-paged scan so the migration runs on huge user bases without
  // OOMing. We page on document ID order which is stable.
  // eslint-disable-next-line no-constant-condition
  while (true) {
    let q = usersRef.orderBy(admin.firestore.FieldPath.documentId()).limit(PAGE_SIZE);
    if (lastDocId) q = q.startAfter(lastDocId);
    const page = await q.get();
    if (page.empty) break;

    for (const userDoc of page.docs) {
      const uid = userDoc.id;
      const privateRef = userDoc.ref.collection("private").doc("profile");
      const privateSnap = await privateRef.get();
      if (privateSnap.exists) {
        skipped += 1;
        continue;
      }

      const data = userDoc.data();
      const piiPayload: Record<string, unknown> = {
        migratedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      const publicDeletes: Record<string, FirebaseFirestore.FieldValue> = {};
      for (const field of PII_FIELDS) {
        if (data[field] === undefined) continue;
        piiPayload[field] = data[field];
        publicDeletes[field] = admin.firestore.FieldValue.delete();
      }

      const batch = db.batch();
      batch.set(privateRef, piiPayload);
      if (Object.keys(publicDeletes).length > 0) {
        batch.update(userDoc.ref, publicDeletes);
      }
      await batch.commit();
      migrated += 1;
    }

    lastDocId = page.docs[page.docs.length - 1].id;
    if (page.size < PAGE_SIZE) break;
  }

  // eslint-disable-next-line no-console
  console.log(
    `migratePiiToPrivate complete: migrated=${migrated} skipped=${skipped}`
  );
}

main().catch((err) => {
  // eslint-disable-next-line no-console
  console.error("migratePiiToPrivate failed:", err);
  process.exit(1);
});
