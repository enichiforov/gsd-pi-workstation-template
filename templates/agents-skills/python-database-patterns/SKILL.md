---
name: python-database-patterns
description: "Design and review Python data-access layers — DAO/Data Mapper/Repository patterns, state-in-memory vs state-in-DB, SQLAlchemy Core vs ORM, Unit of Work, relationship loading strategies (N+1/joined/select-in), primary keys, Alembic migrations, session thread-safety. Use for any database, Supabase/Postgres/pgvector, ORM, or migration work."
---

# Python Database Patterns

**Source:** @advice17 — #53 (DB components), #66 (Fowler data-access patterns), #72 (state-in-memory vs state-in-DB), #74 (SQLAlchemy Core vs ORM), #60 (Unit of Work), #44 (relationship loading strategies), #55 (primary keys), #49 (Alembic), #21 (migrations), #16 (SQL without ORM), #18 (thread-safety of sessions).

## When to Use

- Designing or reviewing a data-access layer (gateways, repositories, DAOs)
- Choosing between SQLAlchemy Core and ORM
- Deciding Active Record vs Data Mapper vs DAO
- Writing/reviewing Alembic migrations
- Fixing N+1 queries or slow relationship loads
- Picking a primary-key strategy (autoincrement vs UUID)
- Any Supabase/Postgres/pgvector work

## 1. The stack of a DB integration (#53)

Know which layer you are touching:

| Layer | Role | Examples |
|-------|------|----------|
| DBMS | Server or embedded engine, owns the query language | PostgreSQL, SQLite, Redis, MongoDB |
| Client library | Hides wire protocol, speaks the language of your runtime | `psycopg`, `asyncpg` |
| Query builder | Helps construct queries safely | SQLAlchemy Core |
| ORM | Object ↔ relational mapping, change tracking, related-data loading | SQLAlchemy ORM |
| Gateway / DAO / Repository | **Your** code, isolates the DB behind business-meaningful methods | your `*Repository`, `*DAO` |

Rule: keep SQL and driver details inside the bottom layers. Business logic talks to *your* gateway, never to raw cursors.

## 2. Two philosophies: state-in-memory vs state-in-DB (#72)

- **State-in-memory** (Active Record, Data Mapper, Unit of Work): `load → mutate in memory → save`. Lets you test mutation logic without a DB and unifies access. Constraints:
  - Don't run raw `insert/update/delete` outside the save step — the loaded state desyncs from the DB.
  - The same entity reachable by two paths can produce two in-memory copies that disagree → use **Identity Map**.
  - Concurrent requests mutating the same entity can corrupt data → locks + load the full related set needed to enforce invariants.
- **State-in-DB** (DAO): keep minimal data in memory, push work into queries. More efficient for high load / specialized stores, but business logic leaks into SQL/stored procedures and the storage API sprawls.

Pick state-in-memory for rich domain models; state-in-DB for raw throughput or non-relational stores. DAO is also fine for read-only "screen" queries that need a cross-cut of the DB without business logic.

## 3. Fowler data-access patterns (#66)

**Group A — separate storage ops from data (hideable storage):**
- **DAO / Table Data Gateway** — dumb class, runs operations, returns plain data (RecordSet/DTO). No cache, no Identity Map. Easy, tunable per query.
- **Data Mapper** — two-way sync between domain models and storage; can hold an Identity Map; one mapper per model type; used by Unit of Work to persist.
- **Repository** — like Data Mapper but for aggregate roots; looks like a collection to business logic; can return polymorphic models and summary/aggregate info. The main pattern for rich domain models.

**Group B — mix data and storage (harder to test/change):**
- **Raw Data Gateway** — one instance per row + a separate Finder.
- **Active Record** — Row Data Gateway *with* business logic; rich models not abstracted from storage; finders often as `@classmethod`s.

Most Python ORMs implement Active Record with implicit connection/transaction control. **SQLAlchemy implements Data Mapper** and gives a higher abstraction (see `map_imperatively`).

## 4. SQLAlchemy: Core vs ORM (#74)

Two APIs:
- **Core** — `select/insert/update`, `Connection.execute`, `Table` objects. Explicit SQL construction.
- **ORM** — entity classes; `Session.get(Model, pk)` or `select(Model)`; `session.add`, mutate + `commit`, `session.delete`. The `Session` **is** a Unit of Work + Identity Map.

```python
# Core (async): await the coroutine, THEN use the Result
result = await conn.execute(select(users_table).where(users_table.c.age > 25))
rows = result.all()

# ORM (async)
result = await session.execute(select(User).where(User.age > 25))
users = result.scalars().all()
user = await session.get(User, 42)      # identity-map aware
session.add(User(name="ivan"))          # buffered in the UoW
await session.commit()                  # flush + commit
```

Key correctness notes:
- If you use ORM models but call `insert`/`update`, **you are not using the ORM** — acceptable only as a targeted optimization, not the default.
- Do **not** create separate domain entities *alongside* ORM models — the hand-written mappers usually ignore Identity Map / UoW and corrupt save logic. Instead choose one of: (a) no ORM (Core only), (b) ORM models *as* the domain entities, (c) dataclasses + imperative mapping.
- Even with the ORM, wrap complex `select`s in a **Repository**. Read-only projections can use a Core-based DAO or alternative imperatively-mapped models.

