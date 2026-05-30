/**
 * Unit-level guard for the new-joiner diff used by `onMemberJoined`.
 *
 * The trigger is `onDocumentWritten` on `events/{eventId}`, so it sees
 * the before/after snapshots and has to compute who actually joined.
 * Pinning the diff keeps the trigger from re-pushing on no-op writes
 * (admin/title edits) and from announcing "new member" on event
 * creation (the creator is not a joiner of their own event).
 */
import {newJoiners} from '../../src/events/onMemberJoined';

describe('newJoiners', () => {
  test('returns members in after but not in before', () => {
    expect(newJoiners(['a', 'b'], ['a', 'b', 'c'])).toEqual(['c']);
  });

  test('returns multiple new members in order added', () => {
    expect(newJoiners(['a'], ['a', 'b', 'c'])).toEqual(['b', 'c']);
  });

  test('returns empty when before is undefined (event creation)', () => {
    // Doc create — the creator populates the initial memberIds; we do
    // not treat the creator as a joiner.
    expect(newJoiners(undefined, ['creator'])).toEqual([]);
  });

  test('returns empty when memberIds did not grow (other-field edit)', () => {
    expect(newJoiners(['a', 'b'], ['a', 'b'])).toEqual([]);
  });

  test('ignores members that left (negative deltas)', () => {
    // A removal alone produces no joiners.
    expect(newJoiners(['a', 'b', 'c'], ['a', 'b'])).toEqual([]);
  });
});
