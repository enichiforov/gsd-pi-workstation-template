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
| https://t.me/advice17/6 | Compose settings externally and inject them | KEEP |
| https://t.me/advice17/24 | Use package imports instead of `sys.path` mutation | KEEP |
| https://t.me/advice17/25 | Imports execute code; avoid surprising side effects | KEEP |
| https://t.me/advice17/26 | Environment variables are process inputs; dotenv is one loader | KEEP |
| https://t.me/advice17/37 | Cwd belongs to the launcher; resolve paths deliberately | KEEP |
| https://t.me/advice17/43 | Distinguish terminal, shell, and standard streams | REFERENCE_ONLY |
| https://t.me/advice17/50 | Understand argv, PATH, shell parsing, and cross-platform launch | KEEP with current subprocess docs |
| https://t.me/advice17/57 | Recreate and do not commit/move virtual environments | KEEP |

Dependency locking, `pyproject.toml`, secret-store, and secure diagnostic workflows are
modernization additions rather than channel-derived claims.
