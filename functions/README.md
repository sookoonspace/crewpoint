# CrewPoint Cloud Functions

Firebase Cloud Functions (v2, callable + Firestore triggers) for CrewPoint.

## Test suite

Tests run against the local Firebase emulator (Firestore + Auth). They are
emulator-only — `setup.ts` errors out if `FIRESTORE_EMULATOR_HOST` is unset.

### Prerequisites

- Node 22 (matches `engines.node` in `package.json`)
- Java 11+ (required by the Firebase emulator)
- `firebase-tools` available on PATH (`npm i -g firebase-tools` or `npx`)

### Running tests

```bash
npm install           # one-time
npm test              # runs jest in-band against fresh emulator instances
```

`npm test` invokes `firebase emulators:exec --only firestore,auth 'jest --runInBand'`,
which boots the emulator, runs the test suite once, and tears it down — ideal
for CI and local one-shot runs.

For watch mode during local development:

```bash
npm run test:watch
```

### Test layout

- `test/setup.ts` — boots a fresh `RulesTestEnvironment` per call, points at
  the local emulator, loads production `firestore.rules`.
- `test/firestore-rules.test.ts` — emulator-driven access-matrix tests for
  `firestore.rules`. Each test acquires an isolated authed/anonymous context
  via `@firebase/rules-unit-testing` and asserts allow/deny via
  `assertSucceeds` / `assertFails`.

### Adding tests

1. Seed preconditions via `env.withSecurityRulesDisabled(async (ctx) => { … })`
   so test data isn't fighting the rules under audit.
2. Acquire the assertion context via `env.authenticatedContext('uid')` or
   `env.unauthenticatedContext()`.
3. Wrap the assertion in `assertSucceeds` (allow) or `assertFails` (deny).
4. Call `env.clearFirestore()` in `afterEach` to keep state isolated.
