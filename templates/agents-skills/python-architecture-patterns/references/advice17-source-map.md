# @advice17 Source Map

## Snapshot provenance

- Source channel: https://t.me/s/advice17
- Working corpus snapshot is not distributed with this public bundle.
- Retrieved from Telegram public preview: `2026-07-22T19:55:45.736977+00:00`
- Corpus SHA-256: `14ef4ea7d09e7ce92cc848f1d72b7128c56cb3d83d80b533e64ed46d5aad38a0`
- Rows are maintained paraphrases, not quotations. The rule/theme identifies the target guidance
  in this package; `MOVE` rows name the canonical destination.
- Status vocabulary: `KEEP` preserves a durable rule; `QUALIFY` adds conditions; `UPDATE` replaces
  an inaccurate/outdated rule; `MOVE` routes it to another skill; `REFERENCE_ONLY` keeps context
  without making it normative; `EXCLUDE` rejects it as coding guidance.


| Post | Guidance | Status |
|---|---|---|
| https://t.me/advice17/16 | Controller, business logic, SQL adapter, composition and transaction ownership | KEEP |
| https://t.me/advice17/47 | Object decorator, Python decorator, DI, cache lifetime | KEEP with `functools.wraps` modernization |
| https://t.me/advice17/52 | Domain-specific public repositories; private generic helper can be acceptable | KEEP |
| https://t.me/advice17/54 | Avoid half-initialized two-phase objects; use factories | KEEP |
| https://t.me/advice17/56 | Inject dependencies instead of constructing them in consumers | KEEP |
| https://t.me/advice17/59 | IoC container scopes, cleanup, graph validation, cycle diagnostics | QUALIFY: omit Dishka 1.0 promotion |
| https://t.me/advice17/60 | UoW tracks and coordinates persistence, not only commit/rollback | UPDATE: correct old pseudo-UoW example |
| https://t.me/advice17/68 | High-level policy owns the abstraction | KEEP |
| https://t.me/advice17/77 | Use cases, controllers, and interactors are distinct | UPDATE: correct old controller/interactor conflation |

Detailed ORM, loading, Alembic, and model-mapping claims from posts 44, 49, 66, 72, and 74 belong
to `python-database-patterns` rather than this core architecture skill.
