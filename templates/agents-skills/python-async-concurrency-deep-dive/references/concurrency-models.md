# Concurrency Model Selection

| Work | Default candidate | Check before choosing |
|---|---|---|
| Many native async I/O operations | asyncio | Library is truly async; no blocking callbacks |
| Blocking I/O library | Thread/offload | Thread safety, cancellation, pool bounds |
| Pure-Python CPU | Process/external worker | Serialization, startup, memory, deployment |
| Native code releasing the GIL | Threads or processes | Benchmark real workload |
| Durable/retryable job | External queue/worker | Delivery, idempotency, visibility |
| Shared mutable GUI state | Framework event thread | Cross-thread handoff API |

## Ownership

Prefer one owner for mutable state and send messages/commands to it. If sharing:

- document which threads/tasks/processes may access it;
- use the primitive valid for that context;
- keep critical sections small;
- never assume the GIL makes compound operations atomic;
- test the race with barriers/events, not sleeps.

`asyncio.Queue` is for tasks on one event loop and is not thread-safe. Cross a thread boundary with
documented thread-safe loop methods or a dedicated bridge. Process memory is not shared unless a
specific IPC/shared-memory mechanism says otherwise.

## Async construction

```python
class Client:
    def __init__(self, connection: Connection) -> None:
        self._connection = connection

    @classmethod
    async def connect(cls, settings: Settings) -> "Client":
        return cls(await open_connection(settings))
```

Prefer an async context manager when construction and cleanup form one lifecycle.
