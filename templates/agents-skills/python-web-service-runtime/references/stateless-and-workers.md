# Stateless Processes and Durable Workers

## Restart and replica checklist

For each operation, verify:

- restart immediately before and after each durable write;
- duplicate delivery with the same idempotency key;
- two concurrent deliveries for the same aggregate;
- alternating requests across replicas with no sticky-session assumption;
- worker crash after the external effect but before acknowledgement;
- shutdown while work is queued, running, or committing.

## State classification

| State | Default owner | Required property |
|---|---|---|
| Business entity or workflow progress | Database/durable store | Survives restart and replica change |
| Durable job | Queue plus job store when needed | Observable delivery and retry contract |
| Signed client token | Client plus signing verifier | Integrity, bounded lifetime, accepted revocation window |
| Encrypted client token | Client plus decrypting verifier | Confidentiality only when required, plus integrity |
| Server-side session/revocation state | Shared durable store | Immediate revocation/idle expiry when required |
| Cache | Process or shared cache | Safe loss, bounded staleness |
| Metrics | Telemetry backend | Process labels and aggregation |
| Pool/client | One scope allowed by thread/task-safety | Deterministic cleanup |

Do not convert a process-local dictionary into a fake database. Do not put configuration that
changes business behavior into mutable routing registries.

## Durable handoff

Avoid:

```python
asyncio.create_task(generate_report(report_id))
```

Prefer a durable handoff:

```python
await jobs.enqueue(
    GenerateReport(report_id),
    idempotency_key=f"report:{report_id}",
)
```

Define:

- who writes the job and the related domain change atomically;
- how duplicates are recognized;
- retryable versus terminal failures;
- backoff, attempt limit, dead-letter policy, and operator visibility;
- cancellation and expiry;
- the acknowledgement point.

Use a transactional outbox when a database commit and message publication must not diverge.
Use claim/checkpoint transactions for long external work. Avoid holding a database transaction
open while waiting on a provider. If a deliberately required invariant cannot use an outbox,
saga, or checkpoint design, state lock duration, timeouts, failure coupling, retries, and why the
coupling is safe.

For cookie/token/session and revocation design, use
`python-authentication-and-authorization`. A signature provides integrity, not confidentiality;
a self-contained token needs short lifetimes or shared revocation/version checks when immediate
revocation or server-enforced idle expiry is required.

## In-memory exceptions

Allow process-local state only when loss and divergence are acceptable and tested, such as:

- bounded caches with a durable source of truth;
- connection pools and clients scoped by safety guarantees;
- metrics buffers with an accepted loss window;
- per-request/task state;
- leader-election handles backed by an external coordination system.

Document the assumption that makes the exception safe.
