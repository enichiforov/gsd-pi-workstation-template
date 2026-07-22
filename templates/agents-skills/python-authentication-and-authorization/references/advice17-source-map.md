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
| https://t.me/advice17/62 | Separate identification, authentication, and authorization; keep authorization in business/application logic | KEEP with current security verification |
| https://t.me/advice17/63 | Hide authentication mechanisms behind a boundary and keep core code independent of sessions/JWT/mTLS | QUALIFY |

Do not make a parameterless `IdentityProvider.get_current_user()` the universal shape. It can hide
request-scoped state, service-locator coupling, and async I/O. Prefer an explicit immutable
principal across the application boundary, while allowing a request-scoped provider inside the
delivery adapter.

Rebuild token, session, cookie, and identity-provider details from current OWASP and framework
documentation rather than treating the 2024 examples as a complete security design.
