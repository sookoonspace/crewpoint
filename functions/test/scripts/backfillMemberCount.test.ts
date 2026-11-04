/** An idempotent admin script gives existing events a correct `memberCount`. */
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';
import {backfillMemberCount} from '../../scripts/backfillMemberCount';

getAdminApp();

const count = async (id: string) => (await getAdminDb().doc(`events/${id}`).get()).data()!.memberCount;

beforeEach(async () => {
  await clearFirestoreEmulator();
  await getAdminDb().doc('events/none').set({memberIds: ['a', 'b']});
  await getAdminDb().doc('events/wrong').set({memberIds: ['a', 'b', 'c'], memberCount: 9});
  await getAdminDb().doc('events/right').set({memberIds: ['a'], memberCount: 1});
});

describe('backfillMemberCount', () => {
  test('a dry run reports what would change, and writes nothing', async () => {
    const result = await backfillMemberCount(getAdminDb(), {dryRun: true});
    expect(result).toEqual({checked: 3, changed: 2});
    expect(await count('none')).toBeUndefined();
    expect(await count('wrong')).toBe(9);
  });

  test('sets the count from the member list', async () => {
    const result = await backfillMemberCount(getAdminDb(), {dryRun: false});
    expect(result).toEqual({checked: 3, changed: 2});
    expect(await count('none')).toBe(2);
    expect(await count('wrong')).toBe(3);
    expect(await count('right')).toBe(1);
  });

  test('running it again changes nothing', async () => {
    await backfillMemberCount(getAdminDb(), {dryRun: false});
    const again = await backfillMemberCount(getAdminDb(), {dryRun: false});
    expect(again).toEqual({checked: 3, changed: 0});
  });
});
