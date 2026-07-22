---
name: python-performance-optimization
description: "Profile and optimize Python latency, throughput, CPU, memory, and allocation with representative baselines and regression proof. Use for hot paths, slow services, memory growth, numeric-type choices, hashing/dicts, pooling, N+1 symptoms, or concurrency/runtime selection; route SQL loading details to python-database-patterns and correctness bugs to python-debugging-and-observability."
---

# Python Performance Optimization

Optimize a measured bottleneck while preserving correctness. Reject folklore, stable multipliers,
and microbenchmarks detached from the production workload.

## Workflow

1. **Define the target.** State latency percentile, throughput, CPU, memory, allocations, startup,
   or cost and the correctness constraints that cannot change.
2. **Build a representative baseline.** Fix inputs, environment, warmup, sample size, concurrency,
   and acceptance threshold. Record runtime/library/hardware versions.
3. **Choose evidence by resource.** Use sampling/call profiling for CPU, `tracemalloc`/heap tools
   for allocations, query tracing for DB, and end-to-end telemetry for waiting.
4. **Find the dominant bottleneck.** Separate CPU, blocking I/O, lock contention, database round
   trips, serialization, allocation, and external latency.
5. **Change one cause.** Prefer algorithm/data-access/lifecycle changes before syntax-level tuning.
6. **Re-measure.** Compare distributions and resource use, not a single best run.
7. **Run correctness and regression checks.** Keep the benchmark or performance test when the
   requirement is durable.

## Core rules

- Profile before and after.
- Optimize the production-shaped path, not an isolated operation unless it dominates that path.
- Use `Decimal` for decimal-exact requirements and `float` for binary floating-point workloads
  where its semantics are acceptable. Benchmark cost in the actual runtime.
- Use domain-derived tolerances for approximate comparisons. Exact `==` can be intentional for
  exactly representable values or sentinels.
- Keep hash/equality stable while an object is a dict/set key. Defining value equality changes
  hashability obligations.
- Use `is` for identity/singletons such as `None`, not value equality.
- Pool/reuse resources only at a scope permitted by thread/task safety and lifecycle. A global
  shared client is not automatically safe.
- Treat retained RSS as evidence to investigate, not proof of a Python leak.
- Route SQL JOIN/N+1/loading fixes to persistence ownership; verify generated SQL and query count.
- Select threads/processes/async only after classifying the bottleneck and measuring overhead.

## Load references selectively

- For benchmark design, CPU/memory/latency tools, and before/after proof, read
  [profiling-workflow.md](references/profiling-workflow.md).
- For numeric types, hashing, identity, pooling, memory, and concurrency trade-offs, read
  [python-performance-decisions.md](references/python-performance-decisions.md).
- For provenance and corrected claims, read
  [advice17-source-map.md](references/advice17-source-map.md).

## Output contract

Return:

1. metric, workload, and baseline;
2. profiler/telemetry evidence;
3. dominant cause;
4. smallest proposed change;
5. correctness risk;
6. before/after result and acceptance verdict.

If no representative measurement exists, report the measurement plan rather than claiming a
speedup.
