/**
 * Spec #233 Req 10, 13a, 14 (#240): what the public event page may show.
 * Pure, so no emulator.
 */
import {Timestamp} from 'firebase-admin/firestore';
import {publicEventView} from '../../src/registration/publicEvent';
import {DEFAULT_REGISTRATION} from '../../src/registration/settings';

const NOW = Date.UTC(2027, 0, 10);
const DAY = 24 * 60 * 60 * 1000;

const event = (over: Record<string, unknown> = {}) => ({
  title: 'Convention 2027',
  description: 'Three days together in Chicago.',
  status: 'published',
  startDate: Timestamp.fromMillis(Date.UTC(2027, 6, 16)),
  endDate: Timestamp.fromMillis(Date.UTC(2027, 6, 18)),
  dateOnly: true,
  timeZone: 'America/Chicago',
  venues: [{id: 'v1', name: 'Hall A', address: '1 Main St', mapUrl: 'https://maps.example/a', directions: 'Door 3'}],
  capacity: 400,
  memberIds: ['owner', 'secret-member'],
  adminIds: ['owner'],
  creatorId: 'owner',
  currency: 'USD',
  labels: {group: {one: 'Family', other: 'Families'}},
  cover: {path: 'events/evt/cover.jpg', updatedAt: Timestamp.fromMillis(NOW)},
  ...over,
});
const registration = (over: object = {}) => ({
  ...DEFAULT_REGISTRATION, mode: 'open' as const, slug: 'convention-2027',
  included: {en: 'Lunch and dinner'}, ...over,
});

// Typed loosely, so tests can read fields a draft's view leaves out.
const view = (e = event(), r = registration(), used = 0): any =>
  publicEventView({event: e, registration: r, placesUsed: used, now: NOW});

describe('publicEventView', () => {
  test('#244: carries the contact line for the closed page', () => {
    expect(view(event(), registration({contactLine: {en: 'Call Nilesh'}})).contactLine).toEqual({en: 'Call Nilesh'});
    expect(view().contactLine).toBeNull();
  });

  test('an open event shows only its public fields', () => {
    const v = view();
    expect(v).toEqual({
      contactLine: null,
      state: 'open',
      slug: 'convention-2027',
      title: 'Convention 2027',
      description: 'Three days together in Chicago.',
      startDate: Date.UTC(2027, 6, 16),
      endDate: Date.UTC(2027, 6, 18),
      dateOnly: true,
      timeZone: 'America/Chicago',
      venues: [{name: 'Hall A', address: '1 Main St', mapUrl: 'https://maps.example/a', directions: 'Door 3'}],
      included: {en: 'Lunch and dinner'},
      deadline: null,
      mode: 'open',
      placesRemain: true,
      hasCover: true,
      labels: {group: {one: 'Family', other: 'Families'}},
    });
    // Never the ID, members, money or counts.
    const text = JSON.stringify(v);
    for (const hidden of ['evt', 'secret-member', 'owner', 'USD', '400', 'capacity']) {
      expect(text).not.toContain(hidden);
    }
  });

  test('a full event says only that it is full, never a number', () => {
    const v = view(event(), registration(), 400);
    expect(v.placesRemain).toBe(false);
    expect(JSON.stringify(v)).not.toContain('400');
  });

  test('no capacity means places remain', () => {
    expect(view(event({capacity: null}), registration(), 9999).placesRemain).toBe(true);
  });

  test('a draft shows "not open yet" and nothing else', () => {
    expect(view(event({status: 'draft'}))).toEqual({state: 'notOpen'});
  });

  test('an ended or archived event has closed', () => {
    expect(view(event({status: 'ended'})).state).toBe('closed');
    expect(view(event({status: 'archived'})).state).toBe('closed');
  });

  test('registration closes at the deadline', () => {
    expect(view(event(), registration({deadline: NOW + DAY})).state).toBe('open');
    const after = view(event(), registration({deadline: NOW - 1}));
    expect(after.state).toBe('closed');
    expect(after.deadline).toBe(NOW - 1);
  });

  test('an older event with no status reads as published until it ends', () => {
    expect(view(event({status: undefined})).state).toBe('open');
    expect(view(event({status: 'active', endDate: Timestamp.fromMillis(NOW - DAY)})).state).toBe('closed');
  });

  test('an invited event shows the page but registers only through personal links', () => {
    expect(view(event(), registration({mode: 'invited'})).mode).toBe('invited');
  });
});
