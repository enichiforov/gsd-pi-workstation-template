---
name: python-web-service-runtime
description: "Design and review restart-safe Python web-service and bot runtimes: stateless processes, horizontal scaling, durable background work, framework/application-server/proxy boundaries, WSGI/ASGI deployment, and protocol selection. Use when a FastAPI/Django/Flask/aiohttp service or Telegram bot must survive restarts, concurrent delivery, multiple replicas, queues, workers, or production deployment."
---

# Python Web Service Runtime

Design from failure and ownership boundaries, not from a framework diagram.

## Workflow

1. **Name the externally visible operation.** Identify its request/event, durable effects,
   response or acknowledgement, latency target, and delivery guarantees.
2. **Run the three-process tests.** Ask whether behavior remains correct after a restart after
   every event, concurrent event delivery, and alternating delivery across replicas.
3. **Classify every piece of state.**
   - Keep only disposable caches, pools, metrics, and process-local coordination in memory.
   - Put business state and resumable progress in a durable external system.
   - State any deliberate loss window for buffered data.
4. **Separate request work from durable work.** Finish bounded request work inline. Hand durable
   or retryable work to a queue/scheduler/worker with explicit idempotency and delivery semantics.
   Do not represent a business job with an untracked `asyncio.create_task()`.
5. **Draw the actual runtime chain.** Distinguish application code, framework, application
   server, supervisor/orchestrator, reverse proxy/load balancer, and static/CDN layers. Assign
   TLS, timeouts, buffering, retries, health checks, and shutdown ownership once.
6. **Choose a protocol from interaction requirements.** Prefer a mature high-level protocol.
   Do not invent framing, authentication, retry, and compatibility rules over raw TCP without a
   demonstrated requirement.
7. **Define lifecycle behavior.** Specify startup validation, readiness, graceful shutdown,
   draining, cancellation, connection cleanup, and deployment order.
8. **Verify operationally.** Test restart, duplicate delivery, concurrent delivery, replica
   alternation, dependency outage, worker crash, and shutdown during in-flight work.

## Core rules

- Keep routing and dependency wiring deterministic at startup; load changing business state at
  operation time.
- Treat process memory as disposable unless loss is an explicit, tested trade-off.
- Keep request handlers thin: parse, authenticate at the boundary, invoke a use case, translate
  the result.
- Keep a database transaction shorter than external network, object-storage, LLM, or Telegram
  I/O. Use claim/checkpoint/outbox patterns when work crosses boundaries.
- Make queue semantics explicit: at-most-once, at-least-once, or effectively-once through
  idempotency. A queue alone does not guarantee exactly-once effects.
- Scale web processes, workers, and schedulers independently. Do not start one global scheduler
  inside every web replica.
- Configure framework development servers only for development unless their current official
  documentation explicitly supports the production topology.
- Treat retries at multiple layers as multiplicative. Assign one owner and a bounded budget.

## Load references selectively

- For restart, replica, queue, and state decisions, read
  [stateless-and-workers.md](references/stateless-and-workers.md).
- For WSGI/ASGI, server, supervisor, proxy, and CDN ownership, read
  [runtime-topology.md](references/runtime-topology.md).
- For FastAPI dependencies and test overrides, read
  [fastapi-boundary.md](references/fastapi-boundary.md).
- For provenance and qualified channel claims, read
  [advice17-source-map.md](references/advice17-source-map.md).

## Output contract

Return:

1. the requested operation and guarantees;
2. a state-ownership table;
3. the runtime component chain and ownership boundaries;
4. failure/restart/replica risks;
5. the smallest justified design;
6. concrete verification scenarios.

Mark unknown delivery, persistence, and authorization requirements instead of inventing them.
