---
name: harlan-git-commit
description: Harlan的Git提交规范 - 压缩标题+详细描述，只提交不推送
version: 1.0.0
---

# Harlan Git Commit 规范

## 核心原则

1. **只提交，不推送** - 执行 `git commit`，永远不执行 `git push`
2. **标题压缩内容** - 用简洁的中文标题总结改了什么，突出核心变更
3. **描述详细展开** - 在 Description 中详细说明变更文件、原因、影响

## Commit 格式

```
<类型>: <压缩的标题>

<详细描述（变更文件、原因、影响）>
```

## 类型前缀

| 类型 | 使用场景 |
|------|----------|
| feat | 新功能 |
| fix | Bug修复 |
| refactor | 重构（不改变功能） |
| docs | 文档更新 |
| chore | 维护任务 |
| perf | 性能优化 |
| style | 代码风格（格式化等） |

## 标题命名规则

- 使用中文撰写
- 简洁明了，不超过50字
- 突出核心变更，避免模糊描述
- 示例：
  - `fix: 修复打包崩溃问题`
  - `feat: 添加技能创建功能`
  - `docs: 更新README安装说明`

## Description 模板

```
变更的文件:
- file1.ts
- file2.rs

变更内容:
- 具体描述1
- 具体描述2

影响范围:
- 影响的模块或功能
```

## 执行步骤

1. `git status` - 查看未提交的变更
2. `git diff --stat` - 确认变更统计
3. `git diff` - 查看具体变更内容
4. 分析变更内容，提取关键信息
5. 生成压缩标题（≤50字，中文）
6. 生成详细描述（变更文件+内容+影响）
7. `git add <files>` - 添加要提交的文件
8. `git commit -m "<标题>" -m "<详细描述>"` - 执行提交（**不加 --no-verify**）

## 示例

### 场景1：修复Bug

**变更：**
- 修改了 `src-tauri/tauri.conf.json` 修复打包崩溃
- 更新了 `README.md` 添加macOS签名说明

**标题：**
```
fix: 修复macOS打包崩溃问题
```

**描述：**
```
变更的文件:
- src-tauri/tauri.conf.json
- README.md

变更内容:
- 移除tauri.conf.json中的升级key配置
- 添加macOS无法验证开发者的解决说明（xattr命令）

影响范围:
- 修复打包构建流程
- 改善macOS用户体验
```

---

### 场景2：更新文档

**变更：**
- 修正CLAUDE.md中ToastProvider的位置说明

**标题：**
```
docs: 修正CLAUDE.md中State Management描述
```

**描述：**
```
变更的文件:
- CLAUDE.md

变更内容:
- 指出ToastProvider实际位于 src/components/ui/Toast.tsx
- 原描述误认为在 src/context/

影响范围:
- 仅影响文档准确性，不影响代码功能
```

---

### 场景3：新功能

**变更：**
- 添加了新的skills管理功能
- 修改了Rust后端添加新的command
- 添加了对应的TypeScript类型

**标题：**
```
feat: 添加skills备份与恢复功能
```

**描述：**
```
变更的文件:
- src-tauri/src/commands.rs
- src-tauri/src/domain.rs
- src/services/backupSource.ts
- src/types/index.ts

变更内容:
- 新增 backup_source 命令用于备份skills
- 新增 restore_source 命令用于恢复skills
- 添加 BackupSource 和 RestoreSource 类型定义
- 前端添加 backupSource.ts 服务层封装

影响范围:
- 新增备份恢复UI入口
- 用户可手动创建快照并回滚
```
