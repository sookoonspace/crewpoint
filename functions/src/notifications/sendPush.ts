import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";
import {shouldSuppress, QuietHoursPrefs} from "./suppress";
import {interpolate, loadTemplate} from "./templates";

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
  | "task_due"
  | "digest";

interface CategoryConfig {
  /** Field on `notificationPrefs` that gates this category. */
  prefKey:
    | "urgentChat"
    | "taskUpdates"
    | "payments"
    | "eventUpdates"
    | "dailyDigest";
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
    // Phase 5.1 — `CHAT_CATEGORY` carries the MUTE_EVENT action so a
    // recipient can pause the event for 8h directly from the lock
    // screen / banner. The action is registered in AppDelegate.swift;
    // FcmHandler.handleAction routes the resulting `mute_event` to
    // EventMuteRepository.muteEvent.
    apnsCategory: "CHAT_CATEGORY",
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
  digest: {
    // Phase 6.1 — opt-in morning summary. Lives on its own Android
    // channel + iOS thread so users can mute it in OS settings
    // independently of the per-event categories.
    prefKey: "dailyDigest",
    androidChannelId: "crewpoint_digest",
    iosThreadId: "digest",
  },
};

interface SendCategorizedPushArgs {
  recipientUids: string[];
  /** Excluded from the recipient list — never send a self-notification. */
  senderId?: string | null;
  category: NotificationCategory;
  /**
   * Owning event. Required for the Phase 5 event-mute lookup at
   * `users/{uid}/eventMutes/{eventId}`. Callers should also pass it
   * through `extraData.eventId` so the client deep-link payload still
   * carries it for tap routing.
   */
  eventId: string;
  /**
   * Fallback / non-localized title. Used as-is when [templateKey] is
   * omitted or the template lookup yields no entry for the recipient's
   * locale.
   */
  title: string;
  /** Fallback / non-localized body. See [title]. */
  body: string;
  /**
   * Phase 6 localization (optional). When provided, the CF resolves
   * `templates/{locale}.json[templateKey].title|body` for each recipient
   * — falling back to [title] / [body] when the template is missing.
   * [placeholders] populates `{{key}}` substitutions inside the
   * resolved template.
   */
  templateKey?: string;
  placeholders?: Record<string, string>;
  /** Goes into `data.deepLink` for in-app navigation on tap. */
  deepLink: string;
  /** Merged into `data` alongside `deepLink`. Values must be strings (FCM). */
  extraData?: Record<string, string>;
}

/**
 * Reads one entry from `private/profile.fcmTokens`. Phase 6.2 migrated
 * the schema from `string[]` → `{value, platform}[]`; this helper accepts
 * both so pre-migration installs keep receiving pushes.
 *
 * Returns the token string, or `null` for malformed entries (which the
 * caller skips).
 */
export function extractTokenValue(rawToken: unknown): string | null {
  if (typeof rawToken === "string") return rawToken;
  if (rawToken && typeof rawToken === "object") {
    const value = (rawToken as Record<string, unknown>).value;
    if (typeof value === "string") return value;
  }
  return null;
}

/**
 * Resolves the final (title, body) pair for one recipient. Pure helper
 * exported for unit tests via __INTERNAL.
 *
 * Resolution order per field:
 *   1. `loadTemplate(templateKey, field, locale)` — Phase 6 path
 *   2. literal `args.title` / `args.body` — back-compat fallback
 *
 * Interpolation runs on the resolved template (path 1) only — literal
 * args are emitted verbatim.
 */
export function resolveNotificationText(args: {
  title: string;
  body: string;
  templateKey: string | undefined;
  placeholders: Record<string, string> | undefined;
  locale: string | null | undefined;
}): {title: string; body: string} {
  if (!args.templateKey) {
    return {title: args.title, body: args.body};
  }
  const placeholders = args.placeholders ?? {};
  const tplTitle = loadTemplate(args.templateKey, "title", args.locale);
  const tplBody = loadTemplate(args.templateKey, "body", args.locale);
  return {
    title: tplTitle ? interpolate(tplTitle, placeholders) : args.title,
    body: tplBody ? interpolate(tplBody, placeholders) : args.body,
  };
}

interface SendResult {
  attempted: number;
  /** Recipients filtered out by pref or self-exclusion. */
  skipped: number;
}

type TokenOwner = {
  uid: string;
  token: string;
  /**
   * Phase 6.2 — original entry as written to Firestore (legacy `string`
   * or new `{value, platform}` object). [pruneDeadTokens] uses this for
   * the `arrayRemove` so the exact stored shape matches.
   */
  rawToken: unknown;
  criticalOptIn: boolean;
  /** Phase 6 — recipient's preferred locale, used to resolve the per-message
   *  notification text. Null means "use server default" (English). */
  locale: string | null;
};

