# Observability and Error Boundaries

## Structured events

Emit one event per meaningful state transition, not a prose stream:

```python
logger.info(
    "publication_completed",
    publication_id=str(publication_id),
    tier=tier,
    duration_ms=duration_ms,
)
```

Follow the repository convention: for example, use `structlog` for application events when the
project requires it, while standard-library logging may remain the configured backend.

Include bounded outcome states and durations. Avoid duplicate logging at every layer; log where the
event has enough semantic context and ownership.

## Metrics and traces

Use metrics for aggregates/SLOs:

- operation count by bounded outcome;
- duration histogram;
- queue depth/age;
- retry/dead-letter count;
- pool utilization;
- readiness state.

Use traces for one request/job across boundaries. Propagate correlation context explicitly across
queues and workers. Keep user/object IDs out of metric labels.

## Exception boundaries

Expected absence may be a result type, `None`, or a named exception according to the API contract.
Unexpected provider errors should surface unless the owning loop has a tested recovery policy.

```python
try:
    payload = provider.fetch(identifier)
except ProviderNotFound as error:
    raise CompanyNotFound(identifier) from error
```

Do not invent custom wrappers when callers can and should handle the original error unchanged.

## Injection-safe construction

- SQL: driver/SQLAlchemy parameters and expression APIs.
- Subprocess: argv list without a shell by default.
- JSON: serializer.
- URL/query: URL builder/`urlencode`.
- HTML: template/context-specific encoder with autoescape enabled.
- Regex: `re.escape` only when literal matching is intended.

## Health

Liveness asks whether the process should be restarted. Readiness asks whether it can safely accept
new work. Keep dependency checks bounded and avoid cascading load. Expose degraded/blocked state in
domain-meaningful operational signals when the loop owns recovery.
