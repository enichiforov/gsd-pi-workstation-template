---
name: python-database-patterns
description: "Design and review relational Python persistence with SQLAlchemy/Core/ORM and Alembic: DAO/Data Mapper/Repository choices, domain-vs-persistence models, Unit of Work, transaction/session ownership, JOIN and relationship loading, projections, primary keys, migrations, concurrency, and async-session safety. Use for Postgres/SQL persistence and migration work; do not infer Mongo/Redis/vector-store guidance from this skill."
---

# Python Database Patterns

Start from data ownership, consistency, and query needs. Choose one clear persistence philosophy
per boundary instead of stacking pattern names.

## Workflow

1. **Name the operation and consistency requirement.** Identify reads, writes, invariants,
   concurrency conflicts, absence states, and atomic boundaries.
2. **Choose the data-access shape.**
   - DAO/read gateway for query-shaped records and read projections.
   - Repository/Data Mapper for domain identity and mutation.
   - Active Record only when persistence-coupled domain objects fit the application.
3. **Choose Core or ORM deliberately.** Prefer Core for explicit SQL/projections/bulk work; ORM for
   identity-mapped object graphs and UoW mutation. Mixing is valid at explicit boundaries.
4. **Assign transaction/session ownership.** Let the use case or transaction runner own begin,
   commit, rollback, and close. Keep one `Session` per thread and one `AsyncSession` per task.
5. **Put query mechanics in persistence.** Repositories/DAOs own SQL JOINs, projections, grouping,
   loading strategies, and mapping. Use cases state the business view they need.
6. **Select loading from measured access.** Consider round trips, row multiplication, parameter
   limits, memory, and consistency. Prevent accidental lazy I/O across closed/async boundaries.
7. **Design migrations as deploy artifacts.** Make them immutable after release, review
   autogenerate, test both clean-base-to-head and supported predecessor-data upgrades on the real
   target DB, and check head/drift policy.
8. **Verify failure behavior.** Test constraint violations, failed flush/rollback, concurrent
   writers, retries, deadlocks, migration replay, and absence semantics.

## Core rules

- Avoid database transactions across provider/object-storage/LLM/Telegram I/O by default. If a
  deliberately required invariant cannot use outbox/saga/checkpoint designs, state lock duration,
  timeouts, failure coupling, retry behavior, and why the coupling is safe.
- After a SQLAlchemy flush failure, roll back explicitly before reusing the session.
- Do not let repositories commit independently when a use case spans multiple operations.
- Keep public repository methods domain-specific. Reuse private generic helpers when useful.
- Treat separate domain/ORM models as a trade-off, not a universal error: require explicit,
  tested mapping, identity, and persistence semantics.
- Allow DB-native JSON/array projections for deliberate read models; reject them only when they
  leak persistence shapes into a boundary that promises domain objects.
- Treat a primary key as identity, not ordering, count, secrecy, or authorization.
- Keep migrations self-contained enough to survive application refactors; do not import mutable
  application models into released migrations.

## Load references selectively

- For DAO/Repository/Data Mapper/Active Record and model separation, read
  [data-access-patterns.md](references/data-access-patterns.md).
- For transactions, UoW, concurrency, JOINs, and loading, read
  [transactions-and-loading.md](references/transactions-and-loading.md).
- For Alembic and deployment checks, read [migrations.md](references/migrations.md).
- For provenance and qualified channel claims, read
  [advice17-source-map.md](references/advice17-source-map.md).

## Output contract

Return:

1. operation and consistency requirements;
2. chosen persistence pattern and why;
3. transaction/session owner;
4. query/JOIN/loading plan;
5. model/projection boundary;
6. migration impact;
7. concurrency and failure tests.

State database, driver, SQLAlchemy, and Alembic versions when behavior depends on them.
