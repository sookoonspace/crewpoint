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

const {CATEGORY_CONFIG, buildApnsAps} = __INTERNAL;

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

    test('categories without actions omit apnsCategory', () => {
      // chat_urgent + member_joined have no action buttons; iOS renders
      // them as plain notifications.
      expect(CATEGORY_CONFIG.chat_urgent.apnsCategory).toBeUndefined();
      expect(CATEGORY_CONFIG.member_joined.apnsCategory).toBeUndefined();
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
