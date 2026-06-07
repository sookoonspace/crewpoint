/**
 * Pure-helper guards for the Phase 6.1 daily-digest CF
 * (`onDigestSummary`). The CF wires Firestore reads + admin.messaging
 * around these helpers; pinning them keeps the time-window and
 * summary-text contracts visible without an emulator.
 */
import {
  isDigestHour,
  buildDigestPlaceholders,
  shouldFireDigest,
} from '../../src/events/onDigestSummary';

describe('isDigestHour', () => {
  test('returns true when recipient-local hour matches the target', () => {
    // 13:00 UTC == 09:00 EDT in May 2026 (UTC-4 with DST).
    expect(
      isDigestHour({
        timezone: 'America/New_York',
        now: new Date('2026-05-01T13:00:00Z'),
        targetHour: 9,
      }),
    ).toBe(true);
  });

  test('returns false when the recipient is not at the target hour', () => {
    expect(
      isDigestHour({
        timezone: 'America/New_York',
        now: new Date('2026-05-01T18:00:00Z'), // 14:00 local
        targetHour: 9,
      }),
    ).toBe(false);
  });

  test('returns false when timezone is null / empty', () => {
    expect(
      isDigestHour({
        timezone: null,
        now: new Date('2026-05-01T13:00:00Z'),
        targetHour: 9,
      }),
    ).toBe(false);
    expect(
      isDigestHour({
        timezone: '',
        now: new Date('2026-05-01T13:00:00Z'),
        targetHour: 9,
      }),
    ).toBe(false);
  });

  test('returns false on unknown timezone (Intl throws → defensive false)', () => {
    expect(
      isDigestHour({
        timezone: 'Made/Up_Zone',
        now: new Date('2026-05-01T13:00:00Z'),
        targetHour: 9,
      }),
    ).toBe(false);
  });

  test('handles Sydney (UTC+10 with DST → +11 in May)', () => {
    // 22:00 UTC on 2026-05-01 == 08:00 AEST (UTC+10, no DST in May).
    // Pin against 23:00 UTC == 09:00 AEST.
    expect(
      isDigestHour({
        timezone: 'Australia/Sydney',
        now: new Date('2026-04-30T23:00:00Z'),
        targetHour: 9,
      }),
    ).toBe(true);
  });
});

describe('shouldFireDigest', () => {
  test('false when dailyDigest pref is false', () => {
    expect(
      shouldFireDigest({
        dailyDigest: false,
        pushEnabled: true,
        unread: 5,
        pending: 2,
        openSettlements: 1,
      }),
    ).toBe(false);
  });

  test('false when master pushEnabled is false', () => {
    expect(
      shouldFireDigest({
        dailyDigest: true,
        pushEnabled: false,
        unread: 5,
        pending: 2,
        openSettlements: 1,
      }),
    ).toBe(false);
  });

  test('false when there is nothing to summarize (all zero)', () => {
    // No "good morning, you have zero things" pings.
    expect(
      shouldFireDigest({
        dailyDigest: true,
        pushEnabled: true,
        unread: 0,
        pending: 0,
        openSettlements: 0,
      }),
    ).toBe(false);
  });

  test('true when any single counter is non-zero', () => {
    expect(
      shouldFireDigest({
        dailyDigest: true,
        pushEnabled: true,
        unread: 1,
        pending: 0,
        openSettlements: 0,
      }),
    ).toBe(true);
    expect(
      shouldFireDigest({
        dailyDigest: true,
        pushEnabled: true,
        unread: 0,
        pending: 1,
        openSettlements: 0,
      }),
    ).toBe(true);
    expect(
      shouldFireDigest({
        dailyDigest: true,
        pushEnabled: true,
        unread: 0,
        pending: 0,
        openSettlements: 1,
      }),
    ).toBe(true);
  });
});

describe('buildDigestPlaceholders', () => {
  test('emits singular/plural variants for each counter', () => {
    const p = buildDigestPlaceholders({
      unread: 1,
      pending: 2,
      openSettlements: 3,
    });
    expect(p.unread).toBe('1');
    expect(p.pending).toBe('2');
    expect(p.openSettlements).toBe('3');
    // Pre-formatted summary line is the canonical body source for
    // the template — keeps templates language-flexible without
    // forcing each locale to do its own plural arithmetic.
    expect(p.summary).toBe(
      '1 unread message, 2 pending tasks, 3 open settlements',
    );
  });

  test('omits zero counters from the summary text', () => {
    const p = buildDigestPlaceholders({
      unread: 0,
      pending: 4,
      openSettlements: 0,
    });
    expect(p.summary).toBe('4 pending tasks');
  });

  test('handles singular vs plural correctly', () => {
    const oneOfEach = buildDigestPlaceholders({
      unread: 1,
      pending: 1,
      openSettlements: 1,
    });
    expect(oneOfEach.summary).toBe(
      '1 unread message, 1 pending task, 1 open settlement',
    );
    const manyOfEach = buildDigestPlaceholders({
      unread: 2,
      pending: 5,
      openSettlements: 3,
    });
    expect(manyOfEach.summary).toBe(
      '2 unread messages, 5 pending tasks, 3 open settlements',
    );
  });
});
