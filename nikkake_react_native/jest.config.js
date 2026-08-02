module.exports = {
  preset: 'jest-expo',
  setupFilesAfterEnv: ['<rootDir>/jest.setup.js'],
  transformIgnorePatterns: [
    'node_modules/(?!((jest-)?react-native|@react-native(-community)?)|expo(nent)?|@expo(nent)?/.*|@expo-google-fonts/.*|react-navigation|@react-navigation/.*|@sentry/react-native|native-base|react-native-svg)',
  ],
  // ワークスペースの共有パッケージ。ビルド成果物ではなくソースを直接見る
  moduleNameMapper: {
    '^@nikkake/([^/]+)$': '<rootDir>/../packages/$1/src/index.ts',
    // packages/ 側は自分の階層に @babel/runtime を持っていないので、
    // 変換後のヘルパー参照をこちらの node_modules へ向ける
    '^@babel/runtime/(.*)$': '<rootDir>/node_modules/@babel/runtime/$1',
  },

  // e2e は Playwright が担当するので Jest からは除外する
  testPathIgnorePatterns: ['/node_modules/', '/e2e/'],
  collectCoverageFrom: ['src/lib/**/*.ts', 'src/stores/**/*.ts'],
};
