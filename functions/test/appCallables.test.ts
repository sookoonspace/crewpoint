/**
 * Every callable the app calls must be exported from `src/index.ts`, or it
 * is never deployed and the app's call fails with "not found". #72's
 * `setExpenseAccess` and `getMyBalance` were written and tested but never
 * exported, which only showed when dev was rolled out.
 */
import {readFileSync, readdirSync, statSync} from "fs";
import {join} from "path";
import * as index from "../src/index";

const LIB = join(__dirname, "..", "..", "lib");

function dartFiles(dir: string): string[] {
  return readdirSync(dir).flatMap((name) => {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) return dartFiles(path);
    return name.endsWith(".dart") ? [path] : [];
  });
}

/** Names passed to `httpsCallable('…')` or a `_call('…')` helper. */
function callableNames(): Set<string> {
  const pattern = /(?:httpsCallable|_call)\s*(?:<[^>]*>)?\(\s*'([A-Za-z]+)'/g;
  const names = new Set<string>();
  for (const file of dartFiles(LIB)) {
    for (const match of readFileSync(file, "utf8").matchAll(pattern)) {
      names.add(match[1]);
    }
  }
  return names;
}

describe("callables the app uses", () => {
  const names = [...callableNames()].sort();

  it("finds the app's calls", () => {
    expect(names).toEqual(
      expect.arrayContaining(["createEvent", "joinEvent", "saveExpense"]),
    );
  });

  it.each(names)("%s is exported for deploy", (name) => {
    expect(Object.keys(index)).toContain(name);
  });
});
