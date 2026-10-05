# Repository Rules

## Files That Must Stay In Sync

一次有效的 skill 入库，至少会涉及以下 5 类路径：

1. `skills_hub/<slug>/`
2. `static/files/skills/<slug>.zip`
3. `docs/skills/<slug>.md`
4. `src/data/skills.ts`
5. `static/files/skills/registry.json`

## Guardrails

- 只支持 `新增 skill` 和 `常规更新`
- 禁止 `slug` 重命名、下线和批量迁移
- 默认执行前，本地仓库必须是干净工作区
- 只有在上一轮失败后继续同一条分支时，才允许 `--resume`
- push 前必须得到用户明确确认；默认只停在本地 branch / commit
- 任何校验失败都必须停止，不能在失败后继续 push
- push 失败或 draft MR 创建失败时，保留本地分支和提交，提示用户人工接管

## Git Conventions

- 工作分支：`skill-contrib/<slug>-<timestamp>`
- 新增 commit：`feat(skill-hub): add <slug>`
- 更新 commit：`chore(skill-hub): update <slug>`
- draft MR 目标分支固定为 `main`

## Validation

脚本执行完成前，必须依次通过：

```bash
node scripts/validate-skills.mjs
npm run build:dev
```

如果仓库是 fresh clone 且缺少依赖，脚本会先执行 `npm install`。

## Failure Handling

- `sourceDir` / `manifest` 不合法：直接停止，先改输入再重跑
- `validate-skills` 或 `build:dev` 失败：
  - 如果你准备修改 `sourceDir` 或 manifest，修好后用 `--resume` 继续
  - 如果你准备直接改 clone 出来的仓库，改完后请用 git 手工继续，不要再跑脚本覆盖它
- GitLab push 权限不足：
  - 这属于权限问题，不代表 skill 内容有问题
  - 本地 branch 和 commit 会保留
  - 让用户找李海龙添加 `app-docs` 的 GitLab SSH push 权限
  - 修好 SSH 权限后可用 `--resume --push` 重试
