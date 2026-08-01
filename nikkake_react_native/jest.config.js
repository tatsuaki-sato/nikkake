module.exports = {
  preset: 'jest-expo',
  setupFilesAfterEnv: ['<rootDir>/jest.setup.js'],
  transformIgnorePatterns: [
    'node_modules/(?!((jest-)?react-native|@react-native(-community)?)|expo(nent)?|@expo(nent)?/.*|@expo-google-fonts/.*|react-navigation|@react-navigation/.*|@sentry/react-native|native-base|react-native-svg)',
  ],
  // e2e は Playwright が担当するので Jest からは除外する
  testPathIgnorePatterns: ['/node_modules/', '/e2e/'],
  collectCoverageFrom: ['src/lib/**/*.ts', 'src/stores/**/*.ts'],
};
