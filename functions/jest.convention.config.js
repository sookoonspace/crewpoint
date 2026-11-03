// Convention acceptance tests. Separate from the default suite because a
// failure here is a product gap, not a regression.
//
// Run: npx firebase emulators:exec --only firestore,auth \
//        "jest --runInBand --config jest.convention.config.js"
const base = require('./jest.config.js');

module.exports = {
  ...base,
  testMatch: ['<rootDir>/test_convention/**/*.test.ts'],
  testTimeout: 180000,
};
