# Asyncio Diagnostics

## Evidence

Use development-only debug facilities where appropriate:

```bash
PYTHONASYNCIODEBUG=1 python -X dev -m app
```

Inspect live tasks:

```python
for task in asyncio.all_tasks():
    print(task.get_name(), task.done(), task.get_stack())
```

Also inspect slow-callback warnings, un-awaited coroutine warnings, never-retrieved task exceptions,
open transports, and resource warnings. Add task names and correlation identifiers.

## Structured concurrency

The standard-library example requires Python 3.11+:

```python
async with asyncio.TaskGroup() as group:
    prices = group.create_task(load_prices(), name="load-prices")
    news = group.create_task(load_news(), name="load-news")
```

If a child fails, the group cancels siblings and raises an exception group. Handle only failures
the boundary can resolve. Do not catch `Exception` merely to keep partially valid work running.
For Python 3.10 or older supported runtimes, use a documented AnyIO task group or explicitly own,
cancel, await, and collect exceptions from every created task.

## Deadlines and cancellation

`asyncio.timeout` requires Python 3.11+:

```python
async with asyncio.timeout(10):
    await publish()
```

On older supported Python, use `asyncio.wait_for(publish(), timeout=10)` or a documented library
deadline and account for its cancellation semantics.

Clean up and re-raise cancellation:

```python
try:
    await operation()
except asyncio.CancelledError:
    await cleanup()
    raise
```

Use `shield` only when an inner operation must outlive caller cancellation and another owner will
observe it. A shielded coroutine without ownership becomes an orphan.

## Graceful shutdown

1. Stop accepting new work.
2. Signal task owners.
3. Let bounded in-flight work finish.
4. Cancel remaining task groups.
5. Await cancellation and collect exceptions.
6. Close servers, clients, pools, async generators, and telemetry.
7. Exit after a bounded deadline.

Test shutdown while each external await is pending.
