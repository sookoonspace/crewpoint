/**
 * Spec #233 Req 8, 11, 16-19, 60 (#239): an event's registration settings,
 * checked before they are saved. Pure, so no emulator.
 */
import {
  DEFAULT_REGISTRATION,
  RegistrationContext,
  RegistrationSettingsError,
  normaliseSlug,
  parseRegistrationSettings,
  withRegistrationDefaults,
} from '../../src/registration/settings';

const ctx: RegistrationContext = {
  fields: [
    {id: 'booked', type: 'yesNo', options: []},
    {id: 'confirmation', type: 'text', options: []},
    {id: 'shirt', type: 'singleChoice', options: ['S', 'M', 'L']},
    {id: 'kidsActivity', type: 'multiChoice', options: ['Swim', 'Craft']},
  ],
  categoryIds: ['adult', 'kid'],
  roles: {
    participant: ['chat.send', 'group.readOwn'],
    player: ['chat.send', 'group.readOwn'],
    admin: ['event.manage', 'members.manage', 'chat.send'],
    owner: ['event.manage', 'event.transfer'],
  },
};

const parse = (over: Record<string, unknown> = {}) =>
  parseRegistrationSettings({...DEFAULT_REGISTRATION, ...over}, ctx);

const refuses = (over: Record<string, unknown>, message: RegExp) =>
  expect(() => parse(over)).toThrow(message);

