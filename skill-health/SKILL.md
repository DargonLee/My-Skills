---
name: skill-health
description: Audit the skill collection for redundancy, validate frontmatter, and ensure library.json stays synced with actual SKILL.md files.
---

# Skill Health Audit

Audit the Claude Code skill collection for quality, consistency, and synchronization.

## When to Use

- Before committing changes to the skill collection
- After adding or modifying skills
- To detect deprecated or redundant skills
- To ensure `library.json` reflects actual skill files

## Audit Checks

### 1. Redundancy Detection

Scan for skills that:
- Have similar names or overlapping purposes
- Are explicitly marked as "replaces" or "supersedes" another skill
- Are deprecated but still registered in `library.json`

Report findings grouped by:
- **Superseded**: Skills that have been replaced by newer versions
- **Duplicate functionality**: Skills with overlapping purposes
- **Deprecated**: Skills marked deprecated but still active

### 2. Frontmatter Validation

For each SKILL.md, verify frontmatter contains:
- `name`: Required, matches directory name
- `description`: Required, one-line summary
- `scope`: Typically `global` for this collection

Flag missing or malformed frontmatter.

### 3. library.json Synchronization

Compare `library.json` entries against actual skill directories:
- **Missing registration**: Skills with SKILL.md but no `library.json` entry
- **Orphaned entries**: `library.json` entries for skills that don't exist
- **Content mismatch**: `library.json` `content` field differs from actual SKILL.md

### 4. Hardcoded Paths Detection

Flag skills containing:
- Absolute file paths (`/Applications/...`, `/Users/...`)
- Device UUIDs
- Machine-specific identifiers

Suggest templating or documenting per-user configuration.

## Output Format

```
## Skill Health Report

### Redundancy
- [SKILL_NAME]: superseded by [NEW_SKILL] — recommend removal
- [SKILL_A] + [SKILL_B]: overlapping functionality — consider merging

### Frontmatter Issues
- [SKILL_NAME]: missing `description` field

### Sync Issues
- [SKILL_NAME]: registered but directory missing
- [SKILL_NAME]: content mismatch (library.json outdated)

### Hardcoded Paths
- [SKILL_NAME]: contains `/Applications/Xcode-...` path

### Summary
- Total skills: N
- Issues found: N
- Recommended actions: [list]
```

## Remediation

After audit, offer to:
- Remove superseded skills from `library.json`
- Update `library.json` to sync with actual files
- Add missing frontmatter fields
- Document hardcoded paths with placeholders

## Usage

Invoke with `/skill-health` to run the audit.