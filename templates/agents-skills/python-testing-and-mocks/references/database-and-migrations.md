# Database and Migration Tests

## Layers

- Unit-test use cases with a fake repository/UoW when persistence behavior is not under test.
- Integration-test each real repository/DAO against the target database dialect.
- Test transaction boundaries and constraints with real commits/rollbacks.
- Keep provider/LLM clients fake when the integration boundary under test is only the database.

Do not construct unrelated real external backends in a “database integration test.”

## Isolation

Select one deliberate strategy:

- transaction rollback per test when application commits do not escape it;
- truncate/reset known tables;
- temporary schema/database;
- disposable container/database.

Test parallel execution and sequence/identity effects when relevant.

## Repository cases

Cover:

- found and domain-required absence;
- uniqueness/foreign-key/check constraints;
- mapping/default/generated values;
- JOIN/projection and query count;
- optimistic/pessimistic concurrency;
- failed flush followed by rollback;
- transaction spanning multiple repositories;
- dialect-specific types and SQL.

## Alembic

Use Alembic's Python command API or the project's supported CLI path. Verify:

1. empty supported database → head;
2. expected single/multiple head policy;
3. schema/metadata drift policy;
4. application smoke test at head;
5. downgrade only if promised;
6. clean-base-to-head replay after supported runtime/dependency/database upgrades.
7. every supported predecessor schema snapshot with representative data → target head;
8. backfill resumability, batching, lock/statement timeouts, and post-migration invariants;
9. old-application/new-schema and new-application/old-compatible-schema operation during any
   promised rolling-deploy compatibility window.

Clean-base replay does not prove transformation of real predecessor data. Retain both upgrade
lanes. Do not stop regression-testing released revisions solely because they were released;
historical imports or APIs can break later.
