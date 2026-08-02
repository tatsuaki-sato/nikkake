// eslint-disable-next-line @typescript-eslint/no-var-requires
const path = require('path');
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { getDefaultConfig } = require('expo/metro-config');

const projectRoot = __dirname;
const workspaceRoot = path.resolve(projectRoot, '..');

const config = getDefaultConfig(projectRoot);

// packages/ を Metro の監視対象に入れる。
// これが無いと @nikkake/api-client を編集してもリロードされない。
config.watchFolders = [path.resolve(workspaceRoot, 'packages')];

// 自分の node_modules を先に見る。
// react / react-native がワークスペース側にも入ってしまった場合に
// 二重ロードで壊れるのを防ぐため、順序は変えないこと。
config.resolver.nodeModulesPaths = [
  path.resolve(projectRoot, 'node_modules'),
  path.resolve(workspaceRoot, 'node_modules'),
];

module.exports = config;
