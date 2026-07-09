---
name: git-commit
description: 智能分析工作区变更，自动生成符合 Conventional Commits 规范的精炼提交信息并执行提交。
disable-model-invocation: true
allowed-tools: Bash(git *), Read, Write
argument-hint: "[可选：自定义提交信息]"

---

# 智能 Git 提交命令说明

自动化执行代码暂存与智能提交。

## 执行流程

1. **状态检查与暂存**
   - 检查当前是否为 Git 仓库。
   - 自动执行 `git add -A` 暂存所有变更（若有特定需求，允许用户先手动 `git add` 部分文件，此步骤则只补充暂存）。

2. **变更智能分析**
   - 执行 `git diff --cached --stat` 分析变更规模与受影响的模块。
   - 判定**变更类型（Type）**：
     - `feat`: 新增功能/文件
     - `fix`: 修复 Bug/异常修改
     - `refactor`: 代码重构（不影响功能）
     - `docs`: 文档、README 修改
     - `style`: 样式、格式化、非业务逻辑调整
     - `test`: 增加或修改测试用例
     - `chore`: 构建流程、依赖、配置变更（如 .gitignore, package.json）

3. **生成提交信息（Commit Message）**
   - **格式规范**：`<type>(<scope>): <description>` 
   - **要求**：
     - `scope`（可选）：填写受影响的模块或核心文件（如 `api`, `ui`, `config`）。
     - `description`：使用英文祈使句，小写开头，末尾无句号，核心描述控制在 50 字以内。
     - 尽量不包含无意义的 `updated code`，要指出具体变更。
   - **示例**：`feat(auth): add jwt login verification`

4. **执行提交**
   - 如果用户输入了自定义参数 `$ARGUMENTS`，优先使用用户输入的信息。
   - 否则，使用自动生成的规范信息。
   - 执行 `git commit -m "<message>"`。

5. **后置确认**
   - 输出最终的提交信息与 Commit SHA，确保工作区干净。

## 使用示例

* `/commit` —— 自动分析所有变更并智能提交。
* `/commit "fix(api): fix user profile memory leak"` —— 使用自定义的规范信息直接提交。