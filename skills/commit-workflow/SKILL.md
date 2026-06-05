---
name: commit
description: Git commit workflow with conventional format and comprehensive summaries
---

# Commit Workflow

## Commit Message Format

```
<type>: <description>

<body>

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
```

**Types**: feat, fix, refactor, docs, test, chore, perf, ci

## Workflow Steps

1. **Check status**: `git status` — review untracked and modified files
2. **Review changes**: `git diff` — understand what changed
3. **Check history**: `git log --oneline -5` — follow existing commit style
4. **Stage files**: `git add <files>` — add relevant files only
5. **Commit**: Use HEREDOC format for multi-line message
6. **Verify**: `git status` — confirm clean working tree

## Commit Message Guidelines

- **Title**: Short, descriptive, explains what changed (not why)
- **Body**: Bullet list of key changes, each change on one line
- **No generic statements**: Avoid "updated code", "fixed issues"
- **Be specific**: List actual files/modules affected

## Example

```bash
git add .gitignore .swiftlint.yml CLAUDE.md clawd-desk/ clawd-hook/ && \
git commit -m "$(cat <<'EOF'
feat: Swift native clawd-desk initial implementation

- macOS menu-bar accessory app (LSUIElement) with APNG animation
- clawd-hook CLI for AI agent event forwarding via HTTP
- HTTP server (port 23333-23337) with state/permission routes
- Agent abstraction layer for Claude Code + Codex CLI (P0)
- Permission bubble, session HUD, dashboard UI
- Theme system (Calico) with 9-state animation mapping
- SwiftLint configuration for code quality

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

## Pre-Commit Checklist

- [ ] No hardcoded secrets (API keys, passwords, tokens)
- [ ] No `.env` or credential files staged
- [ ] Changes are logically grouped (one feature/fix per commit)
- [ ] Commit message explains what changed