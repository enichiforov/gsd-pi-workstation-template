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
| https://t.me/advice17/17 | Separate interactive jobs and supervised services | MOVE: runtime/deployment details belong to `python-web-service-runtime` |
| https://t.me/advice17/18 | Shared mutable state creates races; safety is object-specific | KEEP |
| https://t.me/advice17/30 | `__init__` cannot await and should leave valid state | KEEP |
| https://t.me/advice17/32 | Cooperative/preemptive switching changes race behavior | QUALIFY: remove universal language/runtime mappings |
| https://t.me/advice17/33 | Choose processes/threads/async from workload and measure | KEEP |
| https://t.me/advice17/54 | Prefer async factory to half-initialized two-phase state | KEEP |
| https://t.me/advice17/71 | Awaiting yields control through Future/Task machinery | KEEP as mental model |
| https://t.me/advice17/73 | Callbacks complete Futures and resume Tasks; readiness drives socket I/O | KEEP |

Removed historical claims that cron is universally emulated by systemd or that Rust has one
language-defined scheduler. Cancellation, `TaskGroup`, timeout, and diagnostic workflows are
modernization additions, not claims attributed to the channel.
