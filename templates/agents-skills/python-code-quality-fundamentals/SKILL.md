---
name: python-code-quality-fundamentals
description: "Apply and review Python code-quality fundamentals — SOLID (DIP, LSP, SRP), DTOs, anti-corruption layers, global-variable pitfalls, private vs public attributes (_ and __ name mangling), class vs dict, avoiding speculative abstractions. Use during code review, when introducing abstractions/DTOs, or judging whether code is clean vs over-engineered."
---

# Python Code Quality Fundamentals

**Source:** @advice17 — #35 (purpose of every line), #5 (global variables), #9 (private/public attrs), #68 (DIP), #64 (LSP & polymorphism), #65 (DTO), #70 (Anti-Corruption Layer), #8 (objects vs dicts), #7 (nested funcs/classes).

## When to Use

- Code review of Python modules/agents
- Deciding class vs dict, `_` vs `__`, when to add an abstraction
- Judging inheritance / overrides for LSP compliance
- Introducing DTOs or an anti-corruption layer around an external API
- Any "is this clean / is this over-engineered?" question

## 1. Every line has a purpose (#35)

Good code has no line without a reason (functionality, readability, or test coverage). Remove what earns nothing:
- No dead/unreachable code, no unused functions — they cost maintenance and rot (untested → broken when finally used).
- No speculative abstractions. Badly-placed abstractions are as hard to fix as missing ones — sometimes *don't* introduce them (YAGNI).
- Comments must add information: `# multiply RPS by 3600` is noise; `# approximate requests per hour from current RPS` is signal.

Use each construct only for its purpose (keeps WTFs/min low):
- Classes exist to be instantiated. Don't make a `class Constants:` of only class attributes, or classes of only `@staticmethod`s — put constants at module level or in a settings object with one instance.
- `Enum` = a fixed set of instances, not a grab-bag of app logic or heterogeneous data.
- `@staticmethod`/`@classmethod` = methods that must never touch an instance.
- `__init__.py` = package init/exports, not main logic.
- Don't abuse list comprehensions for side effects: `[print(i) for i in xs]` is wrong — use a `for` loop.
- **Do** add small helpers that improve reading: `if is_price_valid(price):` beats an inline `if 0 < price:`.

## 2. Global variables are a trap (#5)

Six problems: uncontrolled access across layers, hidden dependencies (can't tell what a function needs), uncontrolled lifecycle (exists at import time), tight coupling to init code, impossibility of two instances without changing callers, and hard testing. Singletons share most of these plus add buggy complexity for no gain. Whenever a variable's lifecycle isn't physically tied to the interpreter's, use **Dependency Injection** instead. Framework DI mechanisms should be confined to the layers that touch the framework.

## 3. Private vs public attributes (#9)

Python has no access enforcement — only conventions:
- **Single underscore `_x`** — "not part of the public API." A convention; linters flag external access. This is *not* Java `protected`.
- **Double underscore `__x`** — triggers **name mangling**; protects an attribute from being *overridden* by subclasses (still reachable with effort). Use it only when your methods must bind to *your* attribute regardless of what a subclass defines.
- Everything else → fix the architecture (split interface/implementation, add a facade) rather than relying on visibility tricks.

## 4. DIP — Dependency Inversion Principle (#68)

DIP ≠ DI. DIP is a design principle: abstract/high-level/general code must not depend on concrete/low-level/specific code. To invert a dependency, extract A's *requirements* on D as an interface B (owned by A); D then implements B. Result: A knows only B; D knows A's requirements. Purpose: fight complexity, ease testing, add flexibility, isolate future change, enable reuse. It has a cost — indirection (the impl must be hunted down); a badly-scoped abstraction pays the cost without the benefit. Sometimes two components are at the same level and inversion isn't needed (e.g. the code that literally draws to the screen depending on the screen).

## 5. LSP — Liskov Substitution (#64)

If code expects a base instance, a subclass must work correctly there — for the object's whole life, even after calling subclass-only methods. Requirements for the base method live in docs/tests; the subclass must satisfy them and pass the base's tests. Override options, from safest:
1. Same external behavior, different implementation (fully interchangeable).
2. Same behavior + extra work on subclass-only fields.
3. Change behavior without breaking the base method's contract (may widen accepted params / narrow returned values).
4. Keep signature but change behavior incompatibly — usually a bug: tools still think it's substitutable.
5. Change the signature incompatibly — clearly not substitutable (tools can catch it).

Abstractions (from DIP) give more freedom for legitimate polymorphism while staying LSP-safe.

## 6. DTO — Data Transfer Object (#65)

A DTO is a logic-free data structure meant to be transferred/serialized (in or out). Notes:
- No domain model required — a DTO is any data (assembled from other DTOs, several entities, or generated).
- Serialization format is orthogonal (json/xml/protobuf); one DTO need not serve all formats.
- If a DTO carries serialization logic, **confine it to the outer layer** — an interactor must not return a self-serializing DTO; push serialization outward.
- A DTO holds structure + common types. Generic guards (max size) are fine; per-field business validation (string length, numeric range) belongs elsewhere.
- Client and server DTOs may differ in implementation but must agree on the wire structure — changing fields/types can break the other side.
- Good DTOs: `@dataclass`. **Pydantic models carry serialization logic → keep them at adapter/view boundaries**, don't reuse one across unrelated adapters.

## 7. Anti-Corruption Layer (#70)

Isolate an external system behind an ACL so its API changes don't corrupt your domain:
- Business logic depends on **your** interface + models (your terms, only the aspects you care about).
- If the vendor API is ugly, write a thin **client facade** *in the vendor's terms* (stricter types, split/grouped calls) — do **not** translate to domain here.
- An **adapter** maps your-terms calls → vendor-terms calls (may fan out to several vendor calls).
- Data-shape conversion goes in dedicated **translators** (objects or adapter methods).

## 8. objects vs dicts, nested defs (supporting)

- **Class vs dict (#8):** fixed set of meaningfully-different keys → make a class/`@dataclass` (IDE catches typos in attributes, not in dict keys). Dynamic, homogeneous, non-fixed keys → dict. Dicts for external integration (json/config) are fine, but wrap them in an adapter that converts to real classes; keep `to_dict` serialization in the layer that owns the final representation, not on the domain object.
- **Nested functions/classes (#7):** create per call, untestable, capture hidden mutable context, add nesting, can't be reused. Good only for genuine closures (callbacks, decorators). Otherwise lift them out (add params, or make a class to declare the mutable context); use modules — not nested classes — as namespaces.

## Anti-Patterns

- Module-level mutable globals / singletons holding app state (use DI).
- `class Constants:` / all-`@staticmethod` classes / logic inside `Enum`.
- Overriding a method in a way that breaks the base contract (LSP violation).
- Passing Pydantic models deep into business logic / reusing one across unrelated adapters.
- Dicts with fixed, meaningful keys threaded through the codebase instead of a dataclass.
- Nested functions used as un-testable mini-modules.
- Speculative abstractions "for the future."

## References
- Posts #35, #5, #9, #68, #64, #65, #70, #8, #7
- [DIP in the wild](https://martinfowler.com/articles/dipInTheWild.html), [DTO](https://martinfowler.com/eaaCatalog/dataTransferObject.html), [PEP 544 Protocols](https://peps.python.org/pep-0544/), [YAGNI](https://martinfowler.com/bliki/Yagni.html)

## Pair With
- `python-architecture-patterns` — layering, DI, use cases
- `python-testing-and-mocks` — testing designs that follow DIP