describe('parseRegistrationSettings', () => {
  test('the defaults are valid: invited, no deadline, 72-hour offers, Participant', () => {
    const s = parse();
    expect(s.mode).toBe('invited');
    expect(s.deadline).toBeNull();
    expect(s.offerHours).toBe(72);
    expect(s.registrationRoleId).toBe('participant');
    expect(s.extraGuests).toBe(0);
    expect(s.blocks.people).toBe(true);
  });

  test('keeps open mode, a deadline, review, extra guests and the offer window', () => {
    const deadline = Date.UTC(2027, 5, 30, 23, 59);
    const s = parse({mode: 'open', deadline, review: true, extraGuests: 2, offerHours: 48});
    expect(s).toEqual(expect.objectContaining({
      mode: 'open', deadline, review: true, extraGuests: 2, offerHours: 48,
    }));
  });

  test('refuses an unknown mode, and bad numbers', () => {
    refuses({mode: 'public'}, /mode/);
    refuses({extraGuests: -1}, /extra guests/);
    refuses({extraGuests: 1.5}, /extra guests/);
    refuses({extraGuests: 21}, /extra guests/);
    refuses({offerHours: 0}, /offer/);
    refuses({offerHours: 337}, /offer/);
    refuses({deadline: 'tomorrow'}, /deadline/);
  });

  test('sections are named, ordered and list existing questions, each in one section', () => {
    const sections = [
      {id: 'stay', name: {en: 'Your stay'}, fieldIds: ['booked', 'confirmation']},
      {id: 'extras', name: {en: 'Extras', gu: 'વધારાનું'}, fieldIds: ['shirt']},
    ];
    expect(parse({sections}).sections).toEqual(sections);
    refuses({sections: [{id: 'a', name: {en: 'A'}, fieldIds: ['nope']}]}, /question/);
    refuses({sections: [
      {id: 'a', name: {en: 'A'}, fieldIds: ['shirt']},
      {id: 'b', name: {en: 'B'}, fieldIds: ['shirt']},
    ]}, /one section/);
    refuses({sections: [{id: 'a', name: {en: '  '}, fieldIds: []}]}, /name/);
    refuses({sections: [
      {id: 'a', name: {en: 'A'}, fieldIds: []},
      {id: 'a', name: {en: 'B'}, fieldIds: []},
    ]}, /section/);
  });

  test('#244: the contact line families see once registration closes', () => {
    expect(parse({contactLine: {en: 'Questions? Call Nilesh at 312-555-0123', gu: 'પ્રશ્નો?'}}).contactLine)
      .toEqual({en: 'Questions? Call Nilesh at 312-555-0123', gu: 'પ્રશ્નો?'});
    expect(parse({}).contactLine).toBeNull();
    refuses({contactLine: {en: 'x'.repeat(5001)}}, /contact line/);
  });

  test('blocks switch on and off, with age only for the People block', () => {
    const blocks = {
      people: true, ageOnly: true, stay: true, sessionChoices: true, waivers: false, contact: true,
    };
    expect(parse({blocks}).blocks).toEqual(blocks);
    refuses({blocks: {...blocks, stay: 'yes'}}, /block/);
  });

  test('a condition is a category, or one other answer having a value', () => {
    const conditions = {
      kidsActivity: {categoryId: 'kid'},
      confirmation: {fieldId: 'booked', value: 'yes'},
      shirt: {fieldId: 'kidsActivity', value: 'Swim'},
    };
    // shirt depends on kidsActivity, which has a condition itself.
    refuses({conditions}, /itself has a condition/);
    const ok = {kidsActivity: conditions.kidsActivity, confirmation: conditions.confirmation};
    expect(parse({conditions: ok}).conditions).toEqual(ok);
  });

  test('refuses a condition on an unknown question, category, answer or value', () => {
    refuses({conditions: {nope: {categoryId: 'kid'}}}, /question/);
    refuses({conditions: {shirt: {categoryId: 'senior'}}}, /category/);
    refuses({conditions: {shirt: {fieldId: 'nope', value: 'yes'}}}, /question/);
    refuses({conditions: {shirt: {fieldId: 'booked', value: 'maybe'}}}, /value/);
    refuses({conditions: {booked: {fieldId: 'shirt', value: 'XL'}}}, /value/);
    refuses({conditions: {booked: {fieldId: 'booked', value: 'yes'}}}, /itself/);
    // A text answer has no values to choose from.
    refuses({conditions: {shirt: {fieldId: 'confirmation', value: 'A1'}}}, /yes\/no or choice/);
  });

  test('the after-registration note can be replaced by a second one from a date', () => {
    const from = Date.UTC(2027, 4, 1);
    const s = parse({
      afterNote: {en: 'Book at hotel.example with code CONV27'},
      laterNote: {en: 'Hotel block closed; call the front desk'},
      laterNoteFrom: from,
    });
    expect(s.afterNote).toEqual({en: 'Book at hotel.example with code CONV27'});
    expect(s.laterNoteFrom).toBe(from);
    refuses({afterNote: {en: 'A'}, laterNote: {en: 'B'}}, /date/);
    refuses({afterNote: {en: 'x'.repeat(5001)}}, /note/);
  });

  test("keeps what's included, for the event page", () => {
    expect(parse({included: {en: 'Lunch, dinner and the T-shirt'}}).included)
      .toEqual({en: 'Lunch, dinner and the T-shirt'});
    expect(parse().included).toBeNull();
  });

  test('an empty note is no note', () => {
    expect(parse({afterNote: {en: '  '}}).afterNote).toBeNull();
  });

  test('the role for people who register exists, is not Owner and manages nothing', () => {
    expect(parse({registrationRoleId: 'player'}).registrationRoleId).toBe('player');
    refuses({registrationRoleId: 'owner'}, /role/);
    refuses({registrationRoleId: 'admin'}, /organizer permissions/);
    refuses({registrationRoleId: 'ghost'}, /role/);
  });

  test('ignores keys it does not know, and never takes the slug from the form', () => {
    const s = parse({slug: 'mine', extra: true}) as unknown as Record<string, unknown>;
    expect(s.slug).toBeUndefined();
    expect(s.extra).toBeUndefined();
  });

  test('throws its own error type, so the callable can say what is wrong', () => {
    expect(() => parse({mode: 'x'})).toThrow(RegistrationSettingsError);
  });
});

describe('withRegistrationDefaults', () => {
  test("missing settings take the template's, then the platform's", () => {
    expect(withRegistrationDefaults(undefined, undefined)).toEqual(DEFAULT_REGISTRATION);
    expect(withRegistrationDefaults(undefined, {mode: 'open'}).mode).toBe('open');
    expect(withRegistrationDefaults({review: true}, {mode: 'open'})).toEqual(
      expect.objectContaining({mode: 'open', review: true, offerHours: 72}));
    expect(withRegistrationDefaults({blocks: {stay: true}}, undefined).blocks).toEqual(
      {...DEFAULT_REGISTRATION.blocks, stay: true});
  });
});

describe('normaliseSlug', () => {
  test('letters, numbers and hyphens, kept lower-case so case never makes two', () => {
    expect(normaliseSlug('Convention-2027')).toBe('convention-2027');
    expect(normaliseSlug('  shah-wedding ')).toBe('shah-wedding');
  });

  test('refuses anything else, too short, too long, or a reserved word', () => {
    for (const bad of ['ab', 'a b', 'café', '-start', 'end-', 'under_score', 'x'.repeat(41), 'join', 'admin']) {
      expect(normaliseSlug(bad)).toBeNull();
    }
  });
});
