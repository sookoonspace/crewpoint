/**
 * Spec #233 Req 13, 17 (#237): phone numbers in E.164. The cases are shared
 * with the app, which runs the same file. Pure.
 */
import * as fs from 'fs';
import * as path from 'path';
import {countryForTimeZone, normalisePhone, PhoneCountry} from '../../src/participants/phone';

const cases = JSON.parse(
  fs.readFileSync(path.join(__dirname, '..', 'fixtures', 'phone_cases.json'), 'utf8'),
) as {
  normalise: {input: string; country: PhoneCountry; expected: string | null; note: string}[];
  countryForTimeZone: {timeZone: string | null; expected: PhoneCountry}[];
};

describe('normalisePhone', () => {
  test.each(cases.normalise)('$note: "$input" ($country)', ({input, country, expected}) => {
    expect(normalisePhone(input, country)).toBe(expected);
  });
});

describe('countryForTimeZone', () => {
  test.each(cases.countryForTimeZone)('$timeZone', ({timeZone, expected}) => {
    expect(countryForTimeZone(timeZone)).toBe(expected);
  });
});
