---
name: python-debugging-and-observability
description: "Add logging/observability and debug Python — logging module hierarchy & handlers, exception-handling discipline, memory management (refcount/gc/__del__), injection-safe string formatting (SQL/shell/HTTP), race conditions, abstract classes vs Protocol interfaces. Use when adding logging, reviewing try/except, diagnosing memory or concurrency bugs, or fixing injection issues."
---

# Python Debugging & Observability

**Source:** @advice17 — #36 (logging), #23 (exception handling), #29 (memory management), #10 (string formatting & injection safety), #58 (abstract classes vs interfaces / Protocol), #18 (race conditions), #33/#32 (concurrency).

## When to Use

- Adding logging/observability to a service or agent
- Reviewing `try/except` blocks and error handling
- Diagnosing memory growth, leaks, or `__del__` surprises
- Fixing SQL/shell/HTTP injection or "works until the input has a quote" bugs
- Debugging race conditions in threaded/asyncio code
- Choosing between abstract classes and `Protocol`

## 1. Logging as infrastructure (#36)

Logging crosses every layer (including third-party code) and is **not** business logic — it collects diagnostics.
- Use the stdlib `logging` module so third-party libs integrate. If you write a **library**, only *get* a logger and use it — never configure logging in a library.
- Group logs via the logger hierarchy (dotted names). Default to `logger = logging.getLogger(__name__)`.
- Configure logging in the **infrastructure layer** (start of `main`), not scattered around.
- `logging` separates **logger** (write interface) from **handler** (where/how), with a **formatter** (text form) and optional **filter** (beyond level). You can change destinations (file, stream, queue) without touching call sites.
- Destination by app type:
  - GUI apps → file or system journal (no terminal).
  - Console scripts → may also write to `stderr`.
  - **Long-running server daemons** (possibly multiple copies) → write to **stdout/stderr** and let the external system collect them (journald, docker, ELK). File logging breaks with rotation + multiple processes.

Agent-first observability adds: health/status surfaces, persisted failure state (last error, phase, timestamp, retry count), and explicit failure modes — never log secrets.

## 2. Exception handling (#23)

Per line, exceptions are either **expected** (you know it can happen and how to react) or **unexpected** (a code bug, no strategy). Therefore:
1. Always name the exception you catch — if you don't know what can be raised, you don't know if your handling is correct.
2. Catch the **most specific** class.
3. Wrap the **smallest** possible code in `try` (split expressions if needed).
4. Handle exceptions **where you have enough information** to decide.

Avoid:
- Bare `except:` / `except Exception` — bare catches include `KeyboardInterrupt` (which should end the program). `except Exception` is legitimate only at framework level (return HTTP 500, retry queue message) — and re-raise if you can't truly handle it.
- Silently replacing an exception with a sentinel return value — in Python prefer exceptions over error-code plumbing.

For adapters (DB/external services): introduce **your own exception classes**. Don't leak a vendor library's exception types out of the adapter (they reveal implementation and break when you swap it), and re-map detail level (many network errors → one "service unavailable"; one vendor error in different spots → different meanings to callers).

## 3. Memory management & lifecycle (#29)

CPython frees an object when it has no live references (or only cyclic ones), via reference counting (what the GIL protects) plus a cyclic collector.
- `del name` removes a **reference** (variable, dict key, list slice) — it does **not** delete the object. Rarely needed; prefer scoping the variable to a smaller function.
- `__del__` runs on object deletion — **almost never override it**; timing is unknown and it may not run at all (e.g. at interpreter shutdown). Use **context managers** for finalization.
- The `gc` module manages the *cyclic* collector; disabling it doesn't affect refcount-based freeing, and manual `gc.collect()` is usually pointless.
- Freeing Python objects does **not** immediately shrink process RSS — CPython grabs OS memory in big blocks and returns them lazily. (On macOS M-series, remember pages are 16 KB, not 4 KB, when computing RAM.)

## 4. Injection safety / string formatting (#10)

Formatting text *for a computer* (SQL, HTML, JSON, shell, URL, regex) by interpolation breaks on special characters and enables injection. Switching f-string ↔ `.format` ↔ `%` changes nothing. Use the safe API:

```python
# SQL — parameters, not interpolation (placeholder depends on driver)
cur.execute("SELECT * FROM users WHERE login = ?", (login,))

# HTTP — params dict
requests.get("http://site.com", params={"search": query})

# Shell — arg list, no shell=True
subprocess.run(["ls", dirname])

# HTML — a real templating engine (jinja), which auto-escapes
```

## 5. Race conditions in concurrent code (#18)

Any shared object touched from multiple threads/asyncio tasks can hit a race — behavior depends on interleaving. With threads a switch can happen almost anywhere; with asyncio only at `await` (fewer, not zero). Example that yields random `counter` values under threads:

```python
counter = 0
def do():
    global counter
    if counter < 1:
        sleep(0.01)      # switch point
        counter += 1
```

Mitigations: locks, compare-and-swap — but the most reliable is **no shared mutable state**. Library thread-safety varies: the source post calls `requests.Session` thread-safe for sending requests, but its state (cookies/headers/connection pool) is mutable and not officially guaranteed thread-safe — prefer **one session per thread** or synchronize access; `asyncio.Queue` is not thread-safe but is safe across asyncio tasks; `sqlite3.Connection` and SQLAlchemy `Session` are not thread-safe (Engine is); GUI toolkits are single-threaded. Check per object.

## 6. Concurrency models — know what you're debugging (#32, #33)

- **Preemptive** (OS threads/processes) vs **cooperative** (asyncio, switches only at `await`).
- **1:1** (threading/multiprocessing) — OS schedules; no switch-logic control; needs synchronization; a hung task doesn't block others; can embed arbitrary/native code.
- **N:1** (asyncio) — one OS thread; can't use >1 CPU; needs `await`-aware code; huge task counts, simpler sync.
- **N:M** (Go/Rust) — utilizes all CPUs with some scheduling control.
- GIL blocks parallel Python bytecode but not native libs (numpy). When choosing a parallelization approach, **profile** on your real workload — improving one metric (throughput) often worsens another (latency).

## 7. Abstract classes vs interfaces (#58)

- **Abstract class** — a class blueprint with some concrete + some abstract methods; can't be instantiated directly; subclass must fill the abstract methods.
- **Interface** — the *requirements* an object must meet (method names, params, result types); may not exist as a named entity. In Python it's structural: a function needing `.foo()` and `.bar()` defines an implicit interface. Express it with `typing.Protocol`; implementing it just means having the methods (inheriting from it only helps error-finding). This is how you make DIP abstractions in Python.

## Anti-Patterns

- Configuring `logging` inside a library or scattering `basicConfig` across modules.
- `except:` / broad `except Exception` that swallows and continues without re-raising.
- Adding `try/except` to suppress an undiagnosed error (fix the root cause).
- Overriding `__del__` for cleanup instead of a context manager.
- `subprocess.run(f"cmd {x}", shell=True)` / f-string SQL.
- Sharing a mutable object across threads without synchronization; assuming asyncio removes races.
- Logging secrets/tokens.

## References
- Posts #36, #23, #29, #10, #58, #18, #32, #33
- [logging cookbook](https://docs.python.org/3/howto/logging-cookbook.html), [12factor logs](https://12factor.net/logs), [PEP 544 Protocols](https://peps.python.org/pep-0544/), [race condition](https://ru.wikipedia.org/wiki/Состояние_гонки)

## Pair With
- `python-architecture-patterns` — where exceptions/logging belong by layer
- `python-async-concurrency-deep-dive` — asyncio internals
- `observability` (bundled) — agent-first observability checklist
