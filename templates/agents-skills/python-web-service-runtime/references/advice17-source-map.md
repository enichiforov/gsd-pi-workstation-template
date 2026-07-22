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


| Post | Extracted guidance | Status |
|---|---|---|
| https://t.me/advice17/17 | Separate interactive long jobs, supervised services, and periodic work | QUALIFY: cron and systemd timers are alternatives; containers are not universally required |
| https://t.me/advice17/38 | Prefer mature high-level protocols over inventing a protocol on raw TCP | QUALIFY: verify current HTTP/version transport details |
| https://t.me/advice17/42 | Test restart, concurrency, and multiple replicas; externalize durable state and work | KEEP |
| https://t.me/advice17/48 | Distinguish framework, app server, supervisor, proxy/LB, and CDN | QUALIFY: verify framework production guidance |
| https://t.me/advice17/43 | Understand terminal and standard-stream boundaries | REFERENCE_ONLY |
| https://t.me/advice17/50 | Understand argv, PATH, cwd, shell parsing, and subprocess portability | KEEP; detailed process mechanics live in environment/config skill |

Do not treat channel promotions, product versions, or historical runtime generalizations as
normative guidance.
