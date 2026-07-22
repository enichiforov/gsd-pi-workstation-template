# Transactions, Concurrency, and Loading

## Scope

Construct the session at the operation boundary and keep lifecycle outside data-specific methods:

```python
def execute(command: TransferCommand, session_factory: SessionFactory) -> None:
    with session_factory.begin() as session:
        accounts = SqlAlchemyAccountRepository(session)
        source = accounts.get_for_update(command.source_id)
        target = accounts.get_for_update(command.target_id)
        source.transfer_to(target, command.amount)
```

The context above owns the transaction. The SQLAlchemy `Session` supplies ORM UoW and identity-map
behavior. Do not add a second abstraction unless it provides an application-owned boundary or
coordinates multiple repositories/resources.

After failed flush:

```python
try:
    session.flush()
except IntegrityError as error:
    session.rollback()
    raise DuplicateOrder(...) from error
```

Catch narrowly and translate only when callers need a stable application error.

## Concurrency

- Use one `Session` per thread and one `AsyncSession` per asyncio task.
- Select optimistic locking/version columns, constrained writes, or row locks from conflict and
  throughput requirements.
- Retry only failures documented as transient, with a bounded attempt/time budget.
- Make commands idempotent before retrying an entire transaction.
- Keep side effects outside retried transaction bodies or protect them with outbox/idempotency.

## JOIN and loading ownership

The repository/DAO owns:

- SQL JOIN clauses and predicates;
- `joinedload`, `selectinload`, subqueries, and projections;
- deduplication and mapping;
- pagination/order stability;
- database-specific limits.

The use case owns the semantic need: for example, “orders ready for publication with current
company tier.” It must not construct SQL.

Choose loading by measurement:

- joined load: one round trip but row multiplication;
- select-in: additional query and parameter-list limits, often good for collections;
- lazy load: convenient but can cause N+1 and unexpected async/closed-session I/O;
- explicit projection: best for read-shaped results and aggregates.

Verify generated SQL and query count in integration tests.

Primary reference:
https://docs.sqlalchemy.org/en/20/orm/session_basics.html
