---
name: git-commit
description: 智能分析工作区变更，生成简洁的提交信息并执行提交。自动暂存所有变更，分析文件类型和变更性质，生成符合 Conventional Commits 规范的提交信息。
disable-model-invocation: true
allowed-tools: Bash(git *), Read, Write
argument-hint: "[可选：自定义提交信息]"
---

智能提交工作区所有变更。

## 执行流程

1. **检查仓库状态**
   - 确认当前目录是 Git 仓库
   - 获取当前分支名

2. **暂存变更**
   - 执行 `git add -A` 暂存所有变更（包括新增、修改、删除）

3. **分析变更**
   - 获取变更统计：`git diff --cached --stat`
   - 分析文件类型和变更性质：
     - 新增文件 → `feat`
     - 主要删除 → `remove` 或 `clean`
     - 配置变更 → `config`
     - 测试文件 → `test`
     - 文档变更 → `docs`
     - 重构/重命名 → `refactor`
     - 其他修改 → `fix`

4. **生成提交信息**
   - 格式：`type(scope): 简洁描述, +insertions/-deletions`
   - 限制：不超过 50 个字符
   - 示例：`feat(api): add auth middleware, +45/-3`

5. **执行提交**
   - 如果提供了自定义参数 `$ARGUMENTS`，使用用户输入的信息
   - 否则使用自动生成的信息
   - 执行 `git commit -m "message"`

6. **输出结果**
   - 显示提交的文件列表
   - 显示最终使用的提交信息
   - 显示提交哈希

## 使用示例

- `/commit` - 自动生成提交信息并提交
- `/commit "fix: urgent hotfix"` - 使用自定义信息提交