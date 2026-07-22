# Profiling Workflow

## Select the tool

- End-to-end latency and waiting: tracing/APM plus dependency spans.
- Production-safe CPU sampling: `py-spy` or platform profiler when allowed.
- Deterministic call profiling: `cProfile` for controlled reproductions.
- Line-level mixed CPU/memory: `scalene` or equivalent when installed.
- Python allocations: `tracemalloc` snapshots and diffs.
- Microbenchmark: `pyperf` or a statistically disciplined harness.
- Database: query log/tracing, `EXPLAIN (ANALYZE, BUFFERS)` where safe, query-count tests.

Do not install or run production profilers without authorization. Prefer existing observability
and a representative local/staging reproduction.

## Benchmark checklist

- define representative inputs and concurrency;
- control runtime/library versions and CPU/power conditions;
- separate cold start and steady state;
- warm caches/interpreter when the production path is warm;
- measure enough repetitions and report distribution/variance;
- prevent dead-code/fixture setup from dominating the measurement;
- compare identical correctness outputs;
- state noise and significance threshold.

## Memory investigation

1. Confirm growth with a repeatable workload.
2. Separate Python allocations, native allocations, caches/pools, fragmentation, and OS accounting.
3. Compare `tracemalloc` snapshots for Python allocation growth.
4. Inspect object ownership/reference chains where needed.
5. Verify cleanup and bounded caches.
6. Re-run over multiple cycles; do not use `gc.collect()` as the fix without an ownership cause.

## Report

Include command/tool, versions, workload, sample count, baseline distribution, changed code, new
distribution, correctness result, and remaining bottleneck.
