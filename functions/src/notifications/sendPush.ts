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
  /**
   * APNs `aps.category` — resolves to a `UNNotificationCategory` registered
   * in `ios/Runner/AppDelegate.swift` so iOS shows the matching action set
   * (e.g. MARK_DONE on task notifications). Omitted for categories that
   * don't ship an action — iOS then renders a plain notification.
   */
  apnsCategory?: string;
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
    apnsCategory: "TASK_CATEGORY",
  },
  expense_added: {
    prefKey: "payments",
    androidChannelId: "crewpoint_payments",
    iosThreadId: "payments",
    apnsCategory: "PAYMENT_CATEGORY",
  },
  settlement_disputed: {
    prefKey: "payments",
    androidChannelId: "crewpoint_payments",
    // Shares the iOS thread with expense_added so payment activity in an
    // event groups under a single notification stack.
    iosThreadId: "payments",
    apnsCategory: "PAYMENT_CATEGORY",
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
    apnsCategory: "TASK_CATEGORY",
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

type TokenOwner = {uid: string; token: string; criticalOptIn: boolean};

/**
 * Builds the iOS `apns.payload.aps` dict for one (category, recipient)
 * pair. Pure / side-effect free — exported for unit tests via __INTERNAL.
 *
 * `interruption-level` is only set for `chat_urgent`:
 *   - `criticalOptIn=true`  → `'critical'`     (requires Apple's
 *     `com.apple.developer.usernotifications.critical-alerts` entitlement;
 *     pierces Focus / DND on the device)
 *   - `criticalOptIn=false` → `'time-sensitive'` (default elevated
 *     priority for chat; respects Focus)
 *
 * Non-chat_urgent categories never receive an interruption-level — the
 * default behavior already matches their semantic priority and there is
 * no per-recipient pref to vary on.
 */
export function buildApnsAps(args: {
  category: NotificationCategory;
  criticalOptIn: boolean;
  cfg: CategoryConfig;
}): Record<string, unknown> {
  const aps: Record<string, unknown> = {
    "thread-id": args.cfg.iosThreadId,
  };
  if (args.cfg.apnsCategory) {
    aps.category = args.cfg.apnsCategory;
  }
  if (args.category === "chat_urgent") {
    aps["interruption-level"] = args.criticalOptIn ?
      "critical" :
      "time-sensitive";
  }
  return aps;
}

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
    // Read per-recipient DND-bypass opt-in. Default false; only
    // chat_urgent payloads use this for `apns.payload.aps.interruption-level`.
    const criticalOptIn = prefs.criticalOptIn === true;
    for (const token of tokens) {
      owners.push({uid, token, criticalOptIn});
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
  // sendEach (not sendEachForMulticast) so each Message can carry a
  // per-recipient apns payload — `chat_urgent`'s `interruption-level`
  // varies on the recipient's `criticalOptIn` flag.
  for (let i = 0; i < owners.length; i += FCM_BATCH_SIZE) {
    const chunk = owners.slice(i, i + FCM_BATCH_SIZE);
    const messages = chunk.map((owner) => ({
      token: owner.token,
      notification,
      data: messageData,
      android: {
        notification: {channelId: cfg.androidChannelId},
      },
      apns: {
        payload: {
          aps: buildApnsAps({
            category: args.category,
            criticalOptIn: owner.criticalOptIn,
            cfg,
          }),
        },
      },
    }));
    const response = await messaging.sendEach(messages);
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
export const __INTERNAL = {CATEGORY_CONFIG, buildApnsAps};
