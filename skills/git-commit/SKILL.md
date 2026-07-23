---
name: git-commit
description: 智能分析工作区变更，读取项目 commitlint 规范生成合规提交信息并执行提交，自动处理 pre-commit 钩子失败。
disable-model-invocation: true
allowed-tools: Bash(git *), Bash(npx eslint *), Bash(npx prettier *), Read, Write, Edit
argument-hint: "[可选：自定义提交信息]"
---

# 智能 Git 提交命令说明

自动化执行代码暂存与智能提交。提交信息严格遵循项目自身的 commitlint 配置；若 pre-commit 钩子失败，做最小修复后重试。

## 执行流程

1. **状态检查与暂存**
   - 检查当前是否为 Git 仓库。
   - 执行 `git status` 查看变更全貌；若存在明显与本次提交意图无关的变更（如他人未完成的改动、依赖升级等），先向用户确认是否一并提交，再继续。
   - 自动执行 `git add -A` 暂存所有变更（若用户已手动 `git add` 部分文件，则只补充暂存）。

2. **读取项目提交规范（关键）**
   - 检测 commitlint 配置：`commitlint.config.{js,cjs,mjs,ts}`、`.commitlintrc.{js,json,yml}`、`package.json` 的 `commitlint` 字段，或 `@commitlint/*` 共享配置。
   - 从中提取并遵守：
     - `headerPattern` / `parserPreset.parserOpts.headerPattern`：决定格式，例如标准 `type(scope): subject` 还是 `[type](scope): subject` 等。
     - `type-enum`：仅可使用的 type，避免选到项目不允许的类型。
     - `scope-empty` / `scope-enum`：scope 是否必填、是否限定取值。
     - `header-max-length` / `subject-max-length`：长度上限。
   - 若检测不到任何 commitlint 配置，回退到默认规范 `<type>(<scope>): <description>`。
   - 同时留意是否存在 husky（`.husky/`）、lefthook（`lefthook.yml`）、simple-git-hooks、lint-staged（`package.json` 的 `lint-staged` 字段）等提交钩子。

3. **变更智能分析**
   - 执行 `git diff --cached --stat` 分析变更规模与受影响的模块；必要时用 `git diff --cached -- <path>` 查看具体内容。
   - 判定**变更类型（Type）**（须在第 2 步检测到的 `type-enum` 范围内）：
     - `feat`: 新增功能/文件
     - `fix`: 修复 Bug/异常修改
     - `refactor`: 代码重构（不影响功能）
     - `docs`: 文档、README 修改
     - `style`: 样式、格式化、非业务逻辑调整
     - `test`: 增加或修改测试用例
     - `chore`: 构建流程、依赖、配置变更（如 .gitignore, package.json）

4. **生成提交信息（Commit Message）**
   - **格式以第 2 步检测到的 `headerPattern` 为准**；无配置时使用 `<type>(<scope>): <description>`。
   - **要求**：
     - `scope`（可选，除非 `scope-empty` 要求必填）：受影响的模块或核心文件（如 `api`, `ui`, `config`）。
     - `description`：使用英文祈使句，小写开头，末尾无句号，核心描述控制在 50 字以内（且不超过 `header-max-length`）。
     - 指出具体变更，避免 `updated code` 之类空泛描述。
   - **示例（标准格式）**：`feat(auth): add jwt login verification`
   - 若用户输入了自定义参数 `$ARGUMENTS`，优先采用；但自定义信息仍须匹配项目 commitlint 规范，否则会被 commit-msg 钩子拒绝。

5. **执行提交**
   - 执行 `git commit -m "<message>"`。
   - **处理 pre-commit 钩子失败**：
     - 钩子（常见为 lint-staged → eslint/prettier --fix）可能因暂存文件存在 lint 错误而失败并回滚。
     - 读取钩子报错，对暂存文件做**最小修复**（如修复 ESLint/Prettier 报错），重新 `git add` 后重试 `git commit`。
     - 注意 lint-staged 的 `--fix` 可能已自动改动暂存内容，需重新 `git add` 暂存被修复的文件。
     - 若修复会牵出大量与本次提交无关的既有问题，应**停下来向用户确认**，而非无限扩大修复范围。
     - commit-msg 钩子（commitlint）失败时，按报错调整信息格式/类型/scope 后重试。

6. **后置确认**
   - 输出最终的提交信息与 Commit SHA，确保工作区干净。

## 使用示例

* `/git-commit` —— 自动分析所有变更并智能提交。
* `/git-commit "fix(auth): fix user profile memory leak"` —— 使用自定义信息直接提交（仍需通过项目 commitlint 校验）。
