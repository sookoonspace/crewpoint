/**
 * Writes `src/shared/role_presets.json` from `src/events/permissions.ts`.
 *
 *   npm run gen:roles
 */
import {writeFileSync} from "fs";
import {join} from "path";
import {rolePresetsJson} from "../src/events/rolePresetsJson";

writeFileSync(join(__dirname, "../src/shared/role_presets.json"), rolePresetsJson());
