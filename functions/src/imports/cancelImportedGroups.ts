import {onCall, HttpsError} from "firebase-functions/v2/https";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {requireString, withStructuredLogs} from "../utils/logging";
import {assertNotArchived} from "../events/eventStatus";
import {requirePermission} from "../events/members";
import {commitInChunks, BatchOperation} from "../utils/batch";

const db = getFirestore();

/**
 * cancelImportedGroups — after a re-import, confirms which missing groups
 * (Req 45, X-03) have cancelled: their people are marked `cancelled`, which
 * removes them from counts, and the records are kept. Only groups the job
 * listed as missing can be cancelled. Needs `participants.import`.
 */
export const cancelImportedGroups = onCall({timeoutSeconds: 60}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Must be signed in.");
  const uid = request.auth.uid;
  const data = (request.data ?? {}) as Record<string, unknown>;
  const eventId = requireString(data.eventId, "eventId");
  const jobId = requireString(data.jobId, "jobId");
  const groupIds = data.groupIds;
  if (!Array.isArray(groupIds) || groupIds.length === 0 ||
    !groupIds.every((g) => typeof g === "string" && g)) {
    throw new HttpsError("invalid-argument", "groupIds must list the groups to cancel.");
  }

  return withStructuredLogs(
    {op: "cancelImportedGroups", uid, args: {eventId, jobId, count: groupIds.length}},
    async () => {
      const eventRef = db.collection("events").doc(eventId);
      const event = await eventRef.get();
      if (!event.exists) throw new HttpsError("not-found", "Event not found.");
      assertNotArchived(event.data()!);
      await requirePermission(null, eventRef, event.data()!, uid, "participants.import",
        "Only people who import attendees can cancel groups.");
      const jobRef = eventRef.collection("imports").doc(jobId);
      const job = (await jobRef.get()).data();
      const missing = (job?.report?.missingGroups ?? []) as {groupId: string | null; participantIds: string[]}[];
      const chosen = missing.filter((m) => m.groupId && groupIds.includes(m.groupId));
      if (chosen.length !== groupIds.length) {
        throw new HttpsError("invalid-argument", "Only groups this import listed as missing can be cancelled.");
      }
      const now = FieldValue.serverTimestamp();
      const ops: BatchOperation[] = [];
      for (const m of chosen) {
        ops.push({type: "update", ref: eventRef.collection("groups").doc(m.groupId!), data: {status: "cancelled", updatedAt: now}});
        for (const pid of m.participantIds) {
          ops.push({type: "update", ref: eventRef.collection("participants").doc(pid), data: {status: "cancelled", updatedAt: now}});
        }
      }
      await commitInChunks(ops);
      await jobRef.update({cancelledGroupIds: FieldValue.arrayUnion(...groupIds)});
      return {success: true};
    }
  );
});
