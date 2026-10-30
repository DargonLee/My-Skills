# My-Skills

个人 AI 编码代理的技能库。每个技能是一个目录，入口是 `SKILL.md`。Claude Code、Codex、豆包工作客户端按目录名加载。

两层：

- 仓库根目录：日常在用的技能（九号工作流、工程实践、设计套件）。
- `skills/`：插件集，由 `.claude-plugin/marketplace.json` 注册。其中 5 个未注册，只在本仓库里当工作副本。

已安装到 `~/.agents/skills/`、项目 `.agents/skills/`、`$CODEX_HOME/skills/` 的是独立副本。这里改名不会自动改那些副本，需要重新复制。

## 命名

- 目录名等于 `SKILL.md` 里的 `name`，kebab-case，不带 `-skill` 后缀。
- 动作类用动宾：`write-docs`、`select-ios-build-device`、`implement-minimally`。
- 同一工具的一组技能把工具名放前面：`jenkins-build-*`、`iphone-use*`、`xcode-mcp*`。
- 同一件事的不同合同，用名字里的差别分开，不共用一个名字。

下面这些名字是外部程序的查找键，目录名保持不动：

| 名字 | 原因 |
|------|------|
| `orca-cli`、`computer-use`、`orchestration` | Orca 用 `orca skills get <name>` 取说明 |
| `review` | gstack 的 `/review`，并读取 `.claude/skills/review/` 下的清单 |
| `critique`、`delight`、`normalize`、`optimize`、`frontend-design`、`teach-impeccable` | 设计套件互相用这些短命令调用 |
| `skill-creator`、`skill-installer` | 上游技能包的发行名 |
| `caveman`、`tdd`、`grill-me`、`idea-inbox` | 用户直接输入的命令或口头触发词 |

## 同名容易混的时候用哪个

**提交**

| 技能 | 作用 |
|------|------|
| `git-commit` | 分析已暂存变更，生成 `<type>(<scope>): 中文描述` 并提交。命令 `/git-commit`。 |
| `git-commit-lint` | 读取本仓库 commitlint（type、scope、长度），生成合规的英文提交信息后直接提交。命令 `/git-commit-lint`。 |
| `commit-workflow` | 按 Conventional Commits 写多行说明（标题、要点、Co-Authored-By），只暂存这次相关的文件。 |

**审查**

| 技能 | 作用 |
|------|------|
| `review-uncommitted` | 只读审查工作区里还没提交的改动（已暂存、未暂存、未跟踪），按严重程度给出问题和改法。 |
| `review-swarm` | 对当前 diff 或指定文件开四个只读子代理，找行为回归、安全或隐私、性能、契约和测试缺口。不改文件。 |
| `review` | 合入前对照 base 分支做结构性审查（SQL、LLM 输出信任边界、条件副作用等）。机械问题直接改，其余先问。命令 `/review`。 |

**架构**

| 技能 | 作用 |
|------|------|
| `harlan-architecture` | Harlan 做模块、SDK、Bridge、迁移、拆分时的总入口。 |
| `harlan-architecture-philosophy` | 只有设计偏好、决策方式和输出格式。 |
| `harlan-rn-architecture` | RN 容器：协议优于继承、不写兼容层、一个类型一件事。 |
| `design-layered-architecture` | 逻辑漏到错误的层、UI 里写了业务规则时，把数据源、转换、状态、扩展点和渲染拆开。 |
| `improve-codebase-architecture` | 扫代码库里值得加深的结构点，生成 HTML 报告，再逐项追问。 |
| `react-native-architecture` | 通用的生产级 React Native：Expo、导航、原生模块、离线同步。 |
| `vapp-architecture` | 解释 VApp Native Bridge 怎么跑：TurboModule、NotificationCenter、按协议找服务。 |
| `vapp-method-generator` | 新增或修改一个九号 iOS VApp 方法，并接到 NBVAppManager / NBUnifiedAPIRegistry。 |

**界面**

| 技能 | 作用 |
|------|------|
| `frontend-design` | 写有辨识度的生产级前端界面。项目还没有设计上下文时，先走 `teach-impeccable`。 |
| `teach-impeccable` | 一次性收集项目的设计上下文，写进 AI 配置，供后面的设计技能使用。 |
| `critique` | 从 UX 看层级、信息架构和认知负担，打分并给出可执行的修改。 |
| `delight` | 在不挡住主任务的前提下加个性、动效和微交互。 |
| `normalize` | 把界面拉回现有设计系统：间距、token、组件用法。 |
| `optimize` | 界面性能：加载、渲染、动画、图片和包体积。 |
| `web-design-engineer` | 用 HTML/CSS/JS/React 做落地页、仪表盘、可点击原型、幻灯片和动画演示。 |

