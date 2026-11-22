/**
 * Spec #233 Req 13 (#237): linking by verified email or verified phone, from
 * the shared cases in `test/fixtures/linking_cases.json`. Pure.
 */
import * as fs from 'fs';
import * as path from 'path';
import {decideLinks, Identity, LinkDecision, MatchRecord} from '../../src/participants/linking';
import {normalisePhone, PhoneCountry} from '../../src/participants/phone';

interface CaseRecord extends Partial<MatchRecord> {
  eventId: string;
  participantId: string;
  phoneEntered?: string;
  phoneCountry?: PhoneCountry;
}

const {cases} = JSON.parse(
  fs.readFileSync(path.join(__dirname, '..', 'fixtures', 'linking_cases.json'), 'utf8'),
) as {
  cases: {
    name: string;
    identity: Identity;
    records: CaseRecord[];
    expected: Record<string, LinkDecision>;
  }[];
};

/** A record as private details store it: a typed number goes in as E.164. */
function stored(r: CaseRecord): MatchRecord {
  const {phoneEntered, phoneCountry, ...rest} = r;
  return {
    groupId: 'g1',
    isChild: false,
    linkedUid: null,
    status: 'active',
    ...rest,
    ...(phoneEntered !== undefined ?
      {phone: normalisePhone(phoneEntered, phoneCountry ?? 'US')} :
      {}),
  };
}

describe('decideLinks', () => {
  test.each(cases)('$name', ({identity, records, expected}) => {
    expect(decideLinks(records.map(stored), identity, 'u')).toEqual(expected);
  });
});
