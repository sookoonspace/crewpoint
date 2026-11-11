/**
 * Req 52: counts per event and per session, by category and by custom
 * field, from the attendance rules (Req 50). Pure, so the scheduled job and
 * the callable count the same way.
 */
import {computeStats, CountField, CountPerson} from '../../src/counts/stats';

const diet: CountField = {id: 'diet', type: 'singleChoice', scope: 'participant'};
const kids: CountField = {id: 'kids', type: 'yesNo', scope: 'participant'};
const langs: CountField = {id: 'langs', type: 'multiChoice', scope: 'participant'};
const hotel: CountField = {id: 'hotel', type: 'singleChoice', scope: 'group'};
const note: CountField = {id: 'note', type: 'text', scope: 'participant'};

const person = (id: string, over: Partial<CountPerson> = {}): CountPerson => ({
  id, status: 'active', groupId: 'g1', categoryId: 'adult', answers: {}, ...over,
});

describe('computeStats', () => {
  test('counts active people, their groups and categories', () => {
    const s = computeStats({
      policy: 'everyone', sessions: [], fields: [],
      groups: [{id: 'g1'}, {id: 'g2'}, {id: 'empty'}],
      people: [
        person('a'), person('b', {categoryId: 'child', groupId: 'g2'}),
        person('c', {categoryId: null, groupId: null}),
        person('gone', {status: 'cancelled', groupId: 'empty'}),
      ],
    });
    expect(s.event.total).toBe(3);
    expect(s.event.groups).toBe(2);
    expect(s.event.byCategory).toEqual({adult: 1, child: 1, _none: 1});
  });

  test('counts choice, multi-choice and yes/no answers, with unanswered as _none', () => {
    const s = computeStats({
      policy: 'everyone', sessions: [], groups: [], fields: [diet, kids, langs, note],
      people: [
        person('a', {answers: {diet: 'Veg', kids: true, langs: ['en', 'gu'], note: 'hi'}}),
        person('b', {answers: {diet: 'Veg', kids: false, langs: ['en']}}),
        person('c', {answers: {}}),
      ],
    });
    expect(s.event.byField.diet).toEqual({Veg: 2, _none: 1});
    expect(s.event.byField.kids).toEqual({yes: 1, no: 1, _none: 1});
    expect(s.event.byField.langs).toEqual({en: 2, gu: 1, _none: 1});
    // Free text is not counted.
    expect(s.event.byField.note).toBeUndefined();
  });

  test('a group field counts each person by their group\'s answer', () => {
    const s = computeStats({
      policy: 'everyone', sessions: [], fields: [hotel],
      groups: [{id: 'g1', answers: {hotel: 'Hyatt'}}],
      people: [person('a'), person('b'), person('c', {groupId: null})],
    });
    expect(s.event.byField.hotel).toEqual({Hyatt: 2, _none: 1});
  });

  test('counts each session from the attendance rules', () => {
    const s = computeStats({
      policy: 'arrivalToDeparture', fields: [diet],
      groups: [{id: 'g1', invitedTo: ['gala']}],
      sessions: [
        {id: 'm1', startAt: '2027-07-17T00:00:00Z'},
        {id: 'm3', startAt: '2027-07-17T17:30:00Z'},
        {id: 'k1', startAt: '2027-07-17T18:30:00Z', attendance: 'bySession', eligibility: {categoryIds: ['child']}},
        {id: 'gala', startAt: '2027-07-19T00:00:00Z', attendance: 'invitedOnly'},
      ],
      people: [
        person('late', {arrivalAt: '2027-07-17T16:00:00Z', answers: {diet: 'Veg'}, groupId: 'g2'}),
        person('elder', {optOuts: ['m3'], answers: {diet: 'Jain'}}),
        person('kid', {categoryId: 'child', signUps: ['k1'], answers: {diet: 'Veg'}}),
        person('gone', {status: 'cancelled'}),
      ],
    });
    expect(s.sessions.m1.total).toBe(2);
    expect(s.sessions.m3.byField.diet).toEqual({Veg: 2});
    expect(s.sessions.k1).toEqual({total: 1, byCategory: {child: 1}, byField: {diet: {Veg: 1}}});
    expect(s.sessions.gala.total).toBe(2);
  });

  test('an empty event counts nothing', () => {
    const s = computeStats({policy: null, sessions: [{id: 's', startAt: '2027-01-01T00:00:00Z'}], people: [], groups: [], fields: [diet]});
    expect(s.event).toEqual({total: 0, groups: 0, byCategory: {}, byField: {diet: {}}});
    expect(s.sessions.s.total).toBe(0);
  });
});
