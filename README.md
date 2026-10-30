# My-Skills

个人 AI 编码代理技能集合。每个技能是一个目录,内含 `SKILL.md`(结构化系统提示词),供 Claude Code / Codex / ZCode 等代理加载使用。

## 仓库结构

```
My-Skills/
├── <skill>/            # 顶层:日常工作的技能(九号工作流 + 通用工程 + 设计套件)
├── skills/             # 插件技能集,经 .claude-plugin/marketplace.json 注册(cc-switch 格式)
├── CLAUDE.md           # 仓库协作约定与命名规范
└── README.md           # 本文件:技能清单
```

> 注意:宿主已安装的技能(`~/.agents/skills/`、项目 `.agents/skills/` 下)是**独立副本**而非软链,本仓库改名不会自动同步到已安装位置。

## 技能清单

### 一、九号工作流(自研)

| 技能 | 作用 |
|------|------|
| `git-commit` | 智能分析工作区变更,自动生成符合规范的中文提交信息并执行提交 |
| `review-uncommitted` | 审查工作区全部未提交改动(暂存+未暂存+未跟踪),按严重程度输出问题清单与修复建议 |
| `review-swarm` | 并行只读多代理评审当前 git diff 或指定文件范围:行为回归、安全/隐私、性能可靠性、契约与测试覆盖 |
| `jenkins-build-assistant` | Jenkins 打包与构建查询:iOS 企业签测试包、鸿蒙 AGC 邀请测试包触发;三平台构建状态/日志/失败原因/产物/蒲公英链接查询 |
| `jenkins-install-guide` | jenkins-build-assistant 的安装与使用向导(引导安装技能包,不直接调 Jenkins) |
| `migrate-github-pod` | 把 GitHub 开源 CocoaPods 库私有化到 git.ninebot.com 并用 ninebot-cli 发布到 NBSpecs,或在私仓已有时同步上游新版本 |
| `xcode-mcp-build` | 通过 Xcode 官方 MCP bridge(xcrun mcpbridge)编译 iOS 项目并取构建日志排障 |
| `iphone-use` | 通过 PUA(Phone Use Agent)MCP 工具操作真实 iPhone:导航、点击、输入、采集、认证接管 |
| `iphone-use-setup` | 配置 PUA:在真机上安装、签名、启动手机端执行服务,诊断 USB/Xcode 连接 |
| `skill-hub-contributor` | 向 app-docs 仓库的 Skill Hub 新增/更新技能:收集 manifest、同步仓库、更新 registry、建提交(确认后才 push) |

### 二、通用工程实践

| 技能 | 作用 |
|------|------|
| `tdd` | 测试驱动开发:红-绿-重构流程,先写测试再实现 |
| `minimal-implementation` | 最小实现原则:新功能/API/兼容层/解析器完工前的自查标准 |
| `review` | 合入前的 PR 评审:对 base 分支 diff 做 SQL 安全、LLM 信任边界、条件副作用等结构性检查 |
| `grill-me` | 拷问式访谈,打磨计划或设计方案 |
| `grill-with-docs` | 同 grill-me,并随进程产出 ADR 与术语表 |
| `improve-codebase-architecture` | 扫描代码库寻找架构深化机会,生成可视化 HTML 报告并逐项拷问 |
| `build-iphone-apps` | 纯 CLI(不用 Xcode GUI)构建专业原生 iPhone App:Swift/SwiftUI/UIKit 全生命周期 |
| `react-native-architecture` | 生产级 RN 应用架构:Expo、导航、原生模块、离线同步、跨平台模式 |
| `write-docs` | 按 Metabase 对话式、清晰、用户导向风格撰写文档(markdown/MDX) |
| `caveman` | 超压缩交流模式:去虚词寒暄省约 75% token,保留全部技术准确性 |
| `skill-creator` | 创建/改进技能的指南(结构、描述、触发词设计) |
| `skill-installer` | 从精选列表或 GitHub 仓库(含私仓)安装 Codex 技能到 $CODEX_HOME/skills |
| `computer-use` | 通过 `orca computer` 操控本地 App 窗口 GUI:无障碍树、点击、输入、菜单、截图 |
| `orca-cli` | 通过 `orca` CLI 操作 Orca 管理的 worktree、目录上下文、终端、仓库、自动化、内嵌浏览器 |
| `orchestration` | 编排 Orca 受管 worker:线程消息、阻塞问答、任务分发、任务 DAG、决策门 |

### 三、设计 / UX 套件(Anthropic impeccable 系列)

