# Runtime Topology

## Component ownership

| Component | Owns | Must not own by default |
|---|---|---|
| Application/use cases | Business behavior and authorization decisions | HTTP parsing, TLS, process supervision |
| Web framework | Routing, request/response adaptation, framework hooks | Durable business state |
| WSGI/ASGI application server | Connections, worker processes, timeouts, lifespan | Domain retries and authorization |
| Supervisor/orchestrator | Start, restart, health, resources, rollout | Request-level business behavior |
| Reverse proxy/load balancer | TLS termination, routing, buffering, edge limits | Object-level authorization |
| CDN/static server | Cacheable/static delivery | Dynamic domain decisions |

Co-location does not merge responsibilities. A single binary may perform several roles, but make
ownership explicit before configuring timeouts, retries, and logging.

## Protocol selection

Start with the interaction:

- request/response API: HTTP with an established API style;
- bidirectional long-lived messaging: WebSocket or a suitable messaging protocol;
- asynchronous commands/events: a broker protocol with explicit delivery semantics;
- streaming bytes: an established streaming protocol before raw TCP;
- unreliable low-latency datagrams: UDP only when loss/reordering is part of the design.

Raw TCP is a byte stream, not a message protocol. If it is chosen, specify framing, maximum frame
size, version negotiation, authentication, encryption, timeouts, backpressure, partial reads,
half-close, retry, and compatibility tests.

Avoid version-frozen statements about HTTP transports. Verify current server, client, and proxy
support in their official documentation.

## Lifecycle

At startup:

- validate required configuration once;
- build the dependency graph and reject cycles;
- establish only resources whose startup failure should make the process unready;
- run schema compatibility checks without mutating production implicitly.

At shutdown:

- stop accepting new work;
- mark readiness false;
- drain within a bounded deadline;
- cancel remaining task groups cooperatively;
- close clients, pools, telemetry, and servers deterministically.

Keep liveness shallow. Make readiness reflect whether the instance can safely receive new work.
