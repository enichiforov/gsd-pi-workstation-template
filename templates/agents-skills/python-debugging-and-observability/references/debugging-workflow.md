# Debugging Workflow

## Reproduction record

Capture:

- exact command/entry point;
- input/event/message ID with sensitive values redacted;
- environment and dependency versions;
- expected and actual result;
- full exception chain or hang timeout;
- deterministic setup/cleanup;
- frequency and last-known-good version.

## Evidence tools

- Exceptions: full traceback, `__cause__`/`__context__`, locals only when safe.
- Hang: `faulthandler.dump_traceback_later`, task stacks, thread dump, process sample.
- Async: asyncio debug mode, `asyncio.all_tasks()`, task names/stacks.
- Memory: repeatable workload, `tracemalloc` snapshots, object ownership, native/RSS distinction.
- Resources: warnings for unclosed files/sockets/sessions, file descriptor counts, pool metrics.
- Imports/config: `sys.executable`, module path, cwd, relevant env key names.
- Database: SQL/query timing, transaction state, lock/wait evidence, failed-flush state.

Use `pdb`/breakpoints in a controlled reproduction, not as the only durable explanation.

## Hypothesis loop

Write:

```text
Hypothesis:
Predicted evidence:
Disproving result:
Minimal experiment:
Observed result:
```

Change one variable. Keep the failing artifact until the regression test reproduces the bug.

## Memory and cleanup

Do not infer a leak from RSS alone. Separate:

- intentionally retained cache/pool;
- live Python reference growth;
- cyclic garbage;
- native extension allocation;
- allocator fragmentation;
- OS page accounting.

Use explicit lifecycle/context managers. `del name` only removes one reference; it does not promise
resource closure or immediate OS memory return.
