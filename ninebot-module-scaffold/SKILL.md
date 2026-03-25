---
name: ninebot-module-scaffold
description: Generate Ninebot team module scaffolds from bundled templates. Use when the user asks to create or customize iOS Pod, React Native, Android, or Harmony module templates with the team's standard structure.
---

# Ninebot Module Scaffold

Use this skill when the user wants AI to generate a team-standard module scaffold.

## Quick Start

- Bundled templates live under `assets/templates/<template-id>`.
- Run `python3 scripts/generate_template.py list` to see currently bundled templates.
- Run `python3 scripts/generate_template.py generate --template ios-pod --module-name MyModule --output /absolute/path`.
- After generation, inspect the output and only then apply business-specific changes.

## Workflow

1. Confirm the platform, module name, and output directory.
2. If the user only asks for a Pod/module scaffold and does not specify a platform, default to `ios-pod`.
3. Use the generator script instead of manually copying and replacing names.
4. If the user wants template maintenance or a new platform pack, read [references/template-extension.md](references/template-extension.md) before editing.

## Current Templates

- `ios-pod`: bundled and ready to generate.
- `rn-module`: bundled and ready to generate.

## Notes

- The generator is manifest-driven. Adding Android or Harmony usually means adding a new template folder plus `manifest.json`, not rewriting the script.
- The script supports derived variables such as `module_name_kebab`, `module_name_snake`, `module_name_lower`, and `module_name_upper`.
- Use `--var key=value` for future templates that need extra replacement variables such as package name, namespace, or business identifiers.
