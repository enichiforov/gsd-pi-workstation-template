---
name: python-async-concurrency-deep-dive
description: "Understand and debug Python concurrency — asyncio event loop/coroutines/Future/Task internals, multitasking models (preemptive/cooperative, 1:1/N:1/N:M, GIL), thread-safety & races, async construction (async factory instead of await in __init__), background/service supervision. Use for asyncio code, workers, background tasks, or diagnosing blocked/racing tasks."
---

# Python Async & Concurrency Deep Dive

**Source:** @advice17 — #71 (asyncio event loop via generators), #73 (asyncio callbacks/Future/Task/sockets), #32 (multitasking models), #33 (parallelization approaches), #18 (thread-safety & races), #30 (`__init__` isn't async), #54 (two-phase init for async), #17 (running in background).

## When to Use

- Writing/reviewing asyncio code, workers, or background tasks
- Explaining how the event loop actually works
- Choosing threads vs processes vs asyncio vs multiple servers
- Debugging "why did my task not run / block everything"
- Handling async construction (`__init__` can't `await`)
- Fixing concurrency races and shared-state bugs

## 1. Multitasking models (#32)

Concurrency = running several task sequences in one time span without waiting for others to finish. Two switch models:
- **Preemptive** — the runtime switches regardless of task logic (OS threads/processes).
- **Cooperative** — tasks signal where they can be interrupted (asyncio; historically MS-DOS).

App-level threading over OS threads (N:M naming):
- **1:1** (Python `threading`/`multiprocessing`) — OS schedules; no control over switch logic; needs synchronization; a hung task doesn't freeze others; can run arbitrary/native code in a thread.
- **N:1** (asyncio, JS async) — all app tasks in one OS thread; **can't use >1 CPU**; code must be `await`-aware; simpler sync, massive task counts; downside: one blocking call stalls everything.
- **N:M** (Go preemptive-ish, Rust cooperative) — uses all CPUs with some scheduling control; hard to embed native code.

The **GIL** blocks parallel Python bytecode (it protects refcounts) but not native libs (numpy).

## 2. The event loop as a generator driver (#71)

Mental model: a generator yields step-by-step when you call `next`; `yield from` transparently drives a nested generator from the same outer loop. asyncio is the same idea:
- **event loop** ≈ the outer `for` loop turning the crank,
- **coroutines** ≈ generators; `await` ≈ `yield`/`yield from`.
- `await`ing another coroutine → you "fall into" it (like `yield from`).
- `await`ing a special awaitable (a **Future**) → you `yield` control back to the loop, which can do other work until the Future is ready.
- Independent generators the loop can crank = **asyncio tasks**.

Summary: awaiting a Future hands control to the loop; awaiting a coroutine descends into it; when the loop has control it services other tasks or waits on the outside world.

## 3. Under the hood: callbacks, Future, Task (#73)

Lower than coroutines, the loop drives **synchronous callbacks**:
- The loop calls sync callbacks one at a time (`loop.call_soon`, or `loop.call_soon_threadsafe` from another thread); it also schedules delayed calls.
- **Future** stores a result; `set_result()` marks it done and **schedules** its done-callbacks via `loop.call_soon()` (they run on a later loop iteration, not synchronously inside the `set_result` call).
- **Task** is the glue between an async function (generator) and the loop: it registers itself as a callback; when run, it advances the coroutine one step; on hitting a Future it subscribes for that Future's result and returns control to the loop.
- Who completes a Future? another task/callback (`set_result`), another **thread** (`call_soon_threadsafe`, e.g. aiofiles/granian), or the **loop itself** (e.g. socket readiness).
- **Sockets:** the OS offers blocking and non-blocking modes; asyncio uses non-blocking + readiness polling (`select`/`epoll`/`kqueue`/IOCP). Since Python 3.7 `loop.sock_recv`/`sock_sendall` are `async def` **coroutine methods** you `await` (internally the loop uses Future-like waiters + readiness callbacks); on Linux the loop calls `epoll` between callbacks and completes the wait when I/O is ready. Same for pipes/subprocesses.

Summary: loop runs sync callbacks → Future holds result & fires callbacks → Task adapts a generator to callbacks and links Futures → loop polls sockets non-blockingly → Futures can be set from callbacks or other threads.

## 4. Thread-safety & races (#18)

Any shared mutable object touched from multiple threads/tasks can race. Threads switch almost anywhere; asyncio switches only at `await` (fewer races, not zero). Most reliable fix: **no shared mutable state**; else locks / compare-and-swap. Library facts:
- `requests.Session` — the source post calls it thread-safe for sending, but its mutable state (cookies/headers/pool) isn't an official guarantee → prefer one session per thread or synchronize access.
- `asyncio.Queue` — **not** thread-safe, but safe across asyncio tasks (use `call_soon_threadsafe` to cross thread↔loop).
- `sqlite3.Connection`, SQLAlchemy `Session` — not thread-safe; `Engine` is.
- GUI toolkits — single UI thread only.

## 5. Async construction: `__init__` can't await (#30, #54)

`__init__` is not `async`, so it must not touch the loop or call coroutines, and should avoid I/O / opening connections/files entirely. Don't paper over this with **two-phase init**:

```python
# ❌ can't await in __init__
class Gw:
    def __init__(self, uri):
        self.conn = await asyncpg.connect(uri)   # SyntaxError

# ⚠️ two-phase: object exists in a half-built state; conn may be None → extra guards
class Gw:
    def __init__(self):
        self.conn = None
    async def connect(self, uri):
        self.conn = await asyncpg.connect(uri)

# ✅ async factory: object is usable immediately after creation
class Gw:
    def __init__(self, conn):
        self.conn = conn

async def new_gw(uri) -> Gw:
    conn = await asyncpg.connect(uri)
    return Gw(conn)
```

Prefer an async factory / classmethod / abstract factory over multi-phase init; an object should be fully usable right after construction. Inject dependencies rather than building them in `__init__`.

## 6. Choosing a parallelization approach (#33)

Options span: distributed systems → server clusters → multiple processes → threads → asyncio tasks. Trade communication cost vs parallelism: heavy shared data → same process (shared memory, RAM-bound); independent work → many servers. Threads vs processes: processes add IPC cost (shared memory/pipes/sockets). CPU-bound → GIL matters unless native libs; massive network I/O → asyncio userspace switching beats OS thread switches. **Profile** in realistic configs; the right choice is workload-specific.

## 7. Running in the background (#17)

- One-off long command over SSH → `screen`/`tmux` (or `systemd-run`) so it survives disconnect.
- Long-running service → a supervisor: auto-start on boot, restart on crash, status, logs, resource limits. Linux: **systemd** (+ journald for logs), `systemd-timers` for periodic jobs (cron is emulated by systemd now). Containers (docker/podman) isolate the environment and ease distribution/scaling (k8s).
- (On macOS the equivalent supervisor is **launchd**, not systemd.)

## Anti-Patterns

- Blocking calls (sync I/O, `time.sleep`, CPU loops) inside a coroutine — stalls the whole N:1 loop.
- `await` in `__init__`; leaving objects in a half-initialized two-phase state.
- Sharing `asyncio` objects across threads without `call_soon_threadsafe`; sharing a `Session`/`sqlite3.Connection` across threads.
- Assuming asyncio eliminates race conditions.
- Picking threads/processes/asyncio without profiling.
- Building dependencies inside `__init__` instead of injecting them.

## References
- Posts #71, #73, #32, #33, #18, #30, #54, #17
- [PEP 3156 asyncio](https://peps.python.org/pep-3156), [PEP 380 yield from](https://peps.python.org/pep-0380), [asyncio tasks](https://docs.python.org/3/library/asyncio-task.html), [C10k](https://www.kegel.com/c10k.html)

## Pair With
- `python-debugging-and-observability` — races, concurrency debugging
- `python-performance-optimization` — concurrency trade-offs, pools
- `python-architecture-patterns` — factories, DI, two-phase init
