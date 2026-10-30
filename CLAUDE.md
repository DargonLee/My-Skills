# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A personal collection of AI coding agent skills — each is a directory with a `SKILL.md` (structured system prompt). Two layers:

- **Top-level directories**: daily-working skills (Ninebot workflow skills + community/engineering/design skills). See root `README.md` for the full catalog.
- **`skills/` subdirectory**: the plugin skill set registered via `.claude-plugin/marketplace.json` (cc-switch/marketplace format). Compatible with SkillSwitch and Claude Code marketplace.

**Legacy**: `.skill-switch/library.json` (v2 format) still exists for backward compatibility, but marketplace.json is the primary registry.

## Key Skills (12 registered in marketplace.json)

| Skill | Description |
|-------|-------------|
| `harlan-architecture` | Unified full-stack architecture skill (supersedes older variants) |
| `harlan-architecture-philosophy` | Architecture philosophy and design principles |
| `harlan-rn-architecture` | RN/iOS bridge patterns |
| `vapp-architecture` | VApp Native Bridge runtime documentation (ObjC/Swift RN bridge) |
| `web-design-engineer` | Web design quality standards with CDN-based React patterns |
| `ios-build-device-selection` | Xcode build device preferences |
| `karpathy-guidelines` | Behavioral guidelines for LLM coding (MIT license) |
| `skill-health` | Skill collection audit: redundancy, frontmatter, sync check |
| `xcode-mcp` | Xcode mcpbridge interaction and run-agent configuration |
| `idea-inbox` | Idea inbox management workflow |
| `commit-workflow` | Git commit workflow with conventional format |
| `git-commit-lint` | Smart git commit automation reading project commitlint rules |

`skills/` also hosts unregistered working copies (`vapp-method-generator`, `engineering-layered-design`, `handoff`, `release-version`, `write-ai-doc`).

## Naming Conventions (since 2026-10-30)

- Directory name MUST equal the frontmatter `name`, kebab-case.
- No redundant `-skill` suffix (`vapp-skill` → `vapp-architecture`, `idea-inbox-skill` → `idea-inbox`).
- Disambiguate same-purpose skills instead of duplicating names across layers (`skills/git-commit` → `skills/git-commit-lint`; the Chinese-flavored `git-commit` stays at top level).
- Verb-object order (`docs-write` → `write-docs`).

## Gotchas

- **Hardcoded paths**: `skills/xcode-mcp/scripts/xcode_mcp_wrapper.py` hardcodes Xcode path — update on Xcode version changes
- **Device UUIDs**: `ios-build-device-selection` contains user-specific hardware IDs
- Installed copies under `~/.agents/skills/` or project `.agents/skills/` are independent copies (not symlinks) — renaming here does NOT auto-update them

## Repo Etiquette

- When adding new skills: create directory (top level, or `skills/` for marketplace plugins) with `SKILL.md`; add path to `marketplace.json` if it belongs to the plugin set
- When deprecating skills: remove path from `marketplace.json`
- Skill frontmatter: `name`, `description` are required; `name` must match the directory name