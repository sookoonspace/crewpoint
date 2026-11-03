// Acceptance tests. Separate from the default suite because a failure here is
// a product gap, not a regression. CI fails only on scenarios listed in
// test_acceptance/finished_scenarios.json at the repo root.
//
// Run: npm run test:acceptance
const base = require('./jest.config.js');

module.exports = {
  ...base,
  testMatch: ['<rootDir>/test_acceptance/**/*.test.ts'],
  testTimeout: 180000,
};