| 技能 | 作用 |
|------|------|
| `critique` | UX 视角设计评审:视觉层级、信息架构、认知负荷,量化打分+画像测试+可执行反馈 |
| `delight` | 为界面添加愉悦感与个性:打磨、动效、微交互,让功能变得 memorable |
| `normalize` | 审计并校正 UI 使其回归设计系统:规范、间距、token、模式一致性 |
| `optimize` | UI 性能诊断与修复:加载、渲染、动画、图片、包体积 |
| `teach-impeccable` | 一次性初始化:采集项目设计上下文写入 AI 配置,建立持久设计准则 |
| `frontend-design` | 生成高设计感、避免"AI 千篇一律"外观的生产级前端界面 |

### 四、`skills/` 插件技能集

**已注册 marketplace.json(12 个):**

| 技能 | 作用 |
|------|------|
| `harlan-architecture` | Harlan 全栈架构设计:通用架构哲学 + iOS/RN 跨平台分层 + SDK 设计偏好三位一体 |
| `harlan-architecture-philosophy` | Harlan 架构设计哲学:设计偏好、决策风格与输出格式 |
| `harlan-rn-architecture` | Harlan 的 RN 容器架构偏好:协议优于继承、拒绝兼容性代码、单一职责 |
| `vapp-architecture` | VApp Native Bridge Runtime 架构文档:TuroModule、NotificationCenter 分发、Protocol-oriented 服务查找 |
| `web-design-engineer` | 用 HTML/CSS/JS/React 构建高质量视觉 Web 产物:落地页、仪表盘、交互原型、动画演示 |
| `ios-build-device-selection` | xcodebuild 设备选择偏好(优先指定真机,回退可用模拟器) |
| `karpathy-guidelines` | LLM 编码行为守则:避免过度复杂化、外科手术式改动、显式假设、可验证完成标准 |
| `skill-health` | 技能集健康审计:冗余检测、frontmatter 校验、library.json 同步检查 |
| `xcode-mcp` | 通过 mcpbridge 与 Xcode 交互:列窗口、开文件、编译、以 Xcode 配置启动代理 |
| `idea-inbox` | 想法收件箱:批量处理 docs/ideas/inbox.md 暂存想法并推进执行 |
| `commit-workflow` | 规范化 Git 提交流程与完整提交摘要 |
| `git-commit-lint` | 读取项目 commitlint 规范生成合规提交信息,自动处理 pre-commit 钩子失败 |

**未注册的工作副本(5 个):**

| 技能 | 作用 |
|------|------|
| `vapp-method-generator` | 生成/更新九号 iOS VApp 原生方法与服务(Swift VApp API、NBVAppManager/NBUnifiedAPIRegistry 注册接线) |
| `engineering-layered-design` | 工程分层设计:逻辑漏层、UI 含业务规则等结构问题的设计与重构指导 |
| `handoff` | 会话交接:长会话结束写交接文档,新会话读取恢复上下文 |
| `release-version` | 安全发版与提交:npm/SDK 包发版、版本号、tag/dist-tag 管理 |
| `write-ai-doc` | 为重要特性与关键决策修复创建维护 docs-ai/ 编号记录(000-plan / 001-action) |

## 命名规范(2026-10-30 起)

1. 目录名必须与 SKILL.md frontmatter 的 `name` 一致,kebab-case
2. 不带冗余 `-skill` 后缀
3. 同用途技能跨层不重名,按特色消歧(如 `git-commit` 中文规范版在顶层,`git-commit-lint` commitlint 版在 skills/)
4. 动宾语序(`write-docs` 而非 `docs-write`)

### 本次改名对照

| 旧名 | 新名 | 原因 |
|------|------|------|
| `docs-write` | `write-docs` | 动宾语序 |
| `skills/git-commit` | `skills/git-commit-lint` | 与顶层中文版 git-commit 重名,按 commitlint 特色消歧 |
| `skills/idea-inbox-skill` | `skills/idea-inbox` | 去冗余后缀(name 原为 `idea`,一并统一) |
| `skills/vapp-skill` | `skills/vapp-architecture` | 去冗余后缀,表意其架构文档定位 |
| `xcode-mcp`(顶层) | 删除 | 与 `skills/xcode-mcp` 完全冗余,wrapper 保留新版同步到 skills/ |
| `skills/review-uncommitted` | 删除 | 6 行占位版,顶层 50 行完整版已覆盖 |
| `skills/commit-workflow`(name) | `commit` → `commit-workflow` | name 与目录名统一 |

## 使用方式

- **Claude Code / marketplace**:`.claude-plugin/marketplace.json` 注册的 `skills/` 插件集,可直接作为插件源添加
- **手动安装**:把技能目录复制(或软链)到目标代理的技能目录,如 `~/.agents/skills/<name>/`、项目 `.agents/skills/<name>/`、`$CODEX_HOME/skills/<name>/`
