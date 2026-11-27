/**
 * Spec #233 Req 32, 32a, 33, 34 (#242): the pure capacity rules. A group
 * takes places whole or waits whole; freed places go to the first waiting
 * group that fits.
 */
import {allocate, expireOffers, nextGroupThatFits, planOffers} from '../../src/registration/allocate';

describe('allocate', () => {
  test('a group that fits is submitted and takes its places', () => {
    expect(allocate({capacity: 10, placesUsed: 6, held: 0, size: 4, review: false}))
      .toEqual({status: 'submitted', placesUsed: 10});
  });

  test('a group that does not fit waits whole, and keeps no places', () => {
    expect(allocate({capacity: 10, placesUsed: 8, held: 0, size: 3, review: false}))
      .toEqual({status: 'waitlisted', placesUsed: 8});
  });

  test('places held by open offers are not free', () => {
    expect(allocate({capacity: 10, placesUsed: 6, held: 2, size: 3, review: false}).status)
      .toBe('waitlisted');
  });

  test('with review on, a group that fits is pending and still takes its places', () => {
    expect(allocate({capacity: 10, placesUsed: 0, held: 0, size: 2, review: true}))
      .toEqual({status: 'pending', placesUsed: 2});
  });

  test('no capacity means everyone fits', () => {
    expect(allocate({capacity: null, placesUsed: 900, held: 0, size: 7, review: false}).status)
      .toBe('submitted');
  });
});

describe('nextGroupThatFits', () => {
  const queue = [
    {registrationId: 'big', size: 5, position: 1},
    {registrationId: 'pair', size: 2, position: 2},
    {registrationId: 'solo', size: 1, position: 3},
  ];

  test('the first waiting group in queue order that fits the free places', () => {
    expect(nextGroupThatFits(queue, 5)).toBe('big');
    expect(nextGroupThatFits(queue, 3)).toBe('pair');
  });

  test('a larger group skipped keeps its place in the queue for later', () => {
    expect(nextGroupThatFits([...queue].reverse(), 2)).toBe('pair');
  });

  test('none when nothing fits', () => {
    expect(nextGroupThatFits(queue, 0)).toBeNull();
    expect(nextGroupThatFits([], 9)).toBeNull();
  });
});

describe('planOffers (Req 32, 34, #248)', () => {
  const HOUR = 60 * 60 * 1000;
  const now = Date.UTC(2027, 1, 1, 12);
  const queue = [
    {registrationId: 'big', size: 5, position: 1},
    {registrationId: 'two', size: 2, position: 2},
    {registrationId: 'one', size: 1, position: 3},
  ];
  const base = {capacity: 10, placesUsed: 7, offers: [], queue, now, offerHours: 72, deadline: null};

  test('offers the first group that fits, holding its places, for offerHours', () => {
    expect(planOffers(base)).toEqual([
      {registrationId: 'two', size: 2, offeredAt: now, expiresAt: now + 72 * HOUR},
      {registrationId: 'one', size: 1, offeredAt: now, expiresAt: now + 72 * HOUR},
    ]);
  });

  test('a larger group skipped keeps its place and is offered when enough frees up', () => {
    expect(planOffers({...base, placesUsed: 5}).map((o) => o.registrationId)).toEqual(['big']);
  });

  test('open offers hold their places, and a group already offered is not offered again', () => {
    const open = [{registrationId: 'two', size: 2, offeredAt: now - HOUR, expiresAt: now + HOUR}];
    expect(planOffers({...base, offers: open}).map((o) => o.registrationId)).toEqual(['one']);
    expect(planOffers({...base, placesUsed: 8, offers: open})).toEqual([]);
  });

  test('no automatic offers after the deadline, and none when full', () => {
    expect(planOffers({...base, deadline: now - 1})).toEqual([]);
    expect(planOffers({...base, placesUsed: 10})).toEqual([]);
    expect(planOffers({...base, placesUsed: 12})).toEqual([]);
  });

  test('with no capacity every waiting group is offered', () => {
    expect(planOffers({...base, capacity: null})).toHaveLength(3);
  });
});

describe('expireOffers', () => {
  test('splits open offers from late ones, with an injected time', () => {
    const offers = [
      {registrationId: 'a', size: 1, offeredAt: 0, expiresAt: 100},
      {registrationId: 'b', size: 1, offeredAt: 0, expiresAt: 200},
    ];
    expect(expireOffers(offers, 150)).toEqual({open: [offers[1]], expired: [offers[0]]});
    expect(expireOffers(offers, 100).expired).toEqual([offers[0]]);
  });
});
