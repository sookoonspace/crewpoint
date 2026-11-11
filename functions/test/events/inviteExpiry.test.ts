/**
 * Req 56 (GAP-CON-01): an invite's expiry. The default stays 24 hours on
 * Blank and Party, and lasts until the event starts on other templates. An
 * organizer may set any time from now up to a whole registration period.
 * Pure.
 */
import {Timestamp} from 'firebase-admin/firestore';
import {
  MAX_INVITE_DAYS, checkInviteExpiry, defaultInviteExpiry,
} from '../../src/events/inviteExpiry';

const DAY = 24 * 60 * 60 * 1000;
const NOW = Date.UTC(2026, 10, 10, 12);
const start = (iso: string) => Timestamp.fromDate(new Date(iso));

describe('defaultInviteExpiry', () => {
  test('24 hours on Blank, Party, and events from before templates', () => {
    const later = start('2027-07-16T00:00:00Z');
    expect(defaultInviteExpiry({templateId: 'blank', startDate: later}, NOW)).toBe(NOW + DAY);
    expect(defaultInviteExpiry({templateId: 'party', startDate: later}, NOW)).toBe(NOW + DAY);
    expect(defaultInviteExpiry({startDate: later}, NOW)).toBe(NOW + DAY);
  });

  test('until the event starts on other templates, in its own time zone', () => {
    expect(defaultInviteExpiry({
      templateId: 'convention', startDate: start('2027-07-16T00:00:00Z'),
      dateOnly: true, timeZone: 'America/Chicago',
    }, NOW)).toBe(Date.UTC(2027, 6, 16, 5));
    expect(defaultInviteExpiry({
      templateId: 'wedding', startDate: start('2027-05-01T15:30:00Z'),
    }, NOW)).toBe(Date.UTC(2027, 4, 1, 15, 30));
  });

  test('24 hours when there is no start, or it has passed', () => {
    expect(defaultInviteExpiry({templateId: 'convention'}, NOW)).toBe(NOW + DAY);
    expect(defaultInviteExpiry({templateId: 'convention', startDate: start('2026-11-10T12:30:00Z')}, NOW))
      .toBe(NOW + DAY);
  });

  test('never beyond the longest an organizer could set', () => {
    expect(defaultInviteExpiry({templateId: 'convention', startDate: start('2030-01-01T00:00:00Z')}, NOW))
      .toBe(NOW + MAX_INVITE_DAYS * DAY);
  });
});

describe('checkInviteExpiry', () => {
  test('a whole registration period is allowed', () => {
    expect(checkInviteExpiry(NOW + 300 * DAY, NOW)).toBe(NOW + 300 * DAY);
    expect(checkInviteExpiry(NOW + MAX_INVITE_DAYS * DAY, NOW)).toBe(NOW + MAX_INVITE_DAYS * DAY);
  });

  test('refuses the past, the far future, and anything not a time', () => {
    for (const bad of [NOW - 1, NOW + 4 * 60 * 1000, NOW + (MAX_INVITE_DAYS + 1) * DAY, '2027-01-01', 1.5, NaN]) {
      expect(() => checkInviteExpiry(bad, NOW)).toThrow(expect.objectContaining({code: 'invalid-argument'}));
    }
  });
});