/**
 * Read the recipient's `users/{uid}/eventMutes/{eventId}.mutedUntil`.
 * Returns `null` when the doc is missing / the field is the wrong
 * shape — handled identically by [shouldSuppress].
 */
async function readMutedUntil(
  db: admin.firestore.Firestore,
  uid: string,
  eventId: string
): Promise<unknown> {
  try {
    const snap = await db
      .collection("users")
      .doc(uid)
      .collection("eventMutes")
      .doc(eventId)
      .get();
    return snap.data()?.mutedUntil ?? null;
  } catch (e) {
    logger.warn(
      `eventMute read failed for ${uid}/${eventId}; treating as unmuted`,
      e
    );
    return null;
  }
}

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
  // Pinned "now" for the whole fan-out so every recipient gets the same
  // suppression window (avoids a recipient on the back end of the loop
  // being judged on a slightly newer clock).
  const now = new Date();

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
    // Read per-recipient DND-bypass opt-in. Default false; chat_urgent
    // payloads use this for `apns.payload.aps.interruption-level`, and
    // (Phase 5) the same flag is the documented bypass for quiet-hours
    // / event-mute suppression.
    const criticalOptIn = prefs.criticalOptIn === true;

    // Phase 5: per-recipient quiet-hours + event-mute suppression.
    const quietPrefs: QuietHoursPrefs = {
      quietHoursStart:
        typeof prefs.quietHoursStart === "number" ?
          prefs.quietHoursStart :
          null,
      quietHoursEnd:
        typeof prefs.quietHoursEnd === "number" ?
          prefs.quietHoursEnd :
          null,
      timezone: typeof prefs.timezone === "string" ? prefs.timezone : null,
    };
    const eventMutedUntil = await readMutedUntil(db, uid, args.eventId);
    if (
      shouldSuppress({
        category: args.category,
        criticalOptIn,
        prefs: quietPrefs,
        eventMutedUntil,
        now,
      })
    ) {
      logger.info(
        `Suppressing ${args.category} for ${uid} (quiet hours / event mute)`
      );
      skipped++;
      continue;
    }

    // Phase 6.2 — `fcmTokens` may carry either legacy plain strings or
    // new `{value, platform}` objects. [extractTokenValue] handles both
    // shapes; malformed entries are dropped.
    const rawTokens: unknown[] = Array.isArray(privateData?.fcmTokens) ?
      (privateData?.fcmTokens as unknown[]) :
      [];
    const locale = typeof prefs.locale === "string" ? prefs.locale : null;
    for (const raw of rawTokens) {
      const value = extractTokenValue(raw);
      if (value === null) continue;
      owners.push({uid, token: value, rawToken: raw, criticalOptIn, locale});
    }
  }

  if (owners.length === 0) {
    return {attempted: 0, skipped};
  }

  const messageData: Record<string, string> = {
    ...(args.extraData ?? {}),
    deepLink: args.deepLink,
    category: args.category,
  };

  const messaging = admin.messaging();
  const deadTokens: TokenOwner[] = [];
  // sendEach (not sendEachForMulticast) so each Message can carry a
  // per-recipient apns payload — `chat_urgent`'s `interruption-level`
  // varies on the recipient's `criticalOptIn` flag, and Phase 6
  // localization resolves title/body against the recipient's locale.
  for (let i = 0; i < owners.length; i += FCM_BATCH_SIZE) {
    const chunk = owners.slice(i, i + FCM_BATCH_SIZE);
    const messages = chunk.map((owner) => ({
      token: owner.token,
      notification: resolveNotificationText({
        title: args.title,
        body: args.body,
        templateKey: args.templateKey,
        placeholders: args.placeholders,
        locale: owner.locale,
      }),
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
  // Phase 6.2 — keys are the original Firestore shape (string OR
  // `{value, platform}` object). `arrayRemove` must match exactly,
  // so we feed the raw entry back.
  const byUid = new Map<string, unknown[]>();
  for (const owner of deadTokens) {
    const list = byUid.get(owner.uid) ?? [];
    list.push(owner.rawToken);
    byUid.set(owner.uid, list);
  }
  const batch = db.batch();
  for (const [uid, rawEntries] of byUid) {
    batch.set(
      db.collection("users").doc(uid).collection("private").doc("profile"),
      {
        fcmTokens: admin.firestore.FieldValue.arrayRemove(...rawEntries),
      },
      {merge: true}
    );
  }
  await batch.commit();
  logger.info(
    `Pruned ${deadTokens.length} dead FCM tokens for ${byUid.size} users`
  );
}

/** Test seam — internal helpers exported only for unit tests. */
export const __INTERNAL = {
  CATEGORY_CONFIG,
  buildApnsAps,
  resolveNotificationText,
  extractTokenValue,
};
