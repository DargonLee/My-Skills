---
name: review-uncommitted
description: Review the working tree's uncommitted code changes (staged + unstaged) against this repo's conventions — run a deterministic review pass focused on correctness, RN/react-hooks pitfalls, native-bridge parity, and silent-failure smells. Use when asked to "review the uncommitted code", "review my changes", "看看未提交的代码", or before staging/committing.
---

# Review Uncommitted Code

A deterministic review pass over the **current working tree diff** (staged + unstaged, never
committed). Scope is the diff only — do not audit the whole file unless a flagged line requires
context.

## Inputs

- The diff comes from git. Always read BOTH staged and unstaged, plus any untracked files:

```bash
git status --porcelain
git diff HEAD -- <paths>          # everything not yet committed
```

If only certain files changed, scope the review to those paths. Skip generated output
(`lib/`, `dist/`, `package-lock.json`, `yarn.lock`) unless explicitly asked.

## Review Procedure (run in order)

### 1. Gather the diff
```bash
git diff --stat HEAD          # overview
git diff HEAD -- <files>       # full diff with context
```
For files too large to read whole, read only the changed hunks plus a few surrounding lines.
Use `git diff HEAD -- <file>` rather than re-reading the entire file unless context demands it.

### 2. Apply the project-specific lens (rn-runtime / @ninebot/rn-dynamic)

These are the high-signal checks for THIS codebase. Weight findings here heavily.

#### React / React-Native correctness
- **Hook deps:** every `useEffect`/`useCallback`/`useMemo` dependency array. Missing deps →
  stale closures; extra deps → needless re-subscribe/rebuild. `useProtocolPage` deliberately
  uses refs (`optionsRef`, `isFocusedRef`) to avoid stale closures WITHOUT adding deps —
  verify new code follows this pattern instead of capturing values in closures.
- **Effect cleanup:** every subscription (`AppState.addEventListener`,
  `navigation.addListener`, timers, listeners) must be torn down in the returned cleanup.
  A ref that holds a subscription with no teardown is a leak.
- **`mounted` guard:** async work started in an effect (`controller.start().then(...)`) must
  check a `mounted` flag before calling `setLoading`/`setState` — the effect's cleanup sets
  `mounted = false`.
- **Idempotent lifecycle calls:** `controller.pause()`/`resume()` are documented as idempotent;
  defensive calls are fine, but don't *rely* on ordering across two competing effects without a
  shared ref (see the `AppState` + `useFocusEffect` coordination via `isFocusedRef`).

#### State / immutability
- Never mutate `stateManager` snapshots or node values in place — return new objects.
- `setState` updates must be functional or immutable-spread, not direct mutation.

#### Native-bridge parity (HIGH severity if violated)
- Any change to the shape of data passed to `callnative` / `NBDynamicModuleService` must be
  mirrored on the Swift side (`NBDynamicModuleService.swift`). Flag un-mirrored contract changes.
- Recall: the TurboModule already strips the native `{code,data,msg}` envelope — RN receives the
  inner `data`; parsing must be per-method, not re-unwrap an envelope.

#### Silent-failure smells (MEDIUM+)
- `try/catch` that swallows errors without logging, rethrowing, or surfacing to UI.
- `await` without error handling at a system boundary (BLE read/write, native calls).
- `.catch(() => {})` or empty catch blocks.
- Fallbacks that hide a real failure (e.g. returning `null`/default when the contract failed).

#### Config/protocol correctness
- Changes to `src/types.ts` or `src/runtime/compile.ts` validation: is the new field documented
  in `docs/todo.md`? Is a test added under `__tests__/`?
- `stableSerialize` / `configKey` usage: don't introduce per-render `JSON.stringify` of `config`.

### 3. General code-quality pass (lower weight, still report)
- Functions >50 lines, files >800 lines, nesting >4 levels.
- Hardcoded values that should be constants/tokens (`styles/tokens.ts`).
- `console.log` left in production code (`__DEV__`-gated warnings are acceptable).
- Dead code, commented-out blocks, unused imports.
- Naming: booleans `is/has/should/can`, hooks `use*`, components PascalCase.

### 4. Read surrounding context only as needed
- If a hunk references a symbol whose contract is unclear, read just that function in its file.
- Do NOT read entire large files for routine review — trust the diff context.

## Output Format

Present findings grouped by severity. Use `file:line` references (clickable). For each finding:

- **Severity** tag, file:line, one-line title.
- What's wrong (the actual code).
- Why it matters (tie to the lens above — e.g. "stale closure", "un-mirrored native contract",
  "swallowed BLE error").
- Concrete fix suggestion (prefer a code snippet).

End with a one-line verdict: **Approve** / **Warn** / **Block** per:
- **Approve**: no CRITICAL/HIGH.
- **Warn**: only HIGH issues.
- **Block**: any CRITICAL (security, data loss, native-contract mismatch that breaks runtime).

## Hard Rules

- Review ONLY uncommitted changes. Do not propose refactors of untouched code — note them as
  separate "out of scope" suggestions at most.
- If the diff is empty (`git diff HEAD` is clean), say so and stop — do not invent findings.
- Never auto-apply fixes unless the user asks. Report; let them decide.
- Match the project's comment language: inline rationale in Chinese is the norm — don't "fix" it.
- After flagging a native-bridge contract change, explicitly remind the user of the
  `yarn prepare` rebuild step if `src/` was touched.

## Severity Reference

| Level | Meaning | Examples |
|-------|---------|----------|
| CRITICAL | Security / data loss / breaks runtime | Native contract mismatch; un-handled BLE write error corrupting device state |
| HIGH | Likely bug | Missing effect dep causing stale closure; subscription leak; setState after unmount |
| MEDIUM | Maintainability / latent risk | Swallowed error; missing test for new protocol field; >50-line function |
| LOW | Style / nits | Unused import; hardcoded value; comment language |
