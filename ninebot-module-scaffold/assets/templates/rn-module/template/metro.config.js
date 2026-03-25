/**
 * Metro configuration for React Native
 * https://github.com/facebook/react-native
 *
 * @format
 */
const {mergeConfig, getDefaultConfig} = require('@react-native/metro-config');
const {
  createHarmonyMetroConfig,
} = require('@react-native-oh/react-native-harmony/metro.config');

const defaultConfig = getDefaultConfig(__dirname);

/**
 * @type {import("metro-config").ConfigT}
 */
const config = {
  resolver: {
    assetExts: [...defaultConfig.resolver.assetExts, 'svga'],
  },
  transformer: {
    getTransformOptions: async () => ({
      transform: {
        experimentalImportSupport: false,
        inlineRequires: true,
      },
    }),
  },
  watchman: false,
  watch: {
    usePolling: true,
    interval: 1000,
  },
};

module.exports = mergeConfig(
  defaultConfig,
  createHarmonyMetroConfig({
    reactNativeHarmonyPackageName: '@react-native-oh/react-native-harmony',
  }),
  config,
);
