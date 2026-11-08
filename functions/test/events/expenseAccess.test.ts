/**
 * Req 38 (L15): who reads every expense in an event. The payer and people in
 * a split always read that expense, and `money.read` reads all of them,
 * whatever the setting; this decides only `expenses.readAll`.
 */
import {
  expenseAccessOf,
  parseExpenseAccess,
  readsAllExpensesUnder,
} from '../../src/events/expenseAccess';

describe('expenseAccessOf', () => {
  test('an event without the setting is Everyone, leaving out Observers and Vendors', () => {
    expect(expenseAccessOf({})).toEqual({
      mode: 'everyone', includeNonContributors: false, roleIds: [], uids: [],
    });
    expect(expenseAccessOf({settings: {}})).toEqual(expenseAccessOf({}));
  });

  test('reads a stored setting, and ignores anything malformed', () => {
    expect(expenseAccessOf({settings: {expenseAccess: {
      mode: 'selected', roleIds: ['finance', 7], uids: ['pat'],
    }}})).toEqual({mode: 'selected', includeNonContributors: false, roleIds: ['finance'], uids: ['pat']});
    expect(expenseAccessOf({settings: {expenseAccess: {mode: 'nonsense'}}}).mode).toBe('everyone');
  });
});

describe('readsAllExpensesUnder', () => {
  const everyone = expenseAccessOf({});
  const reads = (access: ReturnType<typeof expenseAccessOf>, uid: string, roleIds: string[]) =>
    readsAllExpensesUnder(access, uid, roleIds);

  test('Everyone: every member except Observers and Vendors', () => {
    expect(reads(everyone, 'a', ['participant'])).toBe(true);
    expect(reads(everyone, 'a', ['vendor', 'scorer'])).toBe(true);
    expect(reads(everyone, 'a', ['vendor'])).toBe(false);
    expect(reads(everyone, 'a', ['observer'])).toBe(false);
  });

  test('Everyone with the switch on: Observers and Vendors too', () => {
    const all = {...everyone, includeNonContributors: true};
    expect(reads(all, 'a', ['observer'])).toBe(true);
    expect(reads(all, 'a', ['vendor'])).toBe(true);
  });

  test('Only people involved: nobody reads every expense this way', () => {
    const involved = {...everyone, mode: 'involved' as const};
    expect(reads(involved, 'a', ['owner'])).toBe(false);
    expect(reads(involved, 'a', ['participant'])).toBe(false);
  });

  test('Selected: the chosen roles and people, including Observers', () => {
    const selected = {
      mode: 'selected' as const, includeNonContributors: false,
      roleIds: ['crewLead', 'observer'], uids: ['pat'],
    };
    expect(reads(selected, 'a', ['participant', 'crewLead'])).toBe(true);
    expect(reads(selected, 'a', ['observer'])).toBe(true);
    expect(reads(selected, 'pat', ['participant'])).toBe(true);
    expect(reads(selected, 'b', ['participant'])).toBe(false);
  });

  test('Selected with nobody chosen', () => {
    const nobody = {mode: 'selected' as const, includeNonContributors: false, roleIds: [], uids: []};
    expect(reads(nobody, 'a', ['admin'])).toBe(false);
  });
});

describe('parseExpenseAccess (what the callable accepts)', () => {
  test('keeps only what the option uses', () => {
    expect(parseExpenseAccess({mode: 'involved', roleIds: ['x'], uids: ['y'], includeNonContributors: true}))
      .toEqual({mode: 'involved', includeNonContributors: false, roleIds: [], uids: []});
    expect(parseExpenseAccess({mode: 'everyone', includeNonContributors: true, roleIds: ['x']}))
      .toEqual({mode: 'everyone', includeNonContributors: true, roleIds: [], uids: []});
    expect(parseExpenseAccess({mode: 'selected', roleIds: ['a', 'a'], uids: ['p']}))
      .toEqual({mode: 'selected', includeNonContributors: false, roleIds: ['a'], uids: ['p']});
  });

  test('refuses an unknown option or the wrong types', () => {
    expect(() => parseExpenseAccess({mode: 'some'})).toThrow();
    expect(() => parseExpenseAccess({mode: 'selected', roleIds: 'finance'})).toThrow();
    expect(() => parseExpenseAccess({mode: 'selected', uids: [1]})).toThrow();
    expect(() => parseExpenseAccess(null)).toThrow();
  });

  test('caps the lists so the document stays small', () => {
    const many = Array.from({length: 501}, (_, i) => `u${i}`);
    expect(() => parseExpenseAccess({mode: 'selected', uids: many})).toThrow();
  });
});
