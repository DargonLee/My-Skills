module.exports = {
  root: true,
  extends: '@react-native-community',
  plugins: ['prettier'],
  rules: {
    'no-fallthrough': 0,
    'prettier/prettier': ['error', {endOfLine: 'auto'}],
    'react-native/no-inline-styles': 0,
    'no-console': 'warn',
    '@typescript-eslint/func-call-spacing': 0,
    curly: ['error', 'multi-line'],
  },
  parserOptions: {
    ecmaVersion: 2022,
  },
};