## 5. Unit of Work (#60)

Tracks changes and persists them coordinately: `register_new/register_dirty/register_deleted` → `commit`. It is more than a transaction wrapper — it batches writes (e.g. merges inserts), can enforce integrity (optimistic locks), and delegates actual writes to Data Mappers. It pairs naturally with Identity Map. SQLAlchemy's `Session` already is a UoW; don't reimplement it on top.

## 6. Relationship loading strategies (#44)

| Strategy | What it does | Watch out |
|----------|--------------|-----------|
| Lazy (N+1) | 1 query for A, then 1 per row into B | Almost always avoid; happens implicitly if you don't eager-load |
| Joined (`selectinload`? no — `joinedload`, Django `select_related`) | single JOIN, columns from both | one-to-many duplicates rows (dedup client-side); careful with BLOBs |
| Select-in (`selectinload`, Django `prefetch_related`) | 2nd query `... WHERE id IN (...)` | no dup rows; huge id lists may need chunking |
| Subquery load | 2nd query re-runs the first as a subquery | when re-fetching ids in-DB is cheaper than shipping them |
| Array/JSON agg | aggregate related rows into arrays/json | rarely in ORM; building transport shapes in DB is an anti-pattern |

The N+1 problem is the default failure mode — choose an explicit strategy.

## 7. Primary keys (#55)

- **Superkey** → any unique set of columns. **Candidate key** → minimal unique set. **Primary key** → the one candidate key you pick (exactly one per table; may be composite; need not be named `id`).
- **Natural key** — an existing candidate key from the data. **Surrogate key** — a dedicated generated column.
- Surrogate generation: **UUID (e.g. uuid4)** — usable before hitting the DB, resists enumeration/count-leaks, but can be slower to index; **autoincrement** — needs a DB round-trip.
- Autoincrement values are **not** guaranteed contiguous or monotonic: deletes free nothing, rolled-back transactions burn numbers, and some DBs preallocate ranges per session. Never assume "max id == row count" or that ids reflect insertion order.

## 8. Migrations & Alembic (#21, #49)

Rules (#21):
1. Table structure is fixed at code-version time; don't create tables at runtime.
2. Migrations run **at deploy**, not on app start.
3. Each migration is self-contained; **never import app code** into a migration (app code changes; migrations must not).
4. Never edit a released migration — write a new one.
5. Test migrations; test DBs are updated only via migrations.
6. Review auto-generated migrations.
For zero-downtime, keep the schema compatible across two app versions (e.g. add column → backfill → later drop old).

Alembic gotchas (#49):
- Import errors → make your package installable (`pip install -e .`) so imports don't depend on the launch dir.
- Empty/partial autogen → model classes weren't imported; import them in the models package `__init__.py`.
- Autogen "drop everything" → generate migration N against the DB state after migration N-1; changes made outside migrations break generation.
- Autogen misses: Enum changes, column type changes, index recreation — **always review and edit**.
- Set a `naming_convention` on `MetaData` so constraint/index names are stable (downgrade breaks otherwise).
- Test migrations, but don't keep them in the regression suite; do assert single-head and up/down replayability.

## 9. Thread-safety (#18)

- `sqlite3.Connection` — **not** thread-safe (one transaction per connection; commit vs rollback race).
- SQLAlchemy `Session` — **not** thread-safe (same reasons). `Engine` (connection pool) — **is** thread-safe; create sessions per unit of work.
- `asyncpg`/pool objects — follow their docs; a pool is shared, a connection/transaction is not.

## Anti-Patterns

- **Generic repository** (`get/save/delete` for all types) — a leaky, contract-free abstraction; see `python-architecture-patterns`. Use it only *inside* a concrete repository.
- Raw `insert/update` scattered through business logic when using an ORM (desyncs UoW state).
- Domain models duplicated next to ORM models with hand mappers.
- `Base.metadata.create_all()` in production / migrations on app start / importing app code into migrations.
- Sharing one `Session`/`sqlite3.Connection` across threads.
- Assuming autoincrement ids are gapless or ordered.

## References
- Posts #53, #66, #72, #74, #60, #44, #55, #21, #49, #16, #18
- Fowler: [Data Mapper](https://martinfowler.com/eaaCatalog/dataMapper.html), [Unit of Work](https://martinfowler.com/eaaCatalog/unitOfWork.html), [Identity Map](https://martinfowler.com/eaaCatalog/identityMap.html), [Repository](https://martinfowler.com/eaaCatalog/repository.html)
- [SQLAlchemy loading relationships](https://docs.sqlalchemy.org/en/20/orm/queryguide/relationships.html), [Alembic](https://alembic.sqlalchemy.org/en/latest/)

## Pair With
- `python-architecture-patterns` — layering, DI, generic-repo anti-pattern
- `python-testing-and-mocks` — testing the data layer, Alembic tests
- `python-performance-optimization` — N+1, connection pools
