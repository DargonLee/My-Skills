---
name: idea
description: Idea Inbox 管理系统。当用户输入 /idea 时触发，用于批量处理 docs/ideas/inbox.md
  中暂存的想法并主动推进执行。同时监听用户在 AI 执行任务期间随手记录的新想法。
  当用户说"看看我的 inbox"、"处理一下想法"、"执行 idea"、"/idea" 时立即触发。
  也应在用户说"我有个想法先记下来"时主动引导写入 inbox.md，不打断当前任务。
allowed-tools: Read, Write, Bash, Edit
---

# Idea Inbox Skill

帮助用户在 AI 执行任务期间捕获临时想法，并在合适时机批量处理、主动推进落地。

## 两种触发场景

### 场景 A：记录想法（AI 正在执行任务时）

用户在对话框中冒出一个新想法，不想打断当前任务。

**你的行为：**
1. 识别用户意图是「记录想法」而非「立即执行」
2. 将想法格式化后追加写入 `docs/ideas/inbox.md`
3. 回复一句简短确认，**不展开讨论**，不打断当前任务流
4. 继续执行原来的任务

**确认回复格式（简短）：**
```
✓ 已记录到 inbox → #tag 想法摘要
```

---

### 场景 B：/idea 指令（批量处理）

用户输入 `/idea`，表示当前任务已完成，要处理 inbox 中积累的想法。

**执行流程：**

#### Step 1：读取 inbox
读取 `docs/ideas/inbox.md`，若文件不存在则创建并告知用户 inbox 为空。

#### Step 2：分类展示
将所有未处理条目按标签分组展示，供用户确认优先级：

```
📋 Inbox 共 N 条想法

🚀 #feature (2)
  [ ] 支持暗色主题
  [ ] 添加导出功能

🐛 #bug (1)
  [ ] 登录页按钮对齐问题

❓ #question (1)
  [ ] 这里为什么用 useEffect 而非 useMemo？

💭 #note (1)
  [ ] 重构时考虑抽象 BaseViewModel
```

询问用户：「全部处理，还是指定某类先来？」

#### Step 3：逐条主动推进

对每条想法，根据标签采取不同行动：

| 标签 | 行动策略 |
|------|----------|
| `#feature` | 分析可行性 → 拆解实现步骤 → 询问是否立即开始 |
| `#bug` | 定位可能原因 → 给出修复方案 → 询问是否立即修复 |
| `#question` | 直接回答问题 → 给出建议 |
| `#refactor` | 分析重构影响范围 → 提出方案 → 询问优先级 |
| `#note` | 确认理解 → 问是否需要进一步行动 |
| 无标签 | 先判断类型，再按上述策略处理 |

**主动推进原则：** 不只是「回答」，而是主动提出「我现在就可以帮你做 X，要开始吗？」

#### Step 4：归档处理结果

处理完毕后：
1. 将已处理条目移动到 `docs/ideas/processed.md`（附处理时间和结论摘要）
2. 从 `inbox.md` 中删除已处理条目
3. 输出归档摘要

---

## inbox.md 格式规范

```markdown
# Idea Inbox

<!-- AI 执行任务期间随手记录的想法，/idea 时批量处理 -->

- [ ] #feature 支持多语言切换
- [ ] #bug 首页在 iPad 横屏时布局错乱
- [ ] #question 这里的 useCallback 依赖数组是否完整？
- [ ] #refactor 考虑将 NBAdapter 拆成更小的模块
- [ ] #note 下次和团队讨论 API 版本策略
```

**标签说明：**
- `#feature` — 新功能/改进建议
- `#bug` — 缺陷发现
- `#question` — 技术疑问
- `#refactor` — 重构想法
- `#note` — 备忘/待讨论

无标签也可以，AI 会自动判断类型。

---

## processed.md 归档格式

```markdown
# Processed Ideas

## 2026-04-29

### ✅ #feature 支持暗色主题
- **结论：** 可行，已拆解为 3 步：(1) CSS 变量改造 (2) 系统主题检测 (3) 用户偏好持久化
- **状态：** 已开始执行

### ✅ #bug 登录页按钮对齐
- **结论：** `flex` 容器缺少 `align-items: center`，已修复
- **状态：** 已完成
```

---

## 初始化

首次使用时，若 `docs/ideas/` 目录不存在：

```bash
mkdir -p docs/ideas
```

创建 `inbox.md` 模板（参考上方格式规范）和空的 `processed.md`。

并在项目 `CLAUDE.md` 中追加：

```markdown
## Idea Inbox

随手记录的想法存放在 `docs/ideas/inbox.md`，使用 `/idea` 批量处理。
标签：#feature #bug #question #refactor #note
```

---

## 边界处理

- **inbox 为空时：** 告知用户 inbox 清空，询问是否有新想法要记录
- **想法描述模糊时：** 先追加原文，处理时再澄清
- **用户只想记录不想处理：** 尊重用户，只写入不展开
- **文件不存在：** 自动创建，不报错
