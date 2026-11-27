/**
 * Spec #233 Req 26-29 (#246): who a waiver applies to, and whether an
 * acceptance counts. The app's waivers.dart runs the same cases.
 */
import cases from '../fixtures/waiver_cases.json';
import {waiverApplies, acceptanceStatus} from '../../src/registration/waivers';

describe('waiverApplies', () => {
  for (const c of cases.applies) {
    test(c.name, () => expect(waiverApplies(c.appliesTo as never, c.person)).toBe(c.applies));
  }
});

describe('acceptanceStatus', () => {
  for (const c of cases.status) {
    test(c.name, () => {
      expect(acceptanceStatus({version: c.version, requireLatest: c.requireLatest}, c.accepted))
        .toEqual({status: c.status, counts: c.counts});
    });
  }
});
