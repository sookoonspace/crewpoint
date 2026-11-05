/** Req 20 (GE-01): message text uses an event's labels. */
import defaults from '../../src/shared/label_defaults.json';
import {resolveLabel} from '../../src/notifications/labels';
import {memberJoinedText} from '../../src/events/onMemberJoined';

describe('resolveLabel', () => {
  test('returns the default with no label set', () => {
    expect(resolveLabel(undefined, 'group', 'one')).toBe('Group');
    expect(resolveLabel({}, 'group', 'other')).toBe('Groups');
  });

  test('returns the event label when set', () => {
    const labels = {group: {one: 'Team', other: 'Teams'}};
    expect(resolveLabel(labels, 'group', 'one')).toBe('Team');
    expect(resolveLabel(labels, 'group', 'other')).toBe('Teams');
    expect(resolveLabel(labels, 'session', 'one')).toBe('Session');
  });

  test('a label with only one form uses it for both', () => {
    expect(resolveLabel({member: {one: 'Committee'}}, 'member', 'other')).toBe('Committee');
    expect(resolveLabel({member: {other: 'Crew'}}, 'member', 'one')).toBe('Crew');
  });

  test('blank or badly shaped labels fall back to the default', () => {
    expect(resolveLabel({group: {one: '  '}}, 'group', 'one')).toBe('Group');
    expect(resolveLabel({group: 'Team'}, 'group', 'one')).toBe('Group');
    expect(resolveLabel({group: {one: 5}}, 'group', 'one')).toBe('Group');
  });

  test('the defaults come from the shared file', () => {
    expect(resolveLabel({}, 'customField', 'other')).toBe(defaults.customField.other);
  });
});

describe('memberJoinedText', () => {
  test('keeps today\'s wording by default', () => {
    expect(memberJoinedText('Trip', undefined)).toEqual({
      title: 'New member in Trip',
      body: 'Tap to review the member list.',
    });
  });

  test('uses the event\'s label', () => {
    const labels = {member: {one: 'Committee', other: 'Committee'}};
    expect(memberJoinedText('Trip', labels)).toEqual({
      title: 'New committee in Trip',
      body: 'Tap to review the committee list.',
    });
  });
});
