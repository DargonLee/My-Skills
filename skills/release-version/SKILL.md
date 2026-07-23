---
name: release-version
description: Publish and commit package releases safely. Use when the user asks to publish a new version, beta, prerelease, npm package, SDK package, library release, bump version, tag/dist-tag a package, or release then commit code changes.
---

# Release Version

Use this workflow for package releases where a local repo must be verified, versioned, published, and committed. Prefer the repo's own scripts and release conventions over generic commands.

## Workflow

1. Inspect release context:
   - Read `AGENTS.md`, repo checklists, `package.json`, lockfiles, and existing release scripts.
   - Run `git status --short` and identify unrelated dirty files before touching anything.
   - Check registry state with the relevant package manager, for example `npm view <name> version versions dist-tags --json`.

2. Choose the version:
   - If the user specifies an exact version, use it.
   - If the user asks for "new beta" and the latest line is `X.Y.Z-beta.N`, use `X.Y.Z-beta.(N+1)`.
   - If the version scheme is unclear, ask before editing.
   - Update the minimal version files only. For npm workspaces, check whether lockfiles also record the package version.

3. Verify before publish:
   - Run focused tests that cover the changed behavior.
   - Run the repo's required build or prepare command. If `src/` builds into ignored package artifacts, still run the build so `npm pack` publishes current code.
   - Run a dry pack when available, for example `npm pack --dry-run`, and scan the package name, version, tarball contents, and file count.

4. Publish:
   - Prefer existing release scripts such as `npm run publish:public` when present.
   - Otherwise use the package manager directly, for example `npm publish --access public --tag beta` or `npm publish --access public`, matching the repo's dist-tag convention.
   - Never publish over an existing version. Re-check the registry if there is any doubt.

5. Verify after publish:
   - Run `npm view <name>@<version> version dist.tarball dist-tags --json` or the equivalent registry query.
   - Confirm the expected dist-tag. If the tag is wrong, fix it with the package manager's dist-tag command and verify again.

6. Commit:
   - Stage only release-related files and the user's intended code changes.
   - Use a concise Chinese commit message, for example `fix(动态配置): 修复 fileName 缺失导致埋点匹配崩溃`.
   - After commit, run `git status --short` and report the commit SHA, version, registry verification, and tests/builds run.

## Guardrails

- Do not use `npm version` unless the user wants its automatic git tag/commit behavior.
- Do not commit generated package artifacts that are ignored by the repo.
- Do not rewrite unrelated dirty files. If unrelated changes are staged, separate them before committing.
- If publish succeeds but commit fails, tell the user immediately; never hide a partially completed release.
- If commit succeeds but publish fails, keep the version bump committed only when that matches the user's release policy; otherwise ask before reverting.