**打包和真机**

| 技能 | 作用 |
|------|------|
| `jenkins-build-assistant` | 调 Jenkins：触发 iOS 企业签测试包和鸿蒙 AGC 邀请测试包；查询 iOS / 鸿蒙 / Android 的状态、日志、失败原因和产物。Android 只查询，不触发。 |
| `jenkins-build-setup` | 引导把 `jenkins-build-assistant` 装进豆包工作客户端，并说明三平台怎么用。本技能不调用 Jenkins。 |
| `build-iphone-apps` | 不用 Xcode 图形界面，用命令行完成 Swift / SwiftUI / UIKit App 的搭建、调试、测试和发布。 |
| `xcode-mcp` | 通过 Xcode 的 mcpbridge 列窗口、打开文件、编译，或按 Xcode 的配置启动代理。 |
| `xcode-mcp-build` | 只走编译这条路：选设备（优先已连接真机，否则 Any iOS Device arm64）→ Build → 读构建日志。 |
| `select-ios-build-device` | `xcodebuild` 的目的地：优先设备 `00008150-001A69800138401C`，没有则用一台 iPhone 17 模拟器。 |
| `iphone-use` | 用 PUA 操作一台真实 iPhone：导航、点击、输入、滚动、采集列表。 |
| `iphone-use-setup` | 在这台 iPhone 上安装、签名并启动 PUA；处理 USB、Xcode 和签名过期。 |

**Orca 和会话**

| 技能 | 作用 |
|------|------|
| `orca-cli` | 操作 Orca 管的 worktree、终端、仓库、自动化和内嵌浏览器。把整段工作交给另一个 agent 时用它。 |
| `orchestration` | 监督多个 Orca worker：线程消息、阻塞问答、任务分发、任务 DAG 和决策门。 |
| `computer-use` | 操作一个看得见的本机窗口：无障碍树、点击、输入、菜单和截图。命令行、文件或 HTTP 能完成时不用它。 |
| `session-handoff` | 会话结束时把进度写进 `HANDOFF.md`；新会话读这份笔记接着做。 |

## 全部技能

### 九号工作流

| 技能 | 作用 |
|------|------|
| `git-commit` | 中文 Conventional Commits，分析变更后直接提交。 |
| `review-uncommitted` | 只读审查工作区未提交改动。 |
| `review-swarm` | 四个只读子代理并行审查 diff。 |
| `jenkins-build-assistant` | 触发和查询 Jenkins 测试包。 |
| `jenkins-build-setup` | 安装并讲解 Jenkins 打包技能，自己不打包。 |
| `migrate-github-pod` | 把 GitHub 上的 CocoaPods 库迁到 git.ninebot.com，并用 ninebot-cli 发到 NBSpecs；私仓已有时同步上游新版本。 |
| `xcode-mcp-build` | 用 Xcode mcpbridge 编译 iOS 工程并看日志。 |
| `iphone-use` | 操作真实 iPhone。 |
| `iphone-use-setup` | 把 iPhone 上的 PUA 服务装好并拉到 READY。 |
| `skill-hub-contributor` | 把本地现成技能入库到 app-docs 的 Skill Hub：更新文档、ZIP 和 registry，先做本地提交，确认后才 push。 |

### 工程实践

| 技能 | 作用 |
|------|------|
| `tdd` | 先写失败测试，再写实现，再重构。 |
| `implement-minimally` | 功能只覆盖当前真实合同；跑通后删掉没用到的分支、包装和 API。完工前用它自查。 |
| `review` | 合入前的 PR 结构性审查，并修机械问题。 |
| `grill-me` | 用连续追问把一个计划或设计方案问清楚。 |
| `grill-with-docs` | 同样的追问，同时把结论写成 ADR 和术语表。 |
| `improve-codebase-architecture` | 找架构上值得加深的点，出 HTML 报告再逐项追问。 |
| `build-iphone-apps` | 命令行构建原生 iPhone App 的全流程。 |
| `react-native-architecture` | 生产级 React Native 的结构和跨平台做法。 |
| `write-docs` | 用 Metabase 那种对话式、面向使用者的语气写 Markdown / MDX。 |
| `caveman` | 压缩说法：去掉虚词和客套，技术内容保持原样。说 “caveman mode” 或 `/caveman` 打开，说 “normal mode” 关闭。 |
| `skill-creator` | 写一个新技能或改一个已有技能时的结构、描述和触发条件。 |
| `skill-installer` | 从精选列表或 GitHub（含私仓）把技能装进 `$CODEX_HOME/skills`。 |
| `computer-use` | 操控可见的本机窗口。 |
| `orca-cli` | 操作 Orca 的 worktree、终端和内嵌浏览器。 |
| `orchestration` | 编排多个 Orca worker。 |

