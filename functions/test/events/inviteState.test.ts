/**
 * Spec #233 Req 15 (GAP-ANY-02, GAP-ANY-03): whether an invite link can be
 * used now. Pure, so no emulator.
 */
import {Timestamp} from 'firebase-admin/firestore';
import {inviteState, inviteView} from '../../src/events/inviteState';

const NOW = Date.UTC(2027, 0, 10);
const later = Timestamp.fromMillis(NOW + 1000);
const earlier = Timestamp.fromMillis(NOW - 1000);

describe('inviteState', () => {
  test('an invite before expiry is active, as codes from before #238 are', () => {
    expect(inviteState({eventId: 'e', expiresAt: later}, NOW)).toBe('active');
  });

  test('an invite with no expiry keeps working, as joinEvent always allowed', () => {
    expect(inviteState({eventId: 'e'}, NOW)).toBe('active');
  });

  test('past its expiry it is expired', () => {
    expect(inviteState({expiresAt: earlier}, NOW)).toBe('expired');
    expect(inviteState({expiresAt: Timestamp.fromMillis(NOW)}, NOW)).toBe('expired');
  });

  test('a single-use link is used once someone joined with it', () => {
    expect(inviteState({expiresAt: later, singleUse: true}, NOW)).toBe('active');
    expect(inviteState({expiresAt: later, singleUse: true, usedBy: 'ravi'}, NOW)).toBe('used');
  });

  test('a link that allows many joins is never used up', () => {
    expect(inviteState({expiresAt: later, uses: 40}, NOW)).toBe('active');
  });

  test('turning off wins over every other state', () => {
    const off = {turnedOffAt: earlier};
    expect(inviteState({...off, expiresAt: later}, NOW)).toBe('off');
    expect(inviteState({...off, expiresAt: earlier}, NOW)).toBe('off');
    expect(inviteState({...off, expiresAt: later, singleUse: true, usedBy: 'x'}, NOW)).toBe('off');
  });

  test('a used link that has also expired reads as used', () => {
    expect(inviteState({expiresAt: earlier, singleUse: true, usedBy: 'x'}, NOW)).toBe('used');
  });
});

describe('inviteView', () => {
  test('what the app lists, with defaults for invites from before #238', () => {
    expect(inviteView('ABC234', {eventId: 'e', expiresAt: later, createdAt: earlier}, NOW)).toEqual({
      code: 'ABC234', roleId: 'participant', expiresAt: NOW + 1000, singleUse: false,
      uses: 0, usedAt: null, turnedOffAt: null, createdAt: NOW - 1000, state: 'active',
    });
  });

  test('a used single-use link', () => {
    expect(inviteView('XYZ789', {
      roleId: 'volunteer', expiresAt: later, singleUse: true, uses: 1, usedBy: 'u', usedAt: earlier,
    }, NOW)).toEqual(expect.objectContaining({
      roleId: 'volunteer', singleUse: true, uses: 1, usedAt: NOW - 1000, state: 'used', createdAt: null,
    }));
  });
});
