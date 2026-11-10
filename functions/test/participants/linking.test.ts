/**
 * Req 46 (X-05): which participant record a signed-in person's verified email
 * links to. Only adult records count, decided in #78: one adult links, while
 * two or more adults, or only children, go to an organizer. Pure.
 */
import {Candidate, decideLink} from '../../src/participants/linking';

const person = (participantId: string, over: Partial<Candidate> = {}): Candidate => ({
  participantId, groupId: 'f1', isChild: false, linkedUid: null, status: 'active', ...over,
});

describe('decideLink', () => {
  test('nothing matches: nothing to do', () => {
    expect(decideLink([], 'ravi')).toEqual({kind: 'none'});
  });

  test('one adult links', () => {
    expect(decideLink([person('p1')], 'ravi')).toEqual({kind: 'link', participantId: 'p1'});
  });

  test('X-05 a family sharing the parent email: the one adult links, never a child', () => {
    const family = [person('ravi'), person('kid1', {isChild: true}), person('kid2', {isChild: true})];
    expect(decideLink(family, 'u')).toEqual({kind: 'link', participantId: 'ravi'});
  });

  test('two adults with the email go to an organizer', () => {
    expect(decideLink([person('ravi'), person('mira'), person('kid', {isChild: true})], 'u'))
      .toEqual({kind: 'ask', participantIds: ['ravi', 'mira', 'kid'], groupIds: ['f1']});
  });

  test('only children go to an organizer', () => {
    expect(decideLink([person('kid', {isChild: true, groupId: 'f2'})], 'u'))
      .toEqual({kind: 'ask', participantIds: ['kid'], groupIds: ['f2']});
  });

  test('already linked to this person: nothing more to do', () => {
    expect(decideLink([person('ravi', {linkedUid: 'u'}), person('mira')], 'u'))
      .toEqual({kind: 'linked', participantId: 'ravi'});
  });

  test('a record linked to someone else, or cancelled, is never taken', () => {
    expect(decideLink([person('ravi', {linkedUid: 'other'})], 'u')).toEqual({kind: 'none'});
    expect(decideLink([person('ravi', {status: 'cancelled'})], 'u')).toEqual({kind: 'none'});
    expect(decideLink([person('ravi', {linkedUid: 'other'}), person('mira')], 'u'))
      .toEqual({kind: 'link', participantId: 'mira'});
  });
});
