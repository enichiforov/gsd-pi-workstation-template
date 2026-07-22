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
| https://t.me/advice17/8 | Prefer typed objects over unstructured fixture dictionaries for fixed shapes | KEEP |
| https://t.me/advice17/14 | FastAPI dependencies can be overridden in tests | UPDATE: callable dependencies are supported; see current FastAPI docs |
| https://t.me/advice17/24 | Import shape determines the namespace to patch | KEEP |
| https://t.me/advice17/31 | Distinguish stubs, mocks, and patching | UPDATE: patch is replacement; spy observes/delegates |
| https://t.me/advice17/49 | Exercise Alembic behavior through supported APIs | UPDATE: retain clean-base-to-head replay |
| https://t.me/advice17/56 | DI makes boundary replacement explicit | KEEP |

Corrected prior skill defects:

- async fixtures now use `@pytest_asyncio.fixture` in strict-mode examples;
- fake return annotations include `None` when absence is possible;
- checkpoint guidance no longer asserts recall the node never reads;
- database integration no longer constructs an unrelated real external backend;
- fallback behavior must come from a named contract, not from the test author's preference.
