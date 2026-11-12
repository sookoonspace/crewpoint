/* eslint-disable */
// Acceptance tests for system templates (#89, Req 62, 66). Every template
// creates an event through the same code, differing only in data.
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../test/setup';
import {SYSTEM_TEMPLATE_IDS, systemTemplate} from '../src/events/templates';

const ftest = require('firebase-functions-test')();
getAdminApp();
const {createEvent} = require('../src/events/createEvent');
const db = () => getAdminDb();

beforeEach(() => clearFirestoreEmulator());
afterAll(() => ftest.cleanup());

describe('templates', () => {
  for (const id of SYSTEM_TEMPLATE_IDS) {
    test(`GE-06 the ${id} template creates its event with no code differences`, async () => {
      await ftest.wrap(createEvent)({auth: {uid: 'host'}, data: {eventId: id, title: `From ${id}`, templateId: id}});
      const t = systemTemplate(id)!;
      const event = (await db().doc(`events/${id}`).get()).data()!;
      expect(event.templateId).toBe(id);
      expect(event.labels).toEqual(t.labels);
      expect(event.settings).toEqual(t.settings);
      expect(event.status).toBe('draft');
      const fields = await db().collection(`events/${id}/fields`).get();
      expect(fields.docs.map((d) => d.id).sort()).toEqual(t.fields.map((f) => f.id).sort());
      const roles = await db().collection(`events/${id}/roles`).get();
      expect(roles.docs.map((d) => d.id).sort()).toEqual(Object.keys(t.roles).sort());
      expect((await db().doc(`events/${id}/members/host`).get()).data()!.roleIds).toEqual(['owner']);
    });
  }
});
