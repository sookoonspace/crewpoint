import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import {sendCategorizedPush} from "../notifications/sendPush";

/**
 * Returns the uids that appear in [after] but not in [before].
 * Order matches the order they appear in [after].
 *
 * When [before] is `undefined` the doc is being created — the creator
 * populates the initial `memberIds`, so we explicitly return `[]` so the
 * trigger does not announce "new member" on event creation.
 */
export function newJoiners(
  before: string[] | undefined,
  after: string[]
): string[] {
  if (!before) return [];
  const beforeSet = new Set(before);
  return after.filter((uid) => !beforeSet.has(uid));
}

/**
 * onMemberJoined — fires on every write to `events/{eventId}` and pushes
 * each net-new member's join to the event's admin set.
 *
 * The trigger needs both `before` and `after` snapshots to compute the
 * delta, so it's `onDocumentWritten` rather than the cheaper
 * `onDocumentCreated`. Admins receive one push per joiner (batch joins
 * fan out one push per delta uid), with deep-link to the members screen
 * so the admin can vet who joined.
 *
 * Best-effort: not retried on failure.
 */
export const onMemberJoined = onDocumentWritten(
  {
    document: "events/{eventId}",
    timeoutSeconds: 30,
    retry: false,
  },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();

    if (!after) return; // delete — nothing to notify

    const beforeMembers = (before?.memberIds as string[] | undefined) ?? undefined;
    const afterMembers = (after.memberIds as string[] | undefined) ?? [];
    const joiners = newJoiners(beforeMembers, afterMembers);
    if (joiners.length === 0) return;

    const eventId = event.params.eventId;
    const eventTitle = (after.title as string | undefined) ?? "Event";
    const adminIds = (after.adminIds as string[] | undefined) ?? [];

    if (adminIds.length === 0) {
      logger.warn(
        `onMemberJoined: event ${eventId} has no admins to notify ` +
          `(${joiners.length} joiner(s))`
      );
      return;
    }

    for (const joiner of joiners) {
      // Recipients = admins minus the joiner (in case a future flow lands
      // them in both arrays at once).
      const recipientUids = adminIds.filter((uid) => uid !== joiner);
      if (recipientUids.length === 0) continue;

      const result = await sendCategorizedPush({
        recipientUids,
        senderId: joiner,
        category: "member_joined",
        title: `New member in ${eventTitle}`,
        body: "Tap to review the member list.",
        deepLink: `/dashboard/event/${eventId}/members`,
        extraData: {eventId, joinerId: joiner},
      });

      logger.info(
        `Member-joined push for ${joiner} in ${eventId}:` +
          ` ${result.attempted} attempted, ${result.skipped} skipped`
      );
    }
  }
);
