/** Req 26, 26a, 26b: the permission catalogue and built-in presets. */
import {
  PERMISSIONS,
  PRESET_ROLES,
  computePermissions,
  legacyRoleIds,
} from '../../src/events/permissions';

const without = (...out: string[]) => PERMISSIONS.filter((p) => !out.includes(p));
const preset = (id: string) => [...PRESET_ROLES[id].permissions].sort();
const sorted = (list: readonly string[]) => [...list].sort();

describe('permission catalogue', () => {
  test('is exactly the Spec list', () => {
    expect(PERMISSIONS).toEqual([
      'event.manage', 'event.transfer', 'members.manage', 'roles.manage',
      'schedule.edit', 'updates.send', 'participants.read', 'participants.edit',
      'participants.readPrivate', 'participants.import', 'group.readOwn',
      'group.editOwn', 'registrations.manage', 'money.read', 'money.record',
      'money.refund', 'money.dueAtDoor', 'budget.read', 'budget.edit',
      'expenses.readAll', 'contributions.manage', 'tasks.manage', 'chat.send',
      'chat.urgent', 'messages.send', 'checkin.scan', 'checkin.lookup',
      'counts.read', 'incidents.report', 'incidents.receive', 'reports.export',
      'competition.manage', 'scores.enter',
    ]);
  });
});

describe('presets', () => {
  test('Owner holds all permissions', () => {
    expect(preset('owner')).toEqual(sorted(PERMISSIONS));
  });

  test('Co-owner holds all except event.transfer', () => {
    expect(preset('coOwner')).toEqual(sorted(without('event.transfer')));
  });

  test('Admin holds all except event.transfer and roles.manage', () => {
    expect(preset('admin')).toEqual(sorted(without('event.transfer', 'roles.manage')));
  });

  // Each list is the Req 26a table plus group.readOwn, from Req 26b.
  const table: Record<string, string[]> = {
    finance: ['money.read', 'money.record', 'money.refund', 'budget.read', 'budget.edit',
      'expenses.readAll', 'contributions.manage', 'participants.read', 'counts.read',
      'reports.export', 'chat.send'],
    crewLead: ['tasks.manage', 'schedule.edit', 'updates.send', 'participants.read',
      'participants.edit', 'money.dueAtDoor', 'counts.read', 'chat.send', 'chat.urgent',
      'messages.send', 'incidents.report', 'incidents.receive'],
    crewMember: ['updates.send', 'participants.read', 'money.dueAtDoor', 'counts.read',
      'chat.send', 'incidents.report', 'incidents.receive'],
    volunteer: ['checkin.scan', 'checkin.lookup', 'money.dueAtDoor', 'incidents.report',
      'chat.send'],
    scorer: ['scores.enter', 'chat.send'],
    vendor: [],
    sponsor: ['chat.send'],
    participant: ['chat.send'],
    observer: [],
  };

  for (const [id, permissions] of Object.entries(table)) {
    test(`${id} holds exactly its table permissions`, () => {
      expect(preset(id)).toEqual(sorted([...permissions, 'group.readOwn']));
    });
  }

  test('every preset includes group.readOwn', () => {
    for (const role of Object.values(PRESET_ROLES)) {
      expect(role.permissions).toContain('group.readOwn');
    }
  });

  test('there are exactly the twelve built-in presets', () => {
    expect(Object.keys(PRESET_ROLES).sort()).toEqual(
      ['owner', 'coOwner', 'admin', ...Object.keys(table)].sort()
    );
  });
});

describe('computePermissions', () => {
  test('several roles grant the union, in catalogue order', () => {
    expect(computePermissions(['scorer', 'volunteer'], {})).toEqual([
      'group.readOwn', 'money.dueAtDoor', 'chat.send', 'checkin.scan',
      'checkin.lookup', 'incidents.report', 'scores.enter',
    ]);
  });

  test("an event's edited preset replaces the built-in one", () => {
    const roles = {sponsor: {permissions: ['counts.read']}};
    expect(computePermissions(['sponsor'], roles)).toEqual(['counts.read']);
  });

  test('a custom role grants its permissions', () => {
    const roles = {hospitality: {permissions: ['participants.read', 'chat.send']}};
    expect(computePermissions(['hospitality'], roles)).toEqual([
      'participants.read', 'chat.send',
    ]);
  });

  test('unknown roles and unknown permission names grant nothing', () => {
    const roles = {odd: {permissions: ['money.steal', 'chat.send', 7]}};
    expect(computePermissions(['missing', 'odd'], roles)).toEqual(['chat.send']);
  });

  test("a group's contact or linked adult gets group.editOwn, whatever the role", () => {
    expect(computePermissions(['observer'], {}, {editsOwnGroup: true})).toEqual([
      'group.readOwn', 'group.editOwn',
    ]);
    expect(computePermissions(['observer'], {})).toEqual(['group.readOwn']);
  });
});

describe('legacyRoleIds — the migration mapping', () => {
  const event = {creatorId: 'c', adminIds: ['c', 'a'], memberIds: ['c', 'a', 'm']};

  test('creator is Owner, admins are Admin, everyone else is Participant', () => {
    expect(legacyRoleIds(event, 'c')).toEqual(['owner']);
    expect(legacyRoleIds(event, 'a')).toEqual(['admin']);
    expect(legacyRoleIds(event, 'm')).toEqual(['participant']);
  });

  test('someone outside the event has no roles', () => {
    expect(legacyRoleIds(event, 'x')).toEqual([]);
  });
});
