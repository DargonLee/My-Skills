# Manifest Schema

`contribute-skill.mjs` 只接受 JSON manifest。推荐先用 `init-manifest` 生成模板，再按当前任务填充。

这个 skill 的输入是一份“你本机已经写好的 skill 目录 + 一份结构化 manifest”，不是一句自然语言需求。

## Common Fields

```json
{
  "mode": "add",
  "repoPath": "/absolute/or/relative/path/to/app-docs",
  "slug": "skill-hub-contributor",
  "sourceDir": "/absolute/or/relative/path/to/source",
  "name": "Skill Hub Contributor",
  "description": "卡片短描述",
  "summary": "卡片补充说明",
  "tags": ["contribution", "automation"],
  "platforms": ["Docusaurus", "GitLab"],
  "installTargets": ["copilot", "claude", "codex"],
  "version": "0.1.0",
  "owner": "平台文档团队",
  "updatedAt": "2026-03-31",
  "repoUrl": "https://gitlab.ninebot.com/ninebotapp/platform/app-docs",
  "featured": false,
  "docSections": [
    {
      "title": "技能简介",
      "markdown": "说明这个 skill 解决什么问题。"
    }
  ],
  "updateKinds": ["metadata", "docs", "source", "zip"]
}
```

## Field Notes

- `mode`
  - `add`: 新增 skill
  - `update`: 更新已有 skill
- `repoPath`
  - 可选
  - 未填写时默认落到 `~/.skill-hub-contributor/app-docs`
- `slug`
  - 必须是 `kebab-case`
  - `update` 时不能改
- `sourceDir`
  - `add` 必填
  - `update` 时只要涉及 `source` 或 `zip` 就必填
  - 目录中必须包含 `SKILL.md`
  - 目录应该是贡献者本机已经写好的 skill 目录，脚本会把它复制进 `app-docs/skills_hub/<slug>/`
- `installTargets`
  - 可选
  - 未填写时默认 `["copilot", "claude", "codex"]`
- `docSections`
  - `add` 必填
  - `update` 且包含 `docs` 时必填
  - `markdown` 字段会被原样写入详情页
- `updateKinds`
  - 仅 `update` 使用
  - 允许值：`metadata`、`docs`、`source`、`zip`
  - 当前仓库约束下，只要出现 `source` 或 `zip`，脚本都会同时同步源码目录和 ZIP 包

## Add Example

```json
{
  "mode": "add",
  "slug": "my-new-skill",
  "sourceDir": "/Users/example/Desktop/my-new-skill",
  "name": "My New Skill",
  "description": "自动处理 xxx 的 skill。",
  "summary": "面向具备仓库权限的同学，自动完成 xxx。",
  "tags": ["tooling", "automation"],
  "platforms": ["Docusaurus", "GitLab"],
  "version": "0.1.0",
  "owner": "张三",
  "docSections": [
    {
      "title": "技能简介",
      "markdown": "说明新增 skill 的用途。"
    },
    {
      "title": "快速开始",
      "markdown": "```bash\nexample command\n```"
    }
  ]
}
```

## Update Example

```json
{
  "mode": "update",
  "repoPath": "/Users/example/Work/app-docs",
  "slug": "my-existing-skill",
  "sourceDir": "/Users/example/Desktop/my-existing-skill",
  "summary": "更新后的补充说明。",
  "updatedAt": "2026-03-31",
  "docSections": [
    {
      "title": "推荐使用流程",
      "markdown": "- 第一步\n- 第二步"
    }
  ],
  "updateKinds": ["metadata", "docs", "source", "zip"]
}
```

## Apply Modes

- 默认执行：先生成本地 branch / commit，不自动 push：

```bash
node scripts/contribute-skill.mjs apply --manifest /tmp/skill-hub-contributor.json
```

- 用户确认后再 push 并创建 draft MR：

```bash
node scripts/contribute-skill.mjs apply --manifest /tmp/skill-hub-contributor.json --resume --push
```

- 只做本地检查，不 commit / push：

```bash
node scripts/contribute-skill.mjs apply --manifest /tmp/skill-hub-contributor.json --check-only
```

- 上一轮失败后继续在原分支重跑：

```bash
node scripts/contribute-skill.mjs apply --manifest /tmp/skill-hub-contributor.json --resume
```
