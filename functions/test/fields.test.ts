/**
 * Req 41 (GE-04, GAP-WED-14, Z-01): custom fields. `event.manage` defines
 * them; anyone in the event reads the definitions so they can fill them in.
 * Standard answers sit on the participant or group, with the filter tags
 * the roster queries by. Private answers sit in the `private` document, so
 * a crew lead who reads the roster never sees them.
 */
import {RulesTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {collection, doc, getDoc, getDocs, query, setDoc, updateDoc, where, orderBy} from 'firebase/firestore';
import {getTestEnv} from './setup';
import {computePermissions} from '../src/events/permissions';

let env: RulesTestEnvironment;
beforeAll(async () => {
  env = await getTestEnv();
});
afterEach(() => env.clearFirestore());
afterAll(() => env.cleanup());

const E = 'events/conv';
const as = (uid: string) => env.authenticatedContext(uid).firestore();
const PEOPLE: Record<string, [string[], string[]]> = {
  owner: [['owner'], []],
  lead: [['crewLead'], []],
  parent: [['participant'], ['f1']],
  plain: [['participant'], []],
};

beforeEach(async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, E), {
      title: 'Convention', status: 'published', creatorId: 'owner', adminIds: ['owner'],
      memberIds: Object.keys(PEOPLE), skipMemberSync: true,
    });
    for (const [uid, [roleIds, groupIds]] of Object.entries(PEOPLE)) {
      await setDoc(doc(db, `${E}/members/${uid}`), {
        uid, roleIds, crewIds: [], groupIds,
        permissions: computePermissions(roleIds, {}, {editsOwnGroup: groupIds.length > 0}),
      });
    }
    await setDoc(doc(db, `${E}/fields/diet`), {
      label: 'Diet', type: 'singleChoice', options: ['Jain', 'Veg'], required: true,
      scope: 'participant', visibility: 'standard', order: 0,
    });
    await setDoc(doc(db, `${E}/groups/f1`), {name: 'Shahs', sortName: 'shahs', adultUids: ['parent']});
    await setDoc(doc(db, `${E}/participants/kid`), {
      name: 'Ana', sortName: 'ana', groupId: 'f1', isChild: true, createdBy: 'owner', status: 'active',
      categoryId: 'child', fields: {diet: 'Jain'}, filterTags: ['diet=Jain'],
    });
    await setDoc(doc(db, `${E}/participants/kid/private/details`), {
      birthDate: '2020-05-01', fields: {allergy: 'Peanuts'},
    });
    await setDoc(doc(db, `${E}/groups/f1/private/details`), {fields: {phone: '555'}});
  });
});

const definition = (over: object = {}) => ({
  label: 'Meal', type: 'singleChoice', options: ['Fish', 'Veg'], required: false,
  scope: 'participant', visibility: 'standard', order: 1, ...over,
});

describe('field definitions', () => {
  test('anyone in the event reads them, to fill them in', async () => {
    await assertSucceeds(getDocs(collection(as('plain'), `${E}/fields`)));
    await assertFails(getDocs(collection(as('stranger'), `${E}/fields`)));
  });

  test('only event.manage defines them', async () => {
    await assertSucceeds(setDoc(doc(as('owner'), `${E}/fields/meal`), definition()));
    await assertFails(setDoc(doc(as('lead'), `${E}/fields/meal`), definition()));
    await assertFails(setDoc(doc(as('parent'), `${E}/fields/meal`), definition()));
  });

  test('every type, scope and visibility, and nothing else', async () => {
    const write = (over: object) => setDoc(doc(as('owner'), `${E}/fields/f`), definition(over));
    for (const type of ['text', 'number', 'date', 'singleChoice', 'multiChoice', 'yesNo']) {
      await assertSucceeds(write({type}));
    }
    await assertSucceeds(write({scope: 'group', visibility: 'private'}));
    await assertFails(write({type: 'photo'}));
    await assertFails(write({scope: 'event'}));
    await assertFails(write({visibility: 'public'}));
    await assertFails(write({label: ''}));
    await assertFails(write({options: 'Fish'}));
    await assertFails(write({secret: true}));
  });
});

describe('answers', () => {
  test('standard answers and tags go on the person, by whoever may edit them', async () => {
    await assertSucceeds(updateDoc(doc(as('parent'), `${E}/participants/kid`), {
      fields: {diet: 'Veg'}, filterTags: ['diet=Veg'], categoryId: 'child',
    }));
    await assertFails(updateDoc(doc(as('plain'), `${E}/participants/kid`), {fields: {diet: 'Veg'}}));
  });

  test('answers and tags are bounded', async () => {
    const many = Object.fromEntries(Array.from({length: 101}, (_, i) => [`f${i}`, 'x']));
    await assertFails(updateDoc(doc(as('owner'), `${E}/participants/kid`), {fields: many}));
    await assertFails(updateDoc(doc(as('owner'), `${E}/participants/kid`), {filterTags: 'diet=Veg'}));
    await assertFails(updateDoc(doc(as('owner'), `${E}/participants/kid`), {categoryId: 7}));
  });

  test('private answers live apart, and a crew lead cannot read them', async () => {
    await assertSucceeds(getDoc(doc(as('owner'), `${E}/participants/kid/private/details`)));
    await assertSucceeds(getDoc(doc(as('parent'), `${E}/participants/kid/private/details`)));
    await assertFails(getDoc(doc(as('lead'), `${E}/participants/kid/private/details`)));
    await assertSucceeds(setDoc(doc(as('parent'), `${E}/participants/kid/private/details`), {
      birthDate: '2020-05-01', fields: {allergy: 'None'},
    }));
    await assertFails(setDoc(doc(as('parent'), `${E}/participants/kid/private/details`), {
      fields: {allergy: 'None'}, notes: 'x',
    }));
  });

  test('the roster filters by category and by a field tag', async () => {
    const people = collection(as('lead'), `${E}/participants`);
    await assertSucceeds(getDocs(query(people, where('categoryId', '==', 'child'), orderBy('sortName'))));
    await assertSucceeds(getDocs(query(people, where('filterTags', 'array-contains', 'diet=Jain'), orderBy('sortName'))));
  });
});

describe('group answers', () => {
  test('standard ones go on the group, by participants.edit or its adults only', async () => {
    await assertSucceeds(updateDoc(doc(as('parent'), `${E}/groups/f1`), {fields: {hotel: 'Hilton'}, filterTags: ['hotel=Hilton']}));
    await assertSucceeds(updateDoc(doc(as('lead'), `${E}/groups/f1`), {fields: {hotel: 'Inn'}}));
    await assertFails(updateDoc(doc(as('plain'), `${E}/groups/f1`), {fields: {hotel: 'Inn'}}));
    // The rest of a group stays with the group callables.
    await assertFails(updateDoc(doc(as('parent'), `${E}/groups/f1`), {name: 'Mine'}));
    await assertFails(updateDoc(doc(as('owner'), `${E}/groups/f1`), {adultUids: ['plain']}));
  });

  test('private ones are read with participants.readPrivate or by its adults', async () => {
    await assertSucceeds(getDoc(doc(as('owner'), `${E}/groups/f1/private/details`)));
    await assertSucceeds(getDoc(doc(as('parent'), `${E}/groups/f1/private/details`)));
    await assertFails(getDoc(doc(as('lead'), `${E}/groups/f1/private/details`)));
    await assertSucceeds(setDoc(doc(as('parent'), `${E}/groups/f1/private/details`), {fields: {phone: '556'}}));
    await assertFails(setDoc(doc(as('plain'), `${E}/groups/f1/private/details`), {fields: {phone: '556'}}));
  });
});
