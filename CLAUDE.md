# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A personal collection of Claude Code SKILL.md files — structured system prompts for AI coding agents. Skills are stored as directories at the repo root, each containing a `SKILL.md` file.

## Skill Registry

Skills are registered via `.skill-switch/library.json`, a v2-format metadata registry that:
- Tracks all installed skills with `scope: global` (available across all Claude Code sessions)
- Embeds full SKILL.md content as a `content` field (not file references)
- Must stay synced with actual SKILL.md files in each skill directory

## Key Skills

- `harlan-architecture` — Unified full-stack architecture skill (replaces `harlan-architecture-philosophy` and `harlan-rn-architecture`)
- `vapp-skill` — VApp Native Bridge runtime documentation (ObjC/Swift RN bridge)
- `web-design-engineer` — Web design quality standards with CDN-based React patterns
- `ios-build-device-selection` — Xcode build device preferences
- `karpathy-guidelines` — Behavioral guidelines for LLM coding (imported, MIT license)

## Gotchas

- **Hardcoded paths**: `xcode_mcp_wrapper.py` hardcodes Xcode path (`/Applications/Xcode-26.5.0-Release.Candidate.app/...`) — update on Xcode version changes
- **Device UUIDs**: `ios-build-device-selection` contains user-specific hardware IDs
- **Skill redundancy**: Older Harlan architecture skills are still registered in `library.json` despite being superseded by `harlan-architecture`
- **No root README.md**: Repository lacks top-level documentation explaining usage

## Repo Etiquette

- When adding new skills: create directory with `SKILL.md`, add entry to `library.json`
- When deprecating skills: remove from `library.json` or mark deprecated
- Skill frontmatter: `name`, `description` are required; `scope: global` for all current skills