### 设计

| 技能 | 作用 |
|------|------|
| `teach-impeccable` | 把项目设计上下文写入 AI 配置。跑一次。 |
| `frontend-design` | 做生产级、不像通用 AI 模板的前端界面。 |
| `critique` | UX 评审：层级、信息架构、认知负担，带分数和修改建议。 |
| `delight` | 给界面加记得住的动效和个性。 |
| `normalize` | 把漂掉的界面收回到设计系统。 |
| `optimize` | 诊断并修界面性能。 |

### `skills/` 插件集

marketplace 已注册：

| 技能 | 作用 |
|------|------|
| `harlan-architecture` | Harlan 的全栈架构总入口。 |
| `harlan-architecture-philosophy` | Harlan 的架构偏好和决策方式。 |
| `harlan-rn-architecture` | Harlan 的 RN 容器架构偏好。 |
| `vapp-architecture` | VApp Native Bridge 运行时说明。 |
| `web-design-engineer` | 高质量视觉 Web 产物（页面、原型、幻灯片、可视化）。 |
| `select-ios-build-device` | 为 `xcodebuild` 选定真机或 iPhone 17 模拟器。 |
| `karpathy-guidelines` | 写代码时少做复杂化：先说假设，改动保持手术式，完成标准要能验证。 |
| `audit-skills` | 检查技能是否重复、frontmatter 是否合法、`library.json` 是否和磁盘一致。命令 `/audit-skills`。 |
| `xcode-mcp` | 通过 mcpbridge 和 Xcode 交互。 |
| `idea-inbox` | 任务进行中把临时想法记到 `docs/ideas/inbox.md`；`/idea` 时批量处理并归档。 |
| `commit-workflow` | Conventional Commits 的多行提交格式和提交前检查。 |
| `git-commit-lint` | 按项目 commitlint 生成提交信息并提交。 |

未注册，只在本仓库使用：

| 技能 | 作用 |
|------|------|
| `vapp-method-generator` | 生成或更新九号 iOS VApp 原生方法，并完成注册接线。 |
| `design-layered-architecture` | 按层设计或重构：数据从哪来、怎么变换、谁编排、UI 只负责渲染。 |
| `session-handoff` | 写或读 `HANDOFF.md`，让下一个没有上下文的会话能接着做。 |
| `release-version` | 发 npm / SDK 包：对版本、跑验证、发布、核对 dist-tag，再只提交发版相关文件。 |
| `write-ai-doc` | 为有长期决策价值的功能或修复写 `docs-ai/` 编号记录：实现前 `000-plan.md`，实现后 `001-action.md`。 |

## 改名对照

| 旧名 | 新名 |
|------|------|
| `docs-write` | `write-docs` |
| `skills/git-commit` | `skills/git-commit-lint` |
| `skills/idea-inbox-skill` | `skills/idea-inbox` |
| `skills/vapp-skill` | `skills/vapp-architecture` |
| `skills/commit`（仅 frontmatter） | `commit-workflow` |
| `jenkins-install-guide` | `jenkins-build-setup` |
| `minimal-implementation` | `implement-minimally` |
| `skills/handoff` | `skills/session-handoff` |
| `skills/ios-build-device-selection` | `skills/select-ios-build-device` |
| `skills/engineering-layered-design` | `skills/design-layered-architecture` |
| `skills/skill-health` | `skills/audit-skills` |

顶层曾经有一份和 `skills/xcode-mcp` 重复的 `xcode-mcp`，以及 `skills/review-uncommitted` 的 6 行占位，都已删掉。完整版分别留在 `skills/xcode-mcp` 和顶层 `review-uncommitted`。

## 安装

- Claude Code marketplace：把本仓库加为插件源，加载 `marketplace.json` 里的 12 个技能。
- 手动：把技能目录复制到 `~/.agents/skills/<name>/`、项目 `.agents/skills/<name>/` 或 `$CODEX_HOME/skills/<name>/`。
