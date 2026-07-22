---
name: python-code-quality-fundamentals
description: "Implement and review maintainable Python code: explicit state, cohesive responsibilities, public API discipline, typed data shapes, constructor contracts, decorators and closures, SOLID trade-offs, DTO/anti-corruption boundaries, and static-analysis-ready refactoring. Use for code review, cleanup, class-vs-dict decisions, public/private APIs, over-engineering, or maintainability-focused implementation."
---

# Python Code Quality Fundamentals

Optimize for clear behavior, explicit ownership, and cheap change. Treat principles as decision
tools, not universal slogans.

## Workflow

1. **State the observable contract.** Identify inputs, outputs, side effects, failure/absence
   states, and compatibility constraints.
2. **Remove unsupported machinery.** Delete dead code, speculative abstractions, duplicate paths,
   and comments that merely narrate syntax.
3. **Make state and dependencies explicit.** Replace mutable globals and hidden ambient context
   with owned objects or parameters.
4. **Choose a data shape by semantics.** Use a typed record/object for fixed heterogeneous fields
   and a mapping for dynamic homogeneous keys. Keep boundary schemas at boundaries.
5. **Design the public API.** Expose only supported operations. Use a single leading underscore for
   non-public names; use double-underscore name mangling only to avoid subclass collisions.
6. **Keep construction honest.** After `__init__` returns, the object is usable. Move I/O,
   conversion, and multi-step workflows to factories or use cases.
7. **Use inheritance and decorators deliberately.** Preserve consumed contracts. Prefer
   composition when behavior or lifetime varies independently.
8. **Verify mechanically.** Run tests, formatter, linter, type checkers, import/dependency checks,
   and public API/compatibility tests required by the repository.

## Core rules

- Give each module/class/function one cohesive reason to change; do not split code solely by line
  count.
- Prefer the simplest representation that makes invalid or ambiguous states hard to express.
- Keep Pydantic/serialization and vendor models at external/module boundaries unless the project
  deliberately uses them as its domain model.
- Use `dataclass` or another typed record for fixed internal data without validation needs.
- Preserve Liskov substitutability: a subtype must not strengthen preconditions, weaken
  postconditions, or violate documented/tested behavior.
- Define Protocols/interfaces from the consumer's need, not by copying a concrete provider.
- Translate vendor data/errors through an anti-corruption adapter when provider vocabulary would
  otherwise leak into core code.
- Keep comments for intent, trade-offs, invariants, and non-obvious constraints.
- Qualify recommendations with context and evidence; avoid “always/never” unless violating the
  rule would break a declared invariant.

## Load references selectively

- For globals, objects/dicts, visibility, constructors, closures, decorators, DTOs, and ACLs, read
  [python-language-design.md](references/python-language-design.md).
- For channel provenance and qualified claims, read
  [advice17-source-map.md](references/advice17-source-map.md).
- Use `python-architecture-patterns` for application boundaries, `python-testing-and-mocks` for
  test design, and `python-performance-optimization` for measured performance changes.

## Output contract

Return findings in priority order with:

1. the violated or endangered contract;
2. concrete evidence in the code;
3. the smallest corrective change;
4. tests/static checks that prove it;
5. a trade-off when more than one design is valid.

Do not recommend an abstraction, pattern, or rewrite without showing the maintenance problem it
solves.
