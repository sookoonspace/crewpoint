// Automated tests must never reach a real Firebase project (L12). A `demo-`
// project ID makes the Firebase tools refuse any service that is not emulated.
describe('test environment', () => {
  test('runs against a demo project', () => {
    expect(process.env.GCLOUD_PROJECT).toMatch(/^demo-/);
  });

  test('points Firestore and Auth at the emulators', () => {
    expect(process.env.FIRESTORE_EMULATOR_HOST).toBeTruthy();
    expect(process.env.FIREBASE_AUTH_EMULATOR_HOST).toBeTruthy();
  });
});
