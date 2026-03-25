module.exports = {
  overrides: [
    {
      files: ['*.js', '*.jsx', '*.ts', '*.tsx'],
      options: {
        bracketSpacing: true,
        bracketSameLine: false,
        singleQuote: true,
        trailingComma: 'all',
        arrowParens: 'always',
      },
    },
  ],
};
