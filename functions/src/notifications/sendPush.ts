import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";

const FCM_BATCH_SIZE = 500;

/**
 * Notification category. Each value maps to:
 *   - an Android `channelId` (declared client-side in Phase 3c.1)
 *   - an APNs `thread-id` for iOS grouping
 *   - a per-recipient pref flag on `users/{uid}/private/profile.notificationPrefs`
 *
 * Phase 3a shipped `chat_urgent` + `task_assigned`; Phase 3c.2 added
 * `expense_added`; Phase 3c.3 added `settlement_disputed` (reuses payments
 * routing); Phase 3c.4 added `member_joined`; Phase 3c.5 adds `task_due`
 * (reuses task routing).
 */
export type NotificationCategory =
  | "chat_urgent"
  | "task_assigned"
  | "expense_added"
  | "settlement_disputed"
  | "member_joined"
  | "task_due";

interface CategoryConfig {
  /** Field on `notificationPrefs` that gates this category. */
  prefKey: "urgentChat" | "taskUpdates" | "payments" | "eventUpdates";
  /** Android channel id (client declares the channel; this is the routing key). */
  androidChannelId: string;
  /** APNs `aps.thread-id` for iOS grouping. */
  iosThreadId: string;
}

const CATEGORY_CONFIG: Record<NotificationCategory, CategoryConfig> = {
  chat_urgent: {
    prefKey: "urgentChat",
    androidChannelId: "crewpoint_chat_urgent",
    iosThreadId: "chat",
  },
  task_assigned: {
    prefKey: "taskUpdates",
    androidChannelId: "crewpoint_tasks",
    iosThreadId: "tasks",
  },
  expense_added: {
    prefKey: "payments",
    androidChannelId: "crewpoint_payments",
    iosThreadId: "payments",
  },
  settlement_disputed: {
    prefKey: "payments",
    androidChannelId: "crewpoint_payments",
    // Shares the iOS thread with expense_added so payment activity in an
    // event groups under a single notification stack.
    iosThreadId: "payments",
  },
  member_joined: {
    prefKey: "eventUpdates",
    androidChannelId: "crewpoint_events",
    iosThreadId: "events",
  },
  task_due: {
    prefKey: "taskUpdates",
    androidChannelId: "crewpoint_tasks",
    // Shares the iOS thread with task_assigned so task activity in an
    // event groups under a single notification stack.
    iosThreadId: "tasks",
  },
};

interface SendCategorizedPushArgs {
  recipientUids: string[];
  /** Excluded from the recipient list — never send a self-notification. */
  senderId?: string | null;
  category: NotificationCategory;
  title: string;
  body: string;
  /** Goes into `data.deepLink` for in-app navigation on tap. */
  deepLink: string;
  /** Merged into `data` alongside `deepLink`. Values must be strings (FCM). */
  extraData?: Record<string, string>;
}

interface SendResult {
  attempted: number;
  /** Recipients filtered out by pref or self-exclusion. */
  skipped: number;
}

type TokenOwner = {uid: string; token: string};

/**
 * Fans out a categorized push.
 *
 *  1. Filters recipients by `senderId` exclusion + per-recipient prefs
 *     (`pushEnabled` master AND the category-specific flag).
 *  2. Collects all `(uid, token)` pairs from `private/profile.fcmTokens`.
 *  3. Sends in 500-token chunks via `sendEachForMulticast` with the
 *     correct Android channel id + iOS thread id.
 *  4. Prunes dead tokens from Firestore (`registration-token-not-registered`,
 *     `invalid-argument`).
 *
 * Best-effort: the caller is expected to set `retry: false` on the trigger
 * so duplicate sends don't fire on retry storms.
 */
export async function sendCategorizedPush(
  args: SendCategorizedPushArgs
): Promise<SendResult> {
  const cfg = CATEGORY_CONFIG[args.category];
  const db = admin.firestore();

  const owners: TokenOwner[] = [];
  let skipped = 0;

  for (const uid of args.recipientUids) {
    if (args.senderId && uid === args.senderId) {
      skipped++;
      continue;
    }
    const privateSnap = await db
      .collection("users")
      .doc(uid)
      .collection("private")
      .doc("profile")
      .get();
    const privateData = privateSnap.data();
    const prefs =
      (privateData?.notificationPrefs as Record<string, unknown> | undefined) ??
      {};
    const pushEnabled = prefs.pushEnabled !== false;
    const categoryEnabled = prefs[cfg.prefKey] !== false;
    if (!pushEnabled || !categoryEnabled) {
      logger.info(
        `Skipping ${args.category} push for ${uid}` +
          ` (pushEnabled=${pushEnabled}, ${cfg.prefKey}=${categoryEnabled})`
      );
      skipped++;
      continue;
    }
    const tokens =
      (privateData?.fcmTokens as string[] | undefined) ?? [];
    for (const token of tokens) {
      owners.push({uid, token});
    }
  }

  if (owners.length === 0) {
    return {attempted: 0, skipped};
  }

  const notification = {title: args.title, body: args.body};
  const messageData: Record<string, string> = {
    ...(args.extraData ?? {}),
    deepLink: args.deepLink,
    category: args.category,
  };

  const messaging = admin.messaging();
  const deadTokens: TokenOwner[] = [];
  for (let i = 0; i < owners.length; i += FCM_BATCH_SIZE) {
    const chunk = owners.slice(i, i + FCM_BATCH_SIZE);
    const response = await messaging.sendEachForMulticast({
      tokens: chunk.map((o) => o.token),
      notification,
      data: messageData,
      android: {
        notification: {channelId: cfg.androidChannelId},
      },
      apns: {
        payload: {
          aps: {
            "thread-id": cfg.iosThreadId,
          },
        },
      },
    });
    response.responses.forEach((res, idx) => {
      if (res.success) return;
      const code = res.error?.code ?? "";
      if (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-argument"
      ) {
        deadTokens.push(chunk[idx]);
      }
    });
  }

  if (deadTokens.length > 0) {
    await pruneDeadTokens(db, deadTokens);
  }

  return {attempted: owners.length, skipped};
}

async function pruneDeadTokens(
  db: admin.firestore.Firestore,
  deadTokens: TokenOwner[]
): Promise<void> {
  const byUid = new Map<string, string[]>();
  for (const owner of deadTokens) {
    const list = byUid.get(owner.uid) ?? [];
    list.push(owner.token);
    byUid.set(owner.uid, list);
  }
  const batch = db.batch();
  for (const [uid, tokens] of byUid) {
    batch.set(
      db.collection("users").doc(uid).collection("private").doc("profile"),
      {
        fcmTokens: admin.firestore.FieldValue.arrayRemove(...tokens),
      },
      {merge: true}
    );
  }
  await batch.commit();
  logger.info(
    `Pruned ${deadTokens.length} dead FCM tokens for ${byUid.size} users`
  );
}

/** Test seam — internal helper exported only for unit tests. */
export const __INTERNAL = {CATEGORY_CONFIG};
