/**
 * Unit-level guards for the due-reminder selection logic.
 *
 * The CF runs every 15 minutes and scans a 24h window. The helpers
 * below decide which tasks get a reminder. Pinning them keeps the scan
 * from misfiring (e.g. pinging "done" tasks, repushing the same
 * reminder, or spamming tasks 48h out).
 */
import {
  isDueSoon,
  shouldSendReminder,
} from '../../src/events/onTaskDueScheduled';

describe('isDueSoon', () => {
  const now = new Date('2026-05-30T12:00:00Z');

  test('returns true for a dueDate inside the 24h window', () => {
    const due = new Date('2026-05-30T18:00:00Z'); // +6h
    expect(isDueSoon(due, now, 24)).toBe(true);
  });

  test('returns true at the upper window edge', () => {
    const due = new Date('2026-05-31T12:00:00Z'); // exactly +24h
    expect(isDueSoon(due, now, 24)).toBe(true);
  });

  test('returns false for a dueDate past the window', () => {
    const due = new Date('2026-06-01T12:01:00Z'); // +48h + 1min
    expect(isDueSoon(due, now, 24)).toBe(false);
  });

  test('returns false for a dueDate already in the past', () => {
    const due = new Date('2026-05-30T11:00:00Z'); // -1h
    expect(isDueSoon(due, now, 24)).toBe(false);
  });

  test('returns false for null dueDate (no due date set)', () => {
    expect(isDueSoon(null, now, 24)).toBe(false);
  });
});

describe('shouldSendReminder', () => {
  test('true when status=todo + reminderSent=false + assigneeId set', () => {
    expect(
      shouldSendReminder({
        status: 'todo',
        reminderSent: false,
        assigneeId: 'u1',
      })
    ).toBe(true);
  });

  test('true when status=inProgress', () => {
    expect(
      shouldSendReminder({
        status: 'inProgress',
        reminderSent: false,
        assigneeId: 'u1',
      })
    ).toBe(true);
  });

  test('false when status=done', () => {
    expect(
      shouldSendReminder({
        status: 'done',
        reminderSent: false,
        assigneeId: 'u1',
      })
    ).toBe(false);
  });

  test('false when reminderSent=true (idempotent re-runs)', () => {
    expect(
      shouldSendReminder({
        status: 'todo',
        reminderSent: true,
        assigneeId: 'u1',
      })
    ).toBe(false);
  });

  test('false when no assigneeId (nobody to remind)', () => {
    expect(
      shouldSendReminder({
        status: 'todo',
        reminderSent: false,
        assigneeId: null,
      })
    ).toBe(false);
  });

  test('treats undefined reminderSent as false (legacy docs)', () => {
    expect(
      shouldSendReminder({
        status: 'todo',
        reminderSent: undefined,
        assigneeId: 'u1',
      })
    ).toBe(true);
  });
});
