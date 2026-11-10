/**
 * Req 44, 45 (X-01, X-02, X-03, X-06): planning an import. Columns are mapped
 * to targets; each row is checked, and a row with a problem is listed and
 * left out without stopping the good ones. Re-import matches on a mapped
 * external ID, or else on group plus name, normalised, and never duplicates.
 */
import {planImport, type ImportContext, type Target} from '../../src/imports/plan';

const fields = [
  {id: 'diet', label: 'Diet', type: 'singleChoice', options: ['Jain', 'Veg', 'Non-veg'], required: true, scope: 'participant', visibility: 'standard'},
  {id: 'allergy', label: 'Allergy', type: 'text', options: [], required: false, scope: 'participant', visibility: 'private'},
  {id: 'kids', label: 'Kids activity', type: 'yesNo', options: [], required: false, scope: 'participant', visibility: 'standard'},
  {id: 'hotel', label: 'Hotel', type: 'text', options: [], required: false, scope: 'group', visibility: 'standard'},
] as const;

const context = (over: Partial<ImportContext> = {}): ImportContext => ({
  fields: [...fields],
  categories: [
    {id: 'child', name: 'Child', maxAge: 17, isChild: true},
    {id: 'adult', name: 'Adult', minAge: 18},
  ],
  eventStart: '2027-07-16',
  existing: [],
  existingGroups: [],
  ...over,
});

const header = ['Family', 'ID', 'Name', 'Age', 'Diet', 'Allergy', 'Kids', 'Email'];
const targets: Target[] = ['group', 'externalId', 'name', 'age', 'field:diet', 'field:allergy', 'field:kids', 'email'];
const csv = (...rows: string[][]) => [header, ...rows];

describe('checking rows (X-01, X-06)', () => {
  test('a good row becomes a person, with their answers and age band', () => {
    const plan = planImport(csv(['Patel', 'P1', 'Ravi Patel', '42', 'jain', '', 'yes', 'ravi@x.test']), targets, context());
    expect(plan.errors).toEqual([]);
    expect(plan.people).toHaveLength(1);
    expect(plan.people[0]).toEqual(expect.objectContaining({
      row: 2, name: 'Ravi Patel', groupName: 'Patel', externalId: 'P1',
      categoryId: 'adult', isChild: false, email: 'ravi@x.test',
      standard: {diet: 'Jain', kids: true}, private: {}, match: null,
    }));
    expect(plan.creates).toBe(1);
  });

  test('a child is worked out from their age on the first day', () => {
    const plan = planImport(csv(['Patel', 'P2', 'Asha Patel', '17', 'Veg', '', 'no', '']), targets, context());
    expect(plan.people[0]).toEqual(expect.objectContaining({categoryId: 'child', isChild: true}));
  });

  test('X-06 problems are listed by row, and do not stop the good rows', () => {
    const plan = planImport(csv(
      ['Patel', 'P1', 'Ravi Patel', '42', 'Jain', '', '', 'same@x.test'],
      ['Patel', 'P2', 'Mira Patel', '40', '', '', '', ''],
      ['Shah', 'S1', 'Dev Shah', 'unknown', 'Veg', '', '', ''],
      ['Shah', 'S2', 'Ana Shah', '9', 'Veg', '', '', 'SAME@x.test'],
      ['Shah', 'S3', '', '9', 'Veg', '', '', ''],
      ['Shah', 'S4', 'Raj Shah', '30', 'Fish', '', 'maybe', ''],
      ['Joshi', 'J1', 'Ila Joshi', '35', 'Veg', 'Nuts', '', ''],
    ), targets, context());
    expect(plan.people.map((p) => p.name)).toEqual(['Ravi Patel', 'Ila Joshi']);
    expect(plan.errors).toEqual([
      {row: 3, column: 'Diet', problem: 'required'},
      {row: 4, column: 'Age', problem: 'unknownAge'},
      {row: 5, column: 'Email', problem: 'duplicateEmail'},
      {row: 6, column: 'Name', problem: 'required'},
      {row: 7, column: 'Diet', problem: 'notAnOption'},
      {row: 7, column: 'Kids', problem: 'wrongType'},
    ]);
    expect(plan.people[1].private).toEqual({allergy: 'Nuts'});
  });

  test('a birth date is read, and kept private', () => {
    const plan = planImport(
      [['Name', 'Born', 'Diet'], ['Ana', '2010-07-17', 'Veg'], ['Bo', '7/16/2009', 'Veg'], ['Cy', '31/12/2009', 'Veg']],
      ['name', 'birthDate', 'field:diet'],
      context(),
    );
    expect(plan.people.map((p) => [p.name, p.birthDate, p.categoryId])).toEqual([
      ['Ana', '2010-07-17', 'child'],
      ['Bo', '2009-07-16', 'adult'],
    ]);
    expect(plan.errors).toEqual([{row: 4, column: 'Born', problem: 'unknownAge'}]);
  });

  test('without a name column nothing is planned', () => {
    const plan = planImport(csv(['Patel', 'P1', 'Ravi', '1', 'Veg', '', '', '']), ['group', 'externalId', 'ignore', 'age', 'field:diet', 'ignore', 'ignore', 'ignore'], context());
    expect(plan.people).toEqual([]);
    expect(plan.mappingProblems).toEqual(['nameNotMapped']);
  });

  test('a field that is not mapped is not required of each row', () => {
    const plan = planImport([['Name'], ['Ravi']], ['name'], context());
    expect(plan.errors).toEqual([]);
    expect(plan.mappingProblems).toEqual(['requiredFieldNotMapped:diet']);
  });

  test('the same person twice in one file is listed, not added twice', () => {
    const plan = planImport(csv(
      ['Patel', 'P1', 'Ravi', '42', 'Jain', '', '', ''],
      ['Patel', 'P1', 'Ravi again', '42', 'Jain', '', '', ''],
      ['Shah', '', 'Dev', '30', 'Veg', '', '', ''],
      ['shah ', '', ' DEV', '30', 'Veg', '', '', ''],
    ), targets, context());
    expect(plan.people.map((p) => p.name)).toEqual(['Ravi', 'Dev']);
    expect(plan.errors.map((e) => e.problem)).toEqual(['duplicateRow', 'duplicateRow']);
  });
});

