import {onSchedule} from "firebase-functions/v2/scheduler";
import {logger} from "firebase-functions/v2";
import {getStorage} from "firebase-admin/storage";

const KEEP_MS = 7 * 24 * 60 * 60 * 1000;

/** An uploaded import file is kept for 7 days at most (Req 44a). */
export function importFileExpired(created: Date, now: Date): boolean {
  return now.getTime() - created.getTime() > KEEP_MS;
}

/**
 * cleanupImports — daily, deletes import files older than 7 days that a
 * finished job has not already removed, such as a dry run never applied.
 */
export const cleanupImports = onSchedule(
  {schedule: "every 24 hours", timeoutSeconds: 300},
  async () => {
    const [files] = await getStorage().bucket().getFiles({
      prefix: "events/",
      matchGlob: "events/*/imports/*.csv",
    });
    const now = new Date();
    let removed = 0;
    for (const file of files) {
      const created = new Date(file.metadata.timeCreated ?? 0);
      if (!importFileExpired(created, now)) continue;
      await file.delete({ignoreNotFound: true});
      removed++;
    }
    logger.info("cleanupImports", {checked: files.length, removed});
  }
);
