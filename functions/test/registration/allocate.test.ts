/**
 * Spec #233 Req 32, 32a, 33, 34 (#242): the pure capacity rules. A group
 * takes places whole or waits whole; freed places go to the first waiting
 * group that fits.
 */
import {allocate, nextGroupThatFits} from '../../src/registration/allocate';

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
