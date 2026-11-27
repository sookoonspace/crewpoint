import {onCall, HttpsError} from "firebase-functions/v2/https";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {withStructuredLogs} from "../utils/logging";
import {requirePermission} from "../events/members";
import {registrationOf} from "./registrationSettings";
import {eventBySlug} from "./registrationForm";
import {applyRegistrationMembership} from "./membership";

const db = () => getFirestore();

/**
 * cancelRegistration — cancels a registration (Spec #233 Req 4, 32a, 61;
 * #245), by the event's link name. Without `registrationId`, the caller's
 * own, as its contact or a linked adult, before the deadline (`byGroup`);
 * with one, any registration, by `registrations.manage` at any time
 * (`byCommittee`). In one transaction: a submitted or pending group's
 * places are freed in `registrationTally/current`, the status becomes
 * `cancelled` on the registration, its group and people (kept, with the
 * reason, and left out of every count), the change log records it, and
 * membership given by registering is taken back. Refuses an already
 * cancelled registration (`failed-precondition`, `alreadyCancelled`) and a
 * family after the deadline (`closed`).
 */
export const cancelRegistration = onCall({timeoutSeconds: 60}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Must be signed in.");
  const data = (request.data ?? {}) as {slug?: unknown; registrationId?: unknown};
  const byCommittee = typeof data.registrationId === "string" && data.registrationId.length > 0;

  return withStructuredLogs({op: "cancelRegistration", uid, args: {slug: data.slug, byCommittee}}, async () => {
    const {slug, ref: eventRef} = await eventBySlug(data.slug);
    return db().runTransaction(async (tx) => {
      const eventDoc = await tx.get(eventRef);
      if (!eventDoc.exists) throw new HttpsError("not-found", "We couldn't find this event.");
      const event = eventDoc.data()!;
      const settings = registrationOf(event);
      if (settings.slug !== slug) throw new HttpsError("not-found", "We couldn't find this event.");

      let regDoc: FirebaseFirestore.DocumentSnapshot | undefined;
      if (byCommittee) {
        await requirePermission(tx, eventRef, event, uid, "registrations.manage",
          "You don't have permission to manage registrations.");
        regDoc = await tx.get(eventRef.collection("registrations").doc(String(data.registrationId)));
        if (!regDoc.exists) throw new HttpsError("not-found", "We couldn't find this registration.");
      } else {
        const mine = await tx.get(eventRef.collection("registrations").where("contactUid", "==", uid).limit(1));
        regDoc = mine.docs.find((d) => d.data().status !== "draft");
        if (!regDoc) {
          const member = await tx.get(eventRef.collection("members").doc(uid));
          const groupIds: string[] = (member.data()?.groupIds ?? []).slice(0, 10);
          if (groupIds.length > 0) {
            const asAdult = await tx.get(eventRef.collection("registrations").where("groupId", "in", groupIds).limit(1));
            regDoc = asAdult.docs[0];
          }
        }
        if (!regDoc) throw new HttpsError("not-found", "You haven't registered for this event.");
        if (settings.deadline !== null && Date.now() > settings.deadline) {
          throw new HttpsError("failed-precondition",
            "Registration is closed. Please contact the organizer to make changes.", {reason: "closed"});
        }
      }
      const reg = regDoc.data()!;
      if (reg.status === "cancelled") {
        throw new HttpsError("failed-precondition", "This registration is already cancelled.",
          {reason: "alreadyCancelled"});
      }
      if (reg.status === "draft") throw new HttpsError("not-found", "You haven't registered for this event.");

      const groupRef = eventRef.collection("groups").doc(String(reg.groupId));
      const tallyRef = eventRef.collection("registrationTally").doc("current");
      const [group, people, tally] = await Promise.all([
        tx.get(groupRef),
        tx.get(eventRef.collection("participants").where("registrationId", "==", regDoc.id)),
        tx.get(tallyRef),
      ]);
      const membership = await applyRegistrationMembership.read(tx, eventRef, regDoc.ref, {
        event, groupId: groupRef.id, adults: group.data()?.adultUids ?? [], contactUid: reg.contactUid,
      });

      const now = FieldValue.serverTimestamp();
      const reason = byCommittee ? "byCommittee" : "byGroup";
      if (["submitted", "pending"].includes(reg.status)) {
        const used = typeof tally.data()?.placesUsed === "number" ? tally.data()!.placesUsed : 0;
        tx.set(tallyRef, {placesUsed: Math.max(0, used - people.size), updatedAt: now}, {merge: true});
      }
      tx.update(regDoc.ref, {status: "cancelled", cancelReason: reason, waitlistPosition: null, updatedAt: now});
      if (group.exists) tx.update(groupRef, {registrationStatus: "cancelled", updatedAt: now});
      people.docs.forEach((p) => tx.update(p.ref, {registrationStatus: "cancelled", updatedAt: now}));
      tx.set(regDoc.ref.collection("changes").doc(), {
        at: now, by: uid, action: "cancelled", status: "cancelled", reason, from: reg.status,
      });
      applyRegistrationMembership.write(tx, membership, "cancelled");
      return {status: "cancelled"};
    });
  });
});
