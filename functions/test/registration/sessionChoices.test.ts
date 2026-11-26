/**
 * Spec #233 Req 17 (#242, W-01): by-sign-up sessions as per-person choices,
 * those at the same time as one either/or choice. The app's
 * session_choices.dart runs the same cases.
 */
import cases from '../fixtures/session_choice_cases.json';
import {signUpChoices, validSignUps} from '../../src/registration/sessionChoices';

describe('signUpChoices', () => {
  for (const c of cases) {
    test(c.name, () => {
      expect(signUpChoices(c.policy, c.sessions as never)).toEqual(c.choices);
    });
  }
});

describe('validSignUps', () => {
  const choices = [['park-meal', 'hotel-lunch'], ['tour']];
  test('one of each choice, or none, is fine', () => {
    expect(validSignUps(choices, ['park-meal', 'tour'])).toBe(true);
    expect(validSignUps(choices, [])).toBe(true);
  });
  test('both sides of an either/or are refused', () => {
    expect(validSignUps(choices, ['park-meal', 'hotel-lunch'])).toBe(false);
  });
  test('a session that is not a choice is refused', () => {
    expect(validSignUps(choices, ['opening'])).toBe(false);
  });
});