describe('shared emails (Req 46, decided in #78)', () => {
  test('one family may share an email; two families may not', () => {
    const plan = planImport(csv(
      ['Patel', 'P1', 'Ravi Patel', '42', 'Jain', '', '', 'home@x.test'],
      ['Patel', 'P2', 'Asha Patel', '9', 'Jain', '', '', 'HOME@x.test'],
      ['Shah', 'S1', 'Dev Shah', '30', 'Veg', '', '', 'home@x.test'],
    ), targets, context());
    expect(plan.people.map((p) => p.name)).toEqual(['Ravi Patel', 'Asha Patel']);
    expect(plan.errors).toEqual([{row: 4, column: 'Email', problem: 'duplicateEmail'}]);
  });

  test('without a group, a repeated email is still a problem', () => {
    const plan = planImport(
      [['Name', 'Email', 'Diet'], ['A', 'a@x.test', 'Veg'], ['B', 'a@x.test', 'Veg']],
      ['name', 'email', 'field:diet'],
      context(),
    );
    expect(plan.errors).toEqual([{row: 3, column: 'Email', problem: 'duplicateEmail'}]);
  });
});

describe('re-import (X-02, X-03)', () => {
  const existing = [
    {id: 'a', name: 'Ravi Patel', groupId: 'gP', externalId: 'P1', imported: true, status: 'active'},
    {id: 'b', name: 'Dev Shah', groupId: 'gS', imported: true, status: 'active'},
    {id: 'c', name: 'Ana Shah', groupId: 'gS', imported: true, status: 'active'},
    {id: 'd', name: 'Ila Joshi', groupId: 'gJ', imported: true, status: 'active'},
    {id: 'w', name: 'Walk In', groupId: null, status: 'active'},
  ];
  const existingGroups = [
    {id: 'gP', name: 'Patel'}, {id: 'gS', name: 'Shah'}, {id: 'gJ', name: 'Joshi'},
  ];
  const ctx = context({existing, existingGroups});

  test('matches on external ID first, then on group plus name', () => {
    const plan = planImport(csv(
      ['Patel', 'P1', 'Ravi K Patel', '42', 'Jain', '', '', ''],
      [' SHAH', '', 'dev  shah', '30', 'Veg', '', '', ''],
      ['Mehta', 'M1', 'New Mehta', '50', 'Veg', '', '', ''],
    ), targets, ctx);
    expect(plan.people.map((p) => [p.name, p.match, p.groupId])).toEqual([
      ['Ravi K Patel', 'a', 'gP'],
      ['dev  shah', 'b', 'gS'],
      ['New Mehta', null, null],
    ]);
    expect(plan.creates).toBe(1);
    expect(plan.updates).toBe(2);
    expect(plan.newGroups).toEqual(['Mehta']);
  });

  test('an unnamed entry left by a deleted account is found by its import ID key', () => {
    const plan = planImport(csv(['Patel', 'P9', 'Ravi Patel', '42', 'Jain', '', '', '']), targets, context({
      existing: [{id: 'anon', name: '', groupId: 'gP', imported: true, status: 'active', externalIdKey: 'key:P9'}],
      existingGroups: [{id: 'gP', name: 'Patel'}],
      externalIdKey: (id) => `key:${id}`,
    }));
    expect(plan.people[0].match).toBe('anon');
    expect(plan.updates).toBe(1);
    expect(plan.missingGroups).toEqual([]);
  });

  test('X-03 groups whose imported people are all missing are listed for review', () => {
    const plan = planImport(csv(
      ['Patel', 'P1', 'Ravi Patel', '42', 'Jain', '', '', ''],
      ['Shah', '', 'Dev Shah', '30', 'Veg', '', '', ''],
    ), targets, ctx);
    // Shah is partly present, so only Joshi is missing. The walk-in, added by
    // hand, is never listed.
    expect(plan.missingGroups).toEqual([{groupId: 'gJ', name: 'Joshi', participantIds: ['d']}]);
  });

  test('people already cancelled are not listed again', () => {
    const plan = planImport(csv(['Patel', 'P1', 'Ravi Patel', '42', 'Jain', '', '', '']), targets, context({
      existing: existing.map((p) => (p.id === 'd' ? {...p, status: 'cancelled'} : p)),
      existingGroups,
    }));
    expect(plan.missingGroups.map((g) => g.groupId)).toEqual(['gS']);
  });
});
