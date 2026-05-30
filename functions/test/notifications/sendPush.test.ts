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

const {CATEGORY_CONFIG} = __INTERNAL;

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
});
