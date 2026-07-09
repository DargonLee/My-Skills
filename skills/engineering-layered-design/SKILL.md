---
name: engineering-layered-design
description: Use when designing, reviewing, or refactoring code architecture and engineering structure, especially when logic is leaking into the wrong layer, UI components contain business rules, orchestration services do data parsing, one bug hints at a reusable abstraction, or a feature needs clear boundaries between data source, transformation, state management, extension points, and rendering. Use for separation of concerns, layered design, parser/adapter/pipeline decisions, reusable contracts, and preventing narrow fixes from becoming hardcoded architecture.
---

# Engineering Layered Design

Use this skill to turn a concrete bug or feature into a clean engineering design. Do not anchor the design to the first example you see. Find the general responsibility boundary and make the smallest reusable structure that fits it.

## Core Principle

Ask one question before coding:

```text
What should this layer know, and what should it never need to know?
```

Good architecture keeps knowledge local:

```text
source/input
  -> extraction/adaptation
  -> transformation/domain interpretation
  -> orchestration/state distribution
  -> presentation/output
```

The exact names vary by project, but the responsibility split should remain clear.

## Responsibility Boundaries

- **Source layer** gets raw data or events. It should not format, interpret, or decide UI meaning.
- **Extractor/adapter layer** normalizes external shapes into internal raw values. It should not apply business display rules.
- **Transformation layer** applies reusable parsing, mapping, validation, formatting, or domain interpretation.
- **Orchestration/state layer** coordinates flow and stores/distributes results. It should not contain domain-specific `if type === ...` branches when those rules can be plugins or parsers.
- **Presentation layer** renders prepared state. It should not infer business semantics from raw values.

When a layer must know too much, introduce a boundary object, adapter, resolver, parser, or strategy registry.

## Refactor Workflow

1. Identify the concrete symptom.
2. Generalize the problem: ask what class of future problems looks the same.
3. Mark current misplaced knowledge, such as UI formatting, service-level business parsing, or controller-level data mapping.
4. Define a small contract between layers.
5. Move existing rules behind that contract.
6. Add one focused unit test for the new contract and one integration test for the old behavior.
7. Verify the feature still works through the public surface.

## Design Heuristics

- Prefer a pure function for isolated algorithms.
- Prefer a resolver or pipeline when multiple rules may apply in order.
- Prefer a registry when callers need to add custom behavior without editing core orchestration code.
- Prefer explicit contracts over implicit naming conventions.
- Prefer one extension point over scattered special cases.
- Do not create abstraction for one-off logic unless the bug reveals a repeated responsibility boundary.

## Anti-Patterns

Avoid these:

```ts
// UI knows business rules.
const label = rawValue === 1 ? 'Enabled' : 'Disabled';

// State service knows product-specific formatting.
if (node.type === 'some.business.card') {
  displayText = formatSpecialValue(value);
}

// Network adapter changes meaning instead of shape.
return response.data.items.map(toViewModel);
```

Prefer:

```ts
const raw = extractValue(response);
const resolved = resolveValue({ node, raw, context });
state.set(id, resolved.value);
state.setDisplay(id, resolved.displayText);
```

## Extension Point Checklist

Before adding an extension point, confirm:

- The core layer has a stable contract to call.
- Custom logic can opt in and opt out.
- Built-in behavior remains testable without app-specific setup.
- Ordering is deterministic.
- Unknown or unsupported cases fall back safely.

Good extension points usually return `undefined` to skip, and return a small result object to handle.

## Validation Checklist

Before finishing:

- The concrete example is not hardcoded into the architecture.
- Each changed file has one clear responsibility.
- The orchestration layer reads like a flow, not a rule catalog.
- UI renders prepared data instead of deriving business meaning.
- Tests cover the extracted rule and the integration path.
- Existing project verification commands have run.

## Mental Model

When a user says "this one value displays wrong," do not only fix that value. Ask whether the value passed through source, extraction, transformation, state, and UI boundaries correctly. The durable fix often lives in the boundary, not in the visible symptom.
