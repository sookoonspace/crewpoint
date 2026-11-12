/**
 * Req 65 (GE-06): save-as-template copies configuration only, never people,
 * money or messages, into the saver's own templates, and a new event can be
 * created from it.
 */
import {Timestamp} from 'firebase-admin/firestore';
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';
import {computePermissions} from '../../src/events/permissions';
import {templateFromEvent} from '../../src/events/templates';

// eslint-disable-next-line @typescript-eslint/no-var-requires
const ftest = require('firebase-functions-test')();
getAdminApp();
/* eslint-disable @typescript-eslint/no-var-requires */
const {saveAsTemplate} = require('../../src/events/saveAsTemplate');
const {createEvent} = require('../../src/events/createEvent');
/* eslint-enable @typescript-eslint/no-var-requires */

const E = 'events/conv';
const db = () => getAdminDb();
const call = (fn: unknown, uid: string, data: object) => ftest.wrap(fn)({auth: {uid}, data});
const refused = (code: string) => expect.objectContaining({code});

beforeEach(async () => {
  await clearFirestoreEmulator();
  await db().doc(E).set({
    title: 'Reunion 2027', status: 'published', templateId: 'convention', creatorId: 'owner',
    adminIds: ['owner'], memberIds: ['owner', 'plain'], currency: 'USD', timeZone: 'America/Chicago',
    startDate: Timestamp.fromDate(new Date('2027-07-16T00:00:00Z')),
    venues: [{id: 'hall', name: 'Garland Hall', address: '1 Main St'}],
    modules: {tasks: true, budget: false, chat: true, schedule: true},
    labels: {group: {one: 'Family', other: 'Families'}},
    settings: {
      attendancePolicy: 'arrivalToDeparture',
      categories: [{id: 'child', name: 'Child', maxAge: 17, isChild: true}],
      expenseAccess: {mode: 'selected', roleIds: ['finance'], uids: ['plain']},
    },
  });
  for (const [uid, roleIds] of [['owner', ['owner']], ['plain', ['participant']]] as const) {
    await db().doc(`${E}/members/${uid}`).set({uid, roleIds, permissions: computePermissions([...roleIds], {})});
  }
  await db().doc(`${E}/fields/diet`).set({label: 'Diet', type: 'singleChoice', options: ['Veg', 'Jain'], required: true, scope: 'participant', visibility: 'standard', order: 0});
  await db().doc(`${E}/roles/greeter`).set({name: 'Greeter', permissions: ['participants.read', 'chat.send'], preset: false});
  await db().doc(`${E}/participants/p1`).set({name: 'Ana', sortName: 'ana', status: 'active'});
  await db().doc(`${E}/expenses/x1`).set({payerId: 'owner', amount: 50});
  await db().doc(`${E}/messages/m1`).set({senderId: 'owner', text: 'Hi'});
  await db().doc(`${E}/tasks/t1`).set({title: 'Book hall'});
  await db().doc(`${E}/sessions/s1`).set({title: 'Dinner'});
});
afterAll(() => ftest.cleanup());

describe('templateFromEvent', () => {
  test('keeps configuration only', () => {
    const t = templateFromEvent({
      id: 't1',
      name: 'Our reunion',
      event: {
        templateId: 'convention', modules: {chat: false}, labels: {group: {one: 'Family'}},
        settings: {attendancePolicy: 'everyone', categories: [], expenseAccess: {mode: 'selected', roleIds: ['finance'], uids: ['plain']}},
        title: 'x', venues: [{id: 'v'}], memberIds: ['a'],
      },
      fields: [{id: 'diet', label: 'Diet', type: 'yesNo', options: [], required: false, scope: 'participant', visibility: 'standard', order: 0}],
      roles: {greeter: {name: 'Greeter', permissions: ['chat.send'], preset: false}, admin: {name: 'Admin', permissions: [], preset: true}},
    });
    // Named people are never copied; roles are.
    expect(t.settings.expenseAccess).toEqual({mode: 'selected', roleIds: ['finance'], uids: []});
    expect(t.roles).toEqual({greeter: {name: 'Greeter', permissions: ['chat.send']}});
    expect(t.baseTemplateId).toBe('convention');
    expect(Object.keys(t)).not.toContain('venues');
    expect(JSON.stringify(t)).not.toContain('memberIds');
  });
});

describe('saveAsTemplate', () => {
  test('saves the configuration to the saver\'s own templates, and nothing else', async () => {
    const {templateId} = await call(saveAsTemplate, 'owner', {eventId: 'conv', name: 'Our reunion'});
    const saved = (await db().doc(`users/owner/templates/${templateId}`).get()).data()!;
    expect(saved.name).toEqual({en: 'Our reunion'});
    expect(saved.modules.budget).toBe(false);
    expect(saved.labels.group.one).toBe('Family');
    expect(saved.fields.map((f: {id: string}) => f.id)).toEqual(['diet']);
    expect(saved.roles.greeter.permissions).toEqual(['participants.read', 'chat.send']);
    const text = JSON.stringify(saved);
    for (const leak of ['Ana', 'Hi', 'Book hall', 'Dinner', 'Garland', 'Reunion 2027', 'plain', '"amount"']) {
      expect(text).not.toContain(leak);
    }
  });

  test('needs event.manage and a name', async () => {
    await expect(call(saveAsTemplate, 'plain', {eventId: 'conv', name: 'Mine'})).rejects.toEqual(refused('permission-denied'));
    await expect(call(saveAsTemplate, 'owner', {eventId: 'conv', name: ' '})).rejects.toEqual(refused('invalid-argument'));
  });

  test('an event created from it has the configuration and no people, money or messages', async () => {
    const {templateId} = await call(saveAsTemplate, 'owner', {eventId: 'conv', name: 'Our reunion'});
    await call(createEvent, 'owner', {eventId: 'next', title: 'Reunion 2031', savedTemplateId: templateId});
    const next = (await db().doc('events/next').get()).data()!;
    expect(next.templateId).toBe('convention');
    expect(next.savedTemplateId).toBe(templateId);
    expect(next.modules.budget).toBe(false);
    expect(next.settings.attendancePolicy).toBe('arrivalToDeparture');
    expect(next.memberIds).toEqual(['owner']);
    expect(next.venues).toEqual([]);
    expect((await db().doc('events/next/roles/greeter').get()).data()!.name).toBe('Greeter');
    expect((await db().doc('events/next/fields/diet').get()).exists).toBe(true);
    for (const empty of ['participants', 'expenses', 'messages', 'tasks', 'sessions']) {
      expect((await db().collection(`events/next/${empty}`).get()).size).toBe(0);
    }
  });

  test('only its owner can create from a saved template', async () => {
    const {templateId} = await call(saveAsTemplate, 'owner', {eventId: 'conv', name: 'Our reunion'});
    await expect(call(createEvent, 'plain', {eventId: 'theirs', title: 'Copy', savedTemplateId: templateId}))
      .rejects.toEqual(refused('invalid-argument'));
  });
});
