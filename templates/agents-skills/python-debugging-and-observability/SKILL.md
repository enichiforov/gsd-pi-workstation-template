---
name: python-debugging-and-observability
description: "Diagnose Python failures and design actionable observability: reproducible debugging, tracebacks and task/thread evidence, structured logging, correlation context, metrics/traces, exception boundaries, resource cleanup, safe machine-format construction, and failure-state health signals. Use for crashes, hangs, wrong results, memory/resource symptoms, logging/telemetry gaps, or try/except reviews."
---

# Python Debugging and Observability

Move from symptom to reproducible evidence to the smallest causal fix. Add telemetry that answers
operational questions without leaking secrets or duplicating events.

## Workflow

1. **Define the symptom precisely.** Record expected/actual behavior, scope, first known occurrence,
   frequency, impact, and relevant versions.
2. **Build the smallest reliable reproduction.** Preserve the failing input and boundary; remove
   unrelated systems only after proving they are unrelated.
3. **Capture evidence before changing code.** Collect full traceback/cause chain, logs with
   correlation context, task/thread stacks, dependency timings, resource warnings, and state
   snapshots safe to retain.
4. **Form one falsifiable hypothesis.** Predict what evidence will change if it is true.
5. **Instrument the narrow boundary.** Add temporary or durable signals with an explicit owner and
   cardinality/privacy limits.
6. **Fix the cause.** Change the smallest behavior or ownership boundary; do not mask it with broad
   exception handling, retries, `gc.collect()`, sleeps, or fallbacks.
7. **Prove and guard.** Re-run the reproduction, add a regression test, and verify telemetry now
   distinguishes success, expected absence, retryable failure, and terminal failure.

## Core rules

- Catch the narrowest expected exception around the smallest operation.
- Preserve causes with bare `raise` or `raise DomainError(...) from error`.
- Translate exceptions only at a boundary whose callers need a stable error contract.
- Catch `Exception` at a framework/worker boundary only to report/contain failure; do not silently
  continue invalid work. Never swallow cancellation or process-exit signals accidentally.
- Emit application events through the repository's logging abstraction. Libraries must not
  configure global handlers.
- Attach correlation/request/job ID, operation, target identifiers safe to log, outcome, duration,
  and error class. Do not log credentials, tokens, secrets, or unnecessary personal data.
- Use parameterized/structured APIs for SQL, subprocess argv, URLs, JSON, and HTML. String-format
  choice does not prevent injection; HTML templating requires contextual escaping enabled.
- Use context managers and explicit close/shutdown for deterministic cleanup; do not rely on
  `__del__`.
- Keep metric labels bounded. Put high-cardinality identifiers in logs/traces, not metric labels.
- Define health/readiness from the service's ability to do work, not merely that the process exists.

## Load references selectively

- For reproduction, tracebacks, stacks, memory/resource evidence, and hypothesis testing, read
  [debugging-workflow.md](references/debugging-workflow.md).
- For structured logging, metrics, traces, exception mapping, injection-safe construction, and
  health signals, read [observability-and-errors.md](references/observability-and-errors.md).
- For provenance and qualified claims, read
  [advice17-source-map.md](references/advice17-source-map.md).
- Use `python-async-concurrency-deep-dive` for loop/task races and cancellation; use
  `python-performance-optimization` for profiling a proven performance problem.

## Output contract

Return:

1. precise symptom and reproduction;
2. evidence;
3. hypothesis and falsification check;
4. root cause;
5. smallest fix;
6. regression test;
7. durable observability change, if justified.

Label uncertainty explicitly. Do not report correlation as a confirmed cause.
