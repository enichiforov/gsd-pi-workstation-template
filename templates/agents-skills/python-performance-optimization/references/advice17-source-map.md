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
| https://t.me/advice17/19 | Reuse expensive clients/connections | QUALIFY by thread/task safety and lifecycle |
| https://t.me/advice17/28 | Distinguish identity, rebinding, and mutation | KEEP |
| https://t.me/advice17/29 | Understand reference counting/GC and deterministic cleanup | KEEP with measurement workflow |
| https://t.me/advice17/33 | Select parallelization from workload and profile | KEEP |
| https://t.me/advice17/34 | Interpreter versions may change performance | UPDATE: remove “historically few optimizations” |
| https://t.me/advice17/44 | Relationship loading affects round trips and row volume | KEEP; detailed ownership lives in database skill |
| https://t.me/advice17/67 | Choose float/Decimal from representation requirements | UPDATE: remove stable 3x and universal no-`==` claims |
| https://t.me/advice17/69 | Dict performance depends on hashing/equality semantics | KEEP; remove machine-specific nanosecond facts |

Profiler/tool selection and statistical benchmark discipline are modernization additions.
