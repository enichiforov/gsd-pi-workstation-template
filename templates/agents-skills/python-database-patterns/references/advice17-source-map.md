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
| https://t.me/advice17/16 | SQL stays in adapter; use case owns scenario and atomicity | KEEP |
| https://t.me/advice17/18 | Sessions/connections have explicit concurrency safety | KEEP with current library docs |
| https://t.me/advice17/21 | Migrations are deploy artifacts | KEEP |
| https://t.me/advice17/44 | Choose relationship loading deliberately | QUALIFY: DB-native projections can be valid |
| https://t.me/advice17/49 | Review Alembic autogenerate and isolate revision imports | UPDATE: retain clean-base-to-head replay |
| https://t.me/advice17/52 | Avoid public generic repositories; private helper exception | KEEP |
| https://t.me/advice17/53 | Distinguish DBMS, driver, query builder, ORM, repository | KEEP |
| https://t.me/advice17/55 | Choose primary keys from identity requirements | QUALIFY: PK is not authorization/order/secrecy |
| https://t.me/advice17/60 | UoW tracks and coordinates changes | KEEP |
| https://t.me/advice17/66 | Select data-access pattern from behavior/state ownership | KEEP |
| https://t.me/advice17/72 | Distinguish state-in-memory and state-in-database flows | KEEP |
| https://t.me/advice17/74 | SQLAlchemy Core, ORM, Session, Identity Map | QUALIFY: separate domain/ORM models are not universally wrong |

The channel does not substantively cover MongoDB, Redis, Supabase, or vector-store workflows, so
the skill description no longer claims those scopes.
