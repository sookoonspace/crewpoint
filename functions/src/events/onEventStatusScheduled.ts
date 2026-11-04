import {onSchedule} from "firebase-functions/v2/scheduler";
import {logger} from "firebase-functions/v2";
import {getFirestore} from "firebase-admin/firestore";
import {clock} from "../utils/clock";
import {runStatusChanges} from "./eventStatus";

/**
 * onEventStatusScheduled — moves events to `live` at their start time and
 * `ended` after their end time. Events without dates stay as they are.
 */
export const onEventStatusScheduled = onSchedule(
  {schedule: "every 15 minutes", retryCount: 0},
  async () => {
    const changed = await runStatusChanges(
      getFirestore(),
      new Date(clock.now())
    );
    logger.info(`Event status changes: ${changed}`);
  }
);
