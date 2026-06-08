/**
 * Pure-helper guards for the Phase 5 suppression rules.
 *
 * `sendCategorizedPush` skips a recipient when EITHER:
 *   (a) the current wall-clock in the recipient's timezone falls
 *       inside `notificationPrefs.quietHoursStart`..`quietHoursEnd`
 *       AND the category is NOT `chat_urgent` (Option B bypass), OR
 *   (b) the recipient has an active `eventMutes/{eventId}` doc
 *       (`mutedUntil >= now`) — `chat_urgent` obeys this too.
 *
 * Phase 4 critical-alert opt-in withdrawn for V1/V2 — there is no
 * per-recipient bypass any more. `chat_urgent` always pierces quiet
 * hours; per-event mute always wins.
 */
import {
  isWithinQuietHours,
  isMutedUntilAfter,
  shouldSuppress,
} from '../../src/notifications/suppress';

describe('isWithinQuietHours', () => {
  test('returns false when any of the three fields is null', () => {
    const at = new Date('2026-05-01T02:00:00Z');
    expect(
      isWithinQuietHours(
        {quietHoursStart: null, quietHoursEnd: 7 * 60, timezone: 'UTC'},
        at,
      ),
    ).toBe(false);
    expect(
      isWithinQuietHours(
        {quietHoursStart: 22 * 60, quietHoursEnd: null, timezone: 'UTC'},
        at,
      ),
    ).toBe(false);
    expect(
      isWithinQuietHours(
        {quietHoursStart: 22 * 60, quietHoursEnd: 7 * 60, timezone: null},
        at,
      ),
    ).toBe(false);
  });

  test('intra-day window (09:00-17:00 UTC) — inside vs outside', () => {
    const prefs = {
      quietHoursStart: 9 * 60,
      quietHoursEnd: 17 * 60,
      timezone: 'UTC',
    };
    // 12:30 UTC → inside
    expect(
      isWithinQuietHours(prefs, new Date('2026-05-01T12:30:00Z')),
    ).toBe(true);
    // 08:59 UTC → outside (one minute before window opens)
    expect(
      isWithinQuietHours(prefs, new Date('2026-05-01T08:59:00Z')),
    ).toBe(false);
    // 17:00 UTC → outside (end is exclusive — window is [start, end))
    expect(
      isWithinQuietHours(prefs, new Date('2026-05-01T17:00:00Z')),
    ).toBe(false);
  });

  test(
    'overnight window (22:00-07:00) crosses midnight — both halves muted',
    () => {
      const prefs = {
        quietHoursStart: 22 * 60,
        quietHoursEnd: 7 * 60,
        timezone: 'UTC',
      };
      // 23:30 UTC → inside (post-start, pre-midnight half)
      expect(
        isWithinQuietHours(prefs, new Date('2026-05-01T23:30:00Z')),
      ).toBe(true);
      // 02:00 UTC → inside (post-midnight, pre-end half)
      expect(
        isWithinQuietHours(prefs, new Date('2026-05-01T02:00:00Z')),
      ).toBe(true);
      // 09:00 UTC → outside
      expect(
        isWithinQuietHours(prefs, new Date('2026-05-01T09:00:00Z')),
      ).toBe(false);
      // 21:59 UTC → outside (one minute before window opens)
      expect(
        isWithinQuietHours(prefs, new Date('2026-05-01T21:59:00Z')),
      ).toBe(false);
    },
  );

  test(
    'timezone-aware: 22:00-07:00 in America/New_York maps wall-clock to UTC',
    () => {
      const prefs = {
        quietHoursStart: 22 * 60,
        quietHoursEnd: 7 * 60,
        timezone: 'America/New_York',
      };
      // 03:00 UTC == 23:00 EDT (UTC-4 in May) → inside
      expect(
        isWithinQuietHours(prefs, new Date('2026-05-01T03:00:00Z')),
      ).toBe(true);
      // 13:00 UTC == 09:00 EDT → outside
      expect(
        isWithinQuietHours(prefs, new Date('2026-05-01T13:00:00Z')),
      ).toBe(false);
    },
  );
});

describe('isMutedUntilAfter', () => {
  test('returns true while mutedUntil >= now (inclusive)', () => {
    const now = new Date('2026-05-01T12:00:00Z');
    expect(
      isMutedUntilAfter('2026-05-01T12:00:00.000Z', now),
    ).toBe(true);
    expect(
      isMutedUntilAfter('2026-05-01T13:00:00.000Z', now),
    ).toBe(true);
  });

  test('returns false once mutedUntil is in the past', () => {
    const now = new Date('2026-05-01T12:00:00Z');
    expect(
      isMutedUntilAfter('2026-05-01T11:59:59.000Z', now),
    ).toBe(false);
  });

  test('returns false on null / undefined / wrong type / unparseable', () => {
    const now = new Date('2026-05-01T12:00:00Z');
    expect(isMutedUntilAfter(null, now)).toBe(false);
    expect(isMutedUntilAfter(undefined, now)).toBe(false);
    expect(isMutedUntilAfter(42, now)).toBe(false);
    expect(isMutedUntilAfter('not-a-date', now)).toBe(false);
  });
});

describe('shouldSuppress', () => {
  const quietPrefs = {
    quietHoursStart: 22 * 60,
    quietHoursEnd: 7 * 60,
    timezone: 'UTC',
  };
  const within = new Date('2026-05-01T03:00:00Z'); // inside the window
  const noMute = {
    quietHoursStart: null,
    quietHoursEnd: null,
    timezone: null,
  };

  test('non-urgent in quiet hours → suppress', () => {
    expect(
      shouldSuppress({
        category: 'task_assigned',
        prefs: quietPrefs,
        eventMutedUntil: null,
        now: within,
      }),
    ).toBe(true);
  });

  test('chat_urgent in quiet hours → NOT suppressed (Option B bypass)', () => {
    expect(
      shouldSuppress({
        category: 'chat_urgent',
        prefs: quietPrefs,
        eventMutedUntil: null,
        now: within,
      }),
    ).toBe(false);
  });

  test('non-urgent suppressed by active event mute', () => {
    expect(
      shouldSuppress({
        category: 'task_assigned',
        prefs: noMute,
        eventMutedUntil: '2026-05-01T12:00:00.000Z',
        now: new Date('2026-05-01T11:59:00Z'),
      }),
    ).toBe(true);
  });

  test(
    'chat_urgent obeys event mute (Option B — explicit per-event silence wins)',
    () => {
      expect(
        shouldSuppress({
          category: 'chat_urgent',
          prefs: noMute,
          eventMutedUntil: '2026-05-01T12:00:00.000Z',
          now: new Date('2026-05-01T11:59:00Z'),
        }),
      ).toBe(true);
    },
  );

  test('no quiet hours + no event mute → never suppress', () => {
    expect(
      shouldSuppress({
        category: 'task_assigned',
        prefs: noMute,
        eventMutedUntil: null,
        now: new Date(),
      }),
    ).toBe(false);
  });
});
