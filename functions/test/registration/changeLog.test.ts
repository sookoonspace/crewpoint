/**
 * Spec #233 Req 36 (#244, B-06): every change to a registration is logged
 * with which field and the value before and after. Pure.
 */
import {diffRegistration, RegistrationSnapshot} from '../../src/registration/changeLog';

const base: RegistrationSnapshot = {
  groupName: 'Patel family',
  email: 'asha@example.com',
  phone: '+13125550100',
  groupAnswers: {hotel: 'Hilton'},
  people: {
    p1: {name: 'Asha Patel', birthDate: '1980-03-01', answers: {diet: 'Jain'}, arrivalAt: 1000, departureAt: 2000, signUps: ['park'], optOuts: []},
    p2: {name: 'Dev Patel', birthDate: '2016-05-09', answers: {diet: 'Veg', kids: true}, arrivalAt: null, departureAt: null, signUps: [], optOuts: []},
  },
};

describe('diffRegistration', () => {
  test('nothing changed, nothing logged', () => {
    expect(diffRegistration(base, base)).toEqual([]);
  });

  test('a changed answer names the person, the question and both values', () => {
    const after = {...base, people: {...base.people, p2: {...base.people.p2, answers: {diet: 'Jain', kids: true}}}};
    expect(diffRegistration(base, after)).toEqual([
      {field: 'people.p2.answers.diet', person: 'Dev Patel', before: 'Veg', after: 'Jain'},
    ]);
  });

  test('group answers, contact details, stays, sign-ups and opt-outs', () => {
    const after: RegistrationSnapshot = {
      ...base,
      email: 'asha.p@example.com',
      groupAnswers: {hotel: 'Marriott'},
      people: {
        ...base.people,
        p1: {...base.people.p1, arrivalAt: 1500, signUps: [], optOuts: ['M2']},
      },
    };
    expect(diffRegistration(base, after)).toEqual([
      {field: 'email', person: null, before: 'asha@example.com', after: 'asha.p@example.com'},
      {field: 'groupAnswers.hotel', person: null, before: 'Hilton', after: 'Marriott'},
      {field: 'people.p1.arrivalAt', person: 'Asha Patel', before: 1000, after: 1500},
      {field: 'people.p1.signUps', person: 'Asha Patel', before: ['park'], after: []},
      {field: 'people.p1.optOuts', person: 'Asha Patel', before: [], after: ['M2']},
    ]);
  });

  test('a person added or removed is one entry with their name', () => {
    const {p2: _removed, ...rest} = base.people;
    const after = {...base, people: {...rest, p3: {...base.people.p2, name: 'Meera Patel'}}};
    expect(diffRegistration(base, after)).toEqual([
      {field: 'people.p2', person: 'Dev Patel', before: 'Dev Patel', after: null},
      {field: 'people.p3', person: 'Meera Patel', before: null, after: 'Meera Patel'},
    ]);
  });

  test('order of choices and sign-ups does not count as a change', () => {
    const before = {...base, people: {p1: {...base.people.p1, signUps: ['a', 'b'], answers: {days: ['Fri', 'Sat']}}}};
    const after = {...base, people: {p1: {...base.people.p1, signUps: ['b', 'a'], answers: {days: ['Sat', 'Fri']}}}};
    expect(diffRegistration(before, after)).toEqual([]);
  });
});
