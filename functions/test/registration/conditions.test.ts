/**
 * Spec #233 Req 18 (#242): a question shown only to a category, or only
 * when one other answer has a value. The app's form_conditions.dart runs
 * the same cases.
 */
import cases from '../fixtures/condition_cases.json';
import {isShown} from '../../src/registration/conditions';

describe('isShown', () => {
  for (const c of cases) {
    test(c.name, () => {
      expect(isShown(c.condition as never, c.person as never)).toBe(c.shown);
    });
  }
});
