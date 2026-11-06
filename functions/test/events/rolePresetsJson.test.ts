/**
 * The app reads presets from `src/shared/role_presets.json`, so it must match
 * `permissions.ts` exactly.
 */
import {readFileSync} from 'fs';
import {join} from 'path';
import {rolePresetsJson} from '../../src/events/rolePresetsJson';

test('role_presets.json matches permissions.ts (run npm run gen:roles)', () => {
  const file = readFileSync(join(__dirname, '../../src/shared/role_presets.json'), 'utf8');
  expect(file).toBe(rolePresetsJson());
});
