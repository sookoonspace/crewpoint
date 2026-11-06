import {PERMISSIONS, PRESET_ROLES} from "./permissions";

/**
 * The catalogue and presets as `src/shared/role_presets.json`, which the app
 * loads so its role screens show exactly what the server grants. This file is
 * the source; regenerate the JSON with `npm run gen:roles`, and a test fails
 * if the two differ.
 */
export function rolePresetsJson(): string {
  const data = {
    permissions: PERMISSIONS,
    presets: Object.entries(PRESET_ROLES).map(([id, role]) => ({
      id,
      name: role.name,
      permissions: role.permissions,
    })),
  };
  return JSON.stringify(data, null, 2) + "\n";
}
