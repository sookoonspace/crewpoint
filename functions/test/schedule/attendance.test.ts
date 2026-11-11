/**
 * Req 50 (J-06): who attends a session, from the event's policy, the
 * session's own rule and the stored exceptions. The app runs the same cases
 * from the same fixture, so the two cannot drift apart.
 */
import * as fs from 'fs';
import * as path from 'path';
import {attends, AttendanceCase} from '../../src/schedule/attendance';

const cases = JSON.parse(
  fs.readFileSync(path.join(__dirname, '..', 'fixtures', 'attendance_cases.json'), 'utf8'),
) as Array<AttendanceCase & {name: string; attends: boolean}>;

describe('attends', () => {
  test.each(cases.map((c) => [c.name, c] as const))('%s', (_, c) => {
    expect(attends(c)).toBe(c.attends);
  });
});
