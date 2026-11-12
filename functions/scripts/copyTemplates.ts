/**
 * Copies the system templates from the app's `assets/templates/` to
 * `functions/templates/`, which deploys with the functions. A test fails
 * when the copy falls behind.
 *
 *   npm run gen:templates
 */
import {copyFileSync, mkdirSync, readdirSync} from "fs";
import {join} from "path";

const from = join(__dirname, "../../assets/templates");
const to = join(__dirname, "../templates");
mkdirSync(to, {recursive: true});
for (const file of readdirSync(from)) {
  if (file.endsWith(".json")) copyFileSync(join(from, file), join(to, file));
}
