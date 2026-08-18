/** @type {import('jest').Config} */
module.exports = {
  testEnvironment: 'node',
  testMatch: ['<rootDir>/test/**/*.test.ts'],
  testTimeout: 30000,
  transform: {
    '^.+\\.[tj]s$': ['ts-jest', {tsconfig: '<rootDir>/tsconfig.test.json'}],
  },
  // `jose` (firebase-admin 14 -> jwks-rsa 4) is ESM-only. Jest's CommonJS
  // runtime cannot require it, so it is transpiled rather than ignored.
  // Everything else in node_modules is left untransformed.
  transformIgnorePatterns: ['/node_modules/(?!jose/)'],
};
