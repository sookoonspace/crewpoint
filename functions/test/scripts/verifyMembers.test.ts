/**
 * Req 34 step 5: a verification script compares every event's old arrays
 * with its member documents.
 */
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';
import {migrateToMembers} from '../../scripts/migrateToMembers';
import {verifyMembers} from '../../scripts/verifyMembers';

getAdminApp();

const db = () => getAdminDb();

async function seedMigrated(id: string) {
  await db().doc(`events/${id}`).set({
    title: 'Trip',
    status: 'published',
    creatorId: 'c',
    adminIds: ['c', 'a'],
    memberIds: ['c', 'a', 'm'],
    memberCount: 3,
  });
  await migrateToMembers(db(), {dryRun: false});
}

beforeEach(() => clearFirestoreEmulator());

describe('verifyMembers', () => {
  test('a migrated event has no problems', async () => {
    await seedMigrated('e1');
    expect(await verifyMembers(db())).toEqual({events: 1, problems: []});
  });

  test('reports each kind of mismatch', async () => {
    await seedMigrated('e1');
    const members = db().collection('events/e1/members');
    await members.doc('m').delete();
    await members.doc('ghost').set({uid: 'ghost', roleIds: ['participant'], permissions: ['group.readOwn', 'chat.send']});
    await members.doc('c').update({roleIds: ['admin']});
    await members.doc('a').update({roleIds: ['participant'], permissions: ['group.readOwn', 'chat.send']});
    await db().doc('events/e1').update({memberCount: 9});
    const {problems} = await verifyMembers(db());
    expect(problems.sort()).toEqual([
      'e1: a is in adminIds but holds no admin role',
      'e1: c created the event but is not Owner',
      'e1: c has stale permissions',
      'e1: ghost has a member document but is not in memberIds',
      'e1: m is in memberIds but has no member document',
      'e1: memberCount is 9, but memberIds has 3',
    ]);
  });
});
