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
| https://t.me/advice17/5 | Avoid hidden mutable globals and singleton lifecycle coupling | KEEP |
| https://t.me/advice17/7 | Use nested definitions cautiously; prefer explicit state when reuse/testing matters | QUALIFY: not “untestable” |
| https://t.me/advice17/8 | Choose objects for fixed shapes and mappings for dynamic keys | KEEP |
| https://t.me/advice17/9 | Distinguish public, underscore-private convention, and name mangling | KEEP |
| https://t.me/advice17/30 | Keep construction distinct from workflow and conversion | KEEP |
| https://t.me/advice17/35 | Every construct must justify its maintenance cost | KEEP |
| https://t.me/advice17/46 | First-class callables, argument forwarding, closures | KEEP |
| https://t.me/advice17/47 | Python decorator versus object decorator and hidden registry/cache risks | KEEP with typing/`wraps` modernization |
| https://t.me/advice17/64 | Preserve subtype contracts | KEEP |
| https://t.me/advice17/65 | Keep DTOs representation-specific and logic-light | QUALIFY: boundary validation is valid |
| https://t.me/advice17/68 | Invert dependencies toward high-level requirements | KEEP |
| https://t.me/advice17/70 | Isolate vendor vocabulary with an anti-corruption layer | KEEP |

The modernization workflow for typing, linting, and compatibility is not attributed to the
channel; it is operational guidance added to make the skill executable.
