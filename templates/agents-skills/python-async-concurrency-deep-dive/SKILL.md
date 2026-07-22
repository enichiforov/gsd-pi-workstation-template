---
name: python-async-concurrency-deep-dive
description: "Implement and debug Python asyncio and concurrency: event-loop blocking, coroutine/Future/Task behavior, structured concurrency, cancellation and timeouts, graceful shutdown, task/thread/process ownership, race conditions, async factories, executor boundaries, and orphan background tasks. Use for asyncio services, workers, hangs, races, leaked tasks, or concurrency-model choices."
---

# Python Async and Concurrency

Choose concurrency from workload and ownership. Debug with task/runtime evidence, not scheduler
folklore.

## Workflow

1. **Classify the workload.** Separate CPU work, blocking I/O, native async I/O, shared state, and
   durable jobs.
2. **Map execution contexts.** Record the supported Python/runtime version, event loops, tasks,
   threads, processes, external workers, queues, and which context owns each mutable object.
3. **Reproduce under observability.** Enable asyncio debug mode when appropriate; capture task
   stacks, slow callbacks, thread/process stacks, resource warnings, and timing.
4. **Find blocking and un-awaited work.** Look for synchronous I/O/CPU on the loop, missing
   `await`, forgotten coroutine objects, orphan tasks, and callbacks that raise silently.
5. **Define cancellation and timeout ownership.** Put deadlines at operation boundaries, use
   structured task groups, propagate cancellation, and clean up in `finally`/context managers.
6. **Fix shared-state races.** Prefer ownership/message passing. Otherwise use the primitive
   documented for that execution context; asyncio primitives are not thread-safe.
7. **Offload deliberately.** Use threads for blocking calls with thread-safe dependencies,
   processes/native code for measured CPU bottlenecks, and external workers for durable work.
8. **Verify shutdown and failure.** Test cancellation at every await boundary, child failure,
   timeout, loop shutdown, resource cleanup, and task exception retrieval.

## Core rules

- Never block the event-loop thread with synchronous network/file/database calls or sustained CPU.
- Keep one SQLAlchemy `AsyncSession` per task; do not share mutable clients without documented
  safety.
- On Python 3.11+, use `asyncio.TaskGroup` or another structured owner for related tasks. On older
  supported Python, use a documented AnyIO task group or explicit owned tasks with cancellation
  and exception collection. Keep references to every intentionally detached task.
- Treat cancellation as normal control flow. Re-raise `CancelledError` after cleanup unless the
  boundary deliberately converts it.
- Use `asyncio.timeout` on Python 3.11+ or `wait_for`/a documented library deadline on older
  supported versions at the boundary that owns the deadline. Avoid stacked, conflicting timeouts.
- Use `asyncio.to_thread` only for blocking callables whose dependencies can safely run in that
  thread. Cancellation does not forcibly stop the underlying thread.
- Do not use `asyncio.create_task` as a durable queue.
- Keep `__init__` synchronous and leave the object usable; use an async factory/context manager
  for acquisition.
- Do not assign a universal scheduler model to a language. Verify the selected runtime/library.

## Load references selectively

- For blocked loops, task stacks, cancellation, TaskGroup, timeout, and shutdown checks, read
  [asyncio-diagnostics.md](references/asyncio-diagnostics.md).
- For threads/processes/async/external-worker selection and race ownership, read
  [concurrency-models.md](references/concurrency-models.md).
- For restart-safe durable jobs, queues, replicas, and deployment topology, use
  `python-web-service-runtime`.
- For provenance and corrected historical claims, read
  [advice17-source-map.md](references/advice17-source-map.md).

## Output contract

Return:

1. workload, supported Python/runtime version, and execution-context map;
2. evidence for the observed failure;
3. state/resource owner;
4. cancellation/timeout/shutdown contract;
5. smallest fix;
6. deterministic verification.

Do not recommend async, threads, or processes without relating the choice to the measured workload.
