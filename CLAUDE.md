# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A personal collection of Claude Code SKILL.md files — structured system prompts for AI coding agents. Skills are stored in the `skills/` directory, each containing a `SKILL.md` file.

## Skill Registry (cc-switch Marketplace Format)

Skills are registered via `.claude-plugin/marketplace.json`, the official cc-switch/marketplace format:
- Defines plugins with skill paths (not embedded content)
- Skills live in `skills/` subdirectory
- Compatible with SkillSwitch and Claude Code marketplace

**Legacy**: `.skill-switch/library.json` (v2 format) still exists for backward compatibility, but marketplace.json is the primary registry.

## Key Skills (13 registered)

| Skill | Description |
|-------|-------------|
| `harlan-architecture` | Unified full-stack architecture skill (supersedes older variants) |
| `harlan-architecture-philosophy` | Architecture philosophy and design principles |
| `harlan-rn-architecture` | RN/iOS bridge patterns |
| `harlan-rn-architecture-2` | RN architecture variant |
| `vapp-skill` | VApp Native Bridge runtime documentation (ObjC/Swift RN bridge) |
| `web-design-engineer` | Web design quality standards with CDN-based React patterns |
| `ios-build-device-selection` | Xcode build device preferences |
| `karpathy-guidelines` | Behavioral guidelines for LLM coding (MIT license) |
| `skill-health` | Skill collection audit: redundancy, frontmatter, sync check |
| `xcode-mcp` | Xcode mcpbridge interaction and run-agent configuration |
| `idea-inbox-skill` | Idea inbox management workflow |
| `commit-workflow` | Git commit workflow with conventional format |
| `git-commit` | Smart git commit automation |

## Gotchas

- **Hardcoded paths**: `xcode-mcp/scripts/xcode_mcp_wrapper.py` hardcodes Xcode path — update on Xcode version changes
- **Device UUIDs**: `ios-build-device-selection` contains user-specific hardware IDs

## Repo Etiquette

- When adding new skills: create directory in `skills/` with `SKILL.md`, add path to `marketplace.json`
- When deprecating skills: remove path from `marketplace.json`
- Skill frontmatter: `name`, `description` are required