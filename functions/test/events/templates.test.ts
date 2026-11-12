/**
 * Req 62, 38a (GE-06): system templates are data only, in
 * `assets/templates/`, copied to `functions/templates/` for the server.
 * Each is checked, and sets modules, labels, roles, fields, categories,
 * the attendance policy and settings.
 */
import * as fs from 'fs';
import * as path from 'path';
import {SYSTEM_TEMPLATE_IDS, systemTemplate, validateTemplate} from '../../src/events/templates';

const assets = path.join(__dirname, '..', '..', '..', 'assets', 'templates');
const copies = path.join(__dirname, '..', '..', 'templates');

describe('system templates', () => {
  test('are the six, in order', () => {
    expect(SYSTEM_TEMPLATE_IDS).toEqual(
      ['blank', 'party', 'wedding', 'cricket_tournament', 'golf_outing', 'convention']);
  });

  test("the server copy matches the app's files (run npm run gen:templates)", () => {
    for (const file of fs.readdirSync(assets)) {
      expect(fs.readFileSync(path.join(copies, file), 'utf8'))
        .toBe(fs.readFileSync(path.join(assets, file), 'utf8'));
    }
  });

  test('every one is valid', () => {
    for (const id of SYSTEM_TEMPLATE_IDS) {
      expect(() => validateTemplate(systemTemplate(id))).not.toThrow();
    }
  });

  test('expense access defaults follow Req 38a', () => {
    const mode = (id: string) => systemTemplate(id)!.settings.expenseAccess;
    for (const id of ['party', 'wedding', 'blank']) expect(mode(id)).toEqual({mode: 'everyone'});
    expect(mode('convention')).toEqual({mode: 'selected', roleIds: [], uids: []});
    for (const id of ['cricket_tournament', 'golf_outing']) expect(mode(id)).toEqual({mode: 'involved'});
  });

  test('an unknown template is none', () => {
    expect(systemTemplate('nope')).toBeNull();
  });
});

describe('validateTemplate', () => {
  const good = () => JSON.parse(JSON.stringify(systemTemplate('convention')));
  const broken = (change: (t: any) => void) => {
    const t = good();
    change(t);
    return () => validateTemplate(t);
  };

  test('refuses an unknown module', () => {
    expect(broken((t) => t.modules.games = true)).toThrow(/module/);
  });
  test('refuses a label for an unknown concept', () => {
    expect(broken((t) => t.labels.widget = {one: 'W', other: 'Ws'})).toThrow(/label/);
  });
  test('refuses a bad field', () => {
    expect(broken((t) => t.fields[0].type = 'photo')).toThrow(/field/);
    expect(broken((t) => t.fields[0].visibility = 'public')).toThrow(/field/);
  });
  test('refuses a bad attendance policy or expense access', () => {
    expect(broken((t) => t.settings.attendancePolicy = 'sometimes')).toThrow(/attendance/);
    expect(broken((t) => t.settings.expenseAccess = {mode: 'all'})).toThrow(/expense/);
  });
  test('refuses changing the Owner role or basing a role on nothing', () => {
    expect(broken((t) => t.roles.owner = {name: 'Boss', base: 'owner'})).toThrow(/role/);
    expect(broken((t) => t.roles.helper = {name: 'Helper', base: 'nobody'})).toThrow(/role/);
  });
  test('refuses a category without an ID', () => {
    expect(broken((t) => t.settings.categories.push({name: 'Senior'}))).toThrow(/categor/);
  });
});
