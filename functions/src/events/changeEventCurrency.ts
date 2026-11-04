import {onCall, HttpsError} from "firebase-functions/v2/https";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {requireString, withStructuredLogs} from "../utils/logging";

const db = getFirestore();

/** What makes an event hold money. Charges arrive with Stage 2 registration. */
const MONEY_COLLECTIONS = ["expenses", "charges"];

/**
 * changeEventCurrency — the only way to change an event's currency, because
 * rules cannot see whether the event holds money. Refused once it has any
 * expense or charge (Req 17). Needs `event.manage`, which means owner or admin
 * until permissions land.
 */
export const changeEventCurrency = onCall(
  {timeoutSeconds: 30},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }
    const uid = request.auth.uid;
    const data = (request.data ?? {}) as Record<string, unknown>;
    const eventId = requireString(data.eventId, "eventId");
    const currency = data.currency;
    if (typeof currency !== "string" || !/^[A-Z]{3}$/.test(currency)) {
      throw new HttpsError("invalid-argument", "currency is not a code.");
    }

    return withStructuredLogs(
      {op: "changeEventCurrency", uid, args: {eventId}},
      async () => {
        const eventRef = db.collection("events").doc(eventId);
        await db.runTransaction(async (tx) => {
          const event = await tx.get(eventRef);
          if (!event.exists) {
            throw new HttpsError("not-found", "Event not found.");
          }
          const {creatorId, adminIds = [], currency: current} = event.data()!;
          if (creatorId !== uid && !adminIds.includes(uid)) {
            throw new HttpsError(
              "permission-denied",
              "Only an organizer can change the currency."
            );
          }
          // Nothing to do, so a retry after a lost response succeeds.
          if (current === currency) return;
          for (const name of MONEY_COLLECTIONS) {
            const money = await tx.get(eventRef.collection(name).limit(1));
            if (!money.empty) {
              throw new HttpsError(
                "failed-precondition",
                "Currency cannot change once the event has money recorded."
              );
            }
          }
          tx.update(eventRef, {
            currency,
            updatedAt: FieldValue.serverTimestamp(),
          });
        });
        return {success: true};
      }
    );
  }
);
