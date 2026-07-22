# Async Tests

## Strict-mode fixtures

```python
import asyncio
from collections.abc import AsyncIterator

import pytest
import pytest_asyncio


@pytest_asyncio.fixture
async def client() -> AsyncIterator[Client]:
    async with Client.connect() as value:
        yield value


@pytest.mark.asyncio
async def test_fetches_user(client: Client) -> None:
    assert await client.fetch_user(1) == User(id=1)
```

Do not decorate an `async def` fixture with plain `@pytest.fixture` in pytest-asyncio strict mode.
Keep configured loop scope consistent with fixture/test scope.

## Task ownership

On Python 3.11+, use `TaskGroup` or keep explicit task references. On older supported Python, use a
documented AnyIO task group or explicit ownership. At teardown, assert no unexpected pending
tasks remain, cancel owned tasks, await them, and retrieve exceptions.

```python
task = asyncio.create_task(worker.run(), name="test-worker")
try:
    await ready.wait()
    await exercise_worker()
finally:
    task.cancel()
    with pytest.raises(asyncio.CancelledError):
        await task
```

## Timeouts and races

Bound awaits with a test timeout, `asyncio.wait_for`, or `asyncio.timeout` on Python 3.11+ so hangs
fail diagnostically. Coordinate races with `Event`/barriers:

```python
entered = asyncio.Event()
release = asyncio.Event()
```

Do not use arbitrary sleeps as synchronization. Test cancellation at meaningful await boundaries
and verify cleanup/rollback.

## Blocking calls

If an async test hangs the loop, inspect the production code for synchronous I/O/CPU before
increasing timeouts. A larger timeout is not a fix.
