---
name: skill-hub-contributor
description: "Use when a teammate needs to add a new Skill Hub skill or update an existing one in the app-docs repository. 收集结构化 manifest 后，自动 clone 或同步仓库、更新 skills_hub/docs/ZIP/registry、执行校验、创建本地提交；只有在用户明确确认后才 push 并创建 draft Merge Request。"
---

# Skill Hub Contributor

## Use When

- 贡献者已经在本机某个目录写好了 skill，想把它发布到 `ninebotapp/platform/app-docs`
- 需要新增一个 skill，或更新已有 skill 的展示信息、详情页、源码目录或 ZIP 包
- 贡献者准备先把结果落到本地 branch / commit，再决定是否自己 push
- 贡献者暂时没有 push 权限，但希望先做本地检查；之后找李海龙添加权限再继续 push

## Do Not Use When

- 需要重命名 `slug`
- 需要下线 skill 或删除历史内容
- 需要批量迁移多个 skill
- 希望 agent 从一句自然语言直接生成完整 skill 内容
- 还没有准备好待提交的本地 skill 源目录或更新内容

## Workflow

1. 先确认贡献者已经在本地准备好了 skill 目录，并拿到 `sourceDir` 的绝对路径。这个 skill 不负责生成 skill 内容，只负责把本地现成目录入库。
2. 确认当前请求只属于 `add` 或 `update`，并收集 `slug`、`sourceDir`、卡片元数据和详情页章节内容。
3. 读取 [references/manifest.md](references/manifest.md) 确认 manifest 字段，再读取 [references/repo-rules.md](references/repo-rules.md) 确认仓库规则和边界。
4. 先问清贡献者当前目标：
   - 先生成本地 branch / commit：默认 `apply`
   - 只做本地校验：`apply --check-only`
   - 在用户确认后 push：`apply --resume --push`
   - 接着上一次失败的分支继续：`apply --resume`
5. 用脚本生成一个 manifest 模板，再按当前请求填完整：

   ```bash
   node <absolute-path-to-this-skill>/scripts/contribute-skill.mjs init-manifest --mode add --output /tmp/skill-hub-contributor.json
   ```

6. 检查 manifest：
   - `add` 必须提供完整卡片元数据、`sourceDir` 和 `docSections`
   - `update` 只允许常规更新，不能修改 `slug`
   - 如果涉及 `source` 或 `zip`，`sourceDir` 必须存在且包含 `SKILL.md`
7. 执行脚本。默认模式会 clone 或同步 `app-docs` 到本地，再把 `sourceDir` 复制进仓库并自动补齐 docs、ZIP、列表数据和 registry：

   ```bash
   node <absolute-path-to-this-skill>/scripts/contribute-skill.mjs apply --manifest /tmp/skill-hub-contributor.json
   ```

   只做本地校验时：

   ```bash
   node <absolute-path-to-this-skill>/scripts/contribute-skill.mjs apply --manifest /tmp/skill-hub-contributor.json --check-only
   ```

   失败后续跑时：

   ```bash
   node <absolute-path-to-this-skill>/scripts/contribute-skill.mjs apply --manifest /tmp/skill-hub-contributor.json --resume
   ```

8. 向用户汇报：
   - 实际使用的仓库路径
   - 当前工作分支
   - 这次是 `check-only`、本地 commit，还是已创建 draft MR
   - 如果已经产生本地 commit，必须先问用户是否要执行 push
   - 如果用户拒绝 push，就只把仓库路径和分支发给用户，然后结束本次对话
   - 如果失败，明确说明应该改 `sourceDir / manifest` 后 `--resume`，还是应该直接在 clone 出来的仓库里手工接管
   - 如果 push 权限不足，明确提示这是权限问题，不是 skill 内容问题，并让用户找李海龙添加权限

## Rules

- 默认远端仓库固定为 `git@gitlab.ninebot.com:ninebotapp/platform/app-docs.git`，默认目标分支固定为 `main`。
- 如果 `repoPath` 未提供，脚本会使用 `~/.skill-hub-contributor/app-docs` 作为默认本地 clone 路径。
- 默认执行会要求本地仓库工作区干净；只有在明确续跑上一轮失败分支时才使用 `--resume`。
- `sourceDir` 的 `SKILL.md` frontmatter 中 `name` 必须等于目标 `slug`。
- 对 `source` / `zip` 更新，脚本会按仓库规则同时同步 `skills_hub/<slug>/` 和 `static/files/skills/<slug>.zip`，不要尝试只改其一。
- push 前必须显式征求用户确认；默认行为只创建本地 branch / commit，不自动 push。
- 对没有 push 权限的贡献者，优先建议 `--check-only`，或者默认停在本地 branch / commit，然后让他找`李海龙`添加权限后继续。
