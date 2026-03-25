module.exports = {
  presets: ['module:metro-react-native-babel-preset'],
  plugins: [
    [
      'module-resolver',
      {
        root: ['./src'],
        extensions: ['.js', '.ios.js', '.android.js', '.ts', '.jsx'],
        alias: {
          '@': './src',
          '@assets': './src/assets',
          '@components': './src/components',
          '@core': './src/core',
          '@hooks': './src/hooks',
          '@pages': './src/pages',
        },
      },
    ],
    'react-native-reanimated/plugin',
  ],
};
