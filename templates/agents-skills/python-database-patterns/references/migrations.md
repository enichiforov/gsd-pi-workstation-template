# Alembic Migration Discipline

## Authoring

- Review every autogenerate result; it is a draft, not proof.
- Use stable naming conventions for constraints and indexes.
- Keep released revisions immutable.
- Avoid importing current ORM/application models into revision code.
- Make data migrations explicit about batching, locks, nullability, and mixed-version deployment.
- Separate destructive cleanup from compatibility rollout when zero-downtime deployment requires it.

## Verification

At minimum:

1. upgrade an empty supported database to head;
2. assert exactly the expected head(s);
3. compare metadata/schema according to project drift policy;
4. run application smoke tests against the upgraded schema;
5. test downgrade only when the project promises it;
6. replay old revisions after supported Python, driver, SQLAlchemy, Alembic, or database upgrades.
7. upgrade every supported deployed predecessor schema, with representative edge-case data, to
   the target head and verify post-migration invariants;
8. test backfill restart/resume, batching, lock/statement timeouts, and failure recovery;
9. when rolling deploys are supported, test old application/new schema and new application/old
   compatible schema for the declared compatibility window.

Clean-base-to-head and predecessor-with-data upgrades prove different properties; retain both.
Do not drop historical replay merely because revisions were released. Historical revision code
can break under dependency/runtime changes.

## Deployment

Run migrations as an explicit deploy step, not as an import side effect in every application
replica. Define:

- one migration owner;
- lock/concurrency behavior;
- timeout and rollback/roll-forward policy;
- application/schema compatibility window;
- backup and recovery for destructive operations.
