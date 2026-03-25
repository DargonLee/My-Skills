module.exports = {
  '*.{js,jsx,ts,tsx}': [
    'eslint --fix', // 自动修复 ESLint 问题
    'prettier --write', // 自动格式化
  ],
};
