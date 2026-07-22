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
| https://t.me/advice17/10 | Use structured APIs instead of string interpolation for machine formats | KEEP; require contextual HTML escaping |
| https://t.me/advice17/18 | Shared mutable state creates races | MOVE detailed diagnosis to async/concurrency skill |
| https://t.me/advice17/23 | Catch expected exceptions narrowly and translate at real boundaries | KEEP; custom exceptions remain conditional |
| https://t.me/advice17/29 | Understand references/GC and avoid `__del__` for cleanup | KEEP with evidence workflow |
| https://t.me/advice17/36 | Separate logger emission from application-level handler configuration | KEEP |
| https://t.me/advice17/58 | ABC versus structural `Protocol` | MOVE to architecture/code-quality ownership |

Metrics, tracing, correlation, systematic reproduction, and task/thread evidence are modernization
additions needed to make “debugging and observability” an executable workflow.
