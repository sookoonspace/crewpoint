/**
 * Unit-level guards for the `sendCategorizedPush` routing table.
 *
 * The category→channel/pref mapping is the single source of truth for
 * which Android channel a push lands on + which `NotificationPrefs`
 * field gates it. A typo here silently misroutes pushes (e.g. payments
 * notifications would inherit task-channel sound + bypass the wrong
 * pref check). Pin the table with explicit assertions.
 *
 * No emulator interaction — pure module import.
 */
import {__INTERNAL} from '../../src/notifications/sendPush';

const {
  CATEGORY_CONFIG,
  buildApnsAps,
  resolveNotificationText,
  extractTokenValue,
} = __INTERNAL;

describe('sendCategorizedPush CATEGORY_CONFIG', () => {
  test('chat_urgent routes to crewpoint_chat_urgent + urgentChat pref', () => {
    expect(CATEGORY_CONFIG.chat_urgent.androidChannelId).toBe(
      'crewpoint_chat_urgent'
    );
    expect(CATEGORY_CONFIG.chat_urgent.prefKey).toBe('urgentChat');
  });

  test('task_assigned routes to crewpoint_tasks + taskUpdates pref', () => {
    expect(CATEGORY_CONFIG.task_assigned.androidChannelId).toBe(
      'crewpoint_tasks'
    );
    expect(CATEGORY_CONFIG.task_assigned.prefKey).toBe('taskUpdates');
  });

  test('expense_added routes to crewpoint_payments + payments pref', () => {
    expect(CATEGORY_CONFIG.expense_added.androidChannelId).toBe(
      'crewpoint_payments'
    );
    expect(CATEGORY_CONFIG.expense_added.prefKey).toBe('payments');
  });

  test('settlement_disputed reuses the payments channel + pref', () => {
    expect(CATEGORY_CONFIG.settlement_disputed.androidChannelId).toBe(
      'crewpoint_payments'
    );
    expect(CATEGORY_CONFIG.settlement_disputed.prefKey).toBe('payments');
    // Shares the iOS thread with expense_added so payment activity in an
    // event groups under a single notification stack.
    expect(CATEGORY_CONFIG.settlement_disputed.iosThreadId).toBe(
      CATEGORY_CONFIG.expense_added.iosThreadId
    );
  });

  test('member_joined routes to crewpoint_events + eventUpdates pref', () => {
    expect(CATEGORY_CONFIG.member_joined.androidChannelId).toBe(
      'crewpoint_events'
    );
    expect(CATEGORY_CONFIG.member_joined.prefKey).toBe('eventUpdates');
  });

  test('task_due shares the tasks channel + pref with task_assigned', () => {
    expect(CATEGORY_CONFIG.task_due.androidChannelId).toBe('crewpoint_tasks');
    expect(CATEGORY_CONFIG.task_due.prefKey).toBe('taskUpdates');
    // Shares the iOS thread with task_assigned so task activity groups
    // under a single notification stack.
    expect(CATEGORY_CONFIG.task_due.iosThreadId).toBe(
      CATEGORY_CONFIG.task_assigned.iosThreadId
    );
  });

  describe('apnsCategory routing (Phase 3c.6)', () => {
    test('task_assigned + task_due bind TASK_CATEGORY (MARK_DONE action set)', () => {
      expect(CATEGORY_CONFIG.task_assigned.apnsCategory).toBe('TASK_CATEGORY');
      expect(CATEGORY_CONFIG.task_due.apnsCategory).toBe('TASK_CATEGORY');
    });

    test('expense_added + settlement_disputed bind PAYMENT_CATEGORY (VIEW_EXPENSE action set)', () => {
      expect(CATEGORY_CONFIG.expense_added.apnsCategory).toBe(
        'PAYMENT_CATEGORY'
      );
      expect(CATEGORY_CONFIG.settlement_disputed.apnsCategory).toBe(
        'PAYMENT_CATEGORY'
      );
    });

    test('chat_urgent binds CHAT_CATEGORY (MUTE_EVENT action — Phase 5.1)', () => {
      expect(CATEGORY_CONFIG.chat_urgent.apnsCategory).toBe('CHAT_CATEGORY');
    });

    test('member_joined omits apnsCategory (no action set)', () => {
      expect(CATEGORY_CONFIG.member_joined.apnsCategory).toBeUndefined();
    });
  });

  describe('resolveNotificationText (Phase 6 localization)', () => {
    test('returns literal title/body when no templateKey provided (back-compat)', () => {
      const {title, body} = resolveNotificationText({
        title: 'Literal title',
        body: 'Literal body',
        templateKey: undefined,
        placeholders: undefined,
        locale: null,
      });
      expect(title).toBe('Literal title');
      expect(body).toBe('Literal body');
    });

    test('uses the recipient locale template when templateKey provided', () => {
      const {title, body} = resolveNotificationText({
        title: 'fallback title',
        body: 'fallback body',
        templateKey: 'chat_urgent',
        placeholders: {eventTitle: 'Trip', body: 'Bear in camp'},
        locale: 'en',
      });
      expect(title).toBe('🚨 Urgent in Trip');
      expect(body).toBe('Bear in camp');
    });

    test('falls back to literal title/body when template field is missing', () => {
      // `chat_urgent` has no `subtitle` field in en.json — caller's
      // literal fallback wins.
      const {title, body} = resolveNotificationText({
        title: 'fallback title',
        body: 'fallback body',
        templateKey: 'undefined_category',
        placeholders: {},
        locale: 'en',
      });
      expect(title).toBe('fallback title');
      expect(body).toBe('fallback body');
    });

    test('interpolates per-recipient even when CF passes the same placeholders', () => {
      // Same placeholders for two recipients with different locales —
      // both currently resolve to en (es not yet registered), so the
      // strings match. Pinning this so adding `es.json` later breaks
      // the test deliberately + forces a deliberate update.
      const en = resolveNotificationText({
        title: 'x',
        body: 'x',
        templateKey: 'task_assigned',
        placeholders: {eventTitle: 'Trip', taskTitle: 'Buy beer'},
        locale: 'en',
      });
      const es = resolveNotificationText({
        title: 'x',
        body: 'x',
        templateKey: 'task_assigned',
        placeholders: {eventTitle: 'Trip', taskTitle: 'Buy beer'},
        locale: 'es',
      });
      expect(en.title).toBe('New task in Trip');
      // No `es.json` yet → base-language fallback → en.
      expect(es.title).toBe(en.title);
    });
  });

  describe('extractTokenValue back-compat reader (Phase 6.2)', () => {
    // Phase 6.2 introduces platform-tagged tokens stored as
    // `{value, platform}` objects. Plain-string tokens written by older
    // builds must still be readable so we don't lose delivery to
    // pre-migration installs.
    test('returns the string verbatim for legacy plain-string tokens', () => {
      expect(extractTokenValue('fcm-legacy-token-abc')).toBe(
        'fcm-legacy-token-abc'
      );
    });

    test('returns the `.value` field for new object-shape tokens', () => {
      expect(
        extractTokenValue({value: 'fcm-web-token-xyz', platform: 'web'})
      ).toBe('fcm-web-token-xyz');
      expect(
        extractTokenValue({value: 'fcm-mobile-token', platform: 'mobile'})
      ).toBe('fcm-mobile-token');
    });

    test('returns null for malformed entries (missing/wrong-type value)', () => {
      expect(extractTokenValue(null)).toBeNull();
      expect(extractTokenValue(undefined)).toBeNull();
      expect(extractTokenValue(42)).toBeNull();
      expect(extractTokenValue({})).toBeNull();
      expect(extractTokenValue({platform: 'web'})).toBeNull();
      expect(extractTokenValue({value: 7, platform: 'web'})).toBeNull();
    });
  });

  describe('buildApnsAps interruption-level (Phase 4)', () => {
    test('chat_urgent + criticalOptIn=true → interruption-level "critical"', () => {
      const aps = buildApnsAps({
        category: 'chat_urgent',
        criticalOptIn: true,
        cfg: CATEGORY_CONFIG.chat_urgent,
      });
      expect(aps['interruption-level']).toBe('critical');
      expect(aps['thread-id']).toBe('chat');
    });

    test('chat_urgent + criticalOptIn=false → interruption-level "time-sensitive"', () => {
      const aps = buildApnsAps({
        category: 'chat_urgent',
        criticalOptIn: false,
        cfg: CATEGORY_CONFIG.chat_urgent,
      });
      expect(aps['interruption-level']).toBe('time-sensitive');
    });

    test('non-chat_urgent categories never set interruption-level (irrespective of criticalOptIn)', () => {
      for (const category of [
        'task_assigned',
        'task_due',
        'expense_added',
        'settlement_disputed',
        'member_joined',
      ] as const) {
        const aps = buildApnsAps({
          category,
          criticalOptIn: true,
          cfg: CATEGORY_CONFIG[category],
        });
        expect(aps['interruption-level']).toBeUndefined();
      }
    });

    test('preserves existing apnsCategory + thread-id wiring', () => {
      const aps = buildApnsAps({
        category: 'task_assigned',
        criticalOptIn: false,
        cfg: CATEGORY_CONFIG.task_assigned,
      });
      expect(aps['thread-id']).toBe('tasks');
      expect(aps.category).toBe('TASK_CATEGORY');
    });
  });
});
