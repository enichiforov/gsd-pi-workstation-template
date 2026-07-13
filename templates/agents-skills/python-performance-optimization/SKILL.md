---
name: python-performance-optimization
description: "Profile and optimize Python — dict/hashing cost and custom __hash__/__eq__, float vs Decimal, reference/identity semantics and is, object/connection pooling, memory cost, N+1 queries, choosing parallelization. Use for latency/throughput work, numeric-type choices, reusing expensive objects, or any make-it-faster request. Profile first."
---

# Python Performance Optimization

**Source:** @advice17 — #69 (dicts & hashing), #67 (float vs Decimal), #28 (references & `is`), #19 (object/connection pools), #29 (memory), #44 (N+1), #33 (parallelization & profiling), #34 (interpreter optimizations).

## When to Use

- Profiling / optimizing hot paths, latency or throughput work
- Choosing numeric types (float vs Decimal) for correctness+speed
- Understanding dict/hashability cost and custom `__hash__`/`__eq__`
- Reusing expensive objects (connection/session pools)
- Diagnosing memory growth or reference-identity bugs
- Any "make it faster" request

> First rule (#33): **profile.** There are many parallelization/optimization options; improving one metric often worsens another (asyncio helps connection count but can hurt response time). Measure on your real workload — behavior is often not what you assumed.

## 1. Dicts & hashing (#69)

A dict maps unique keys to values and must look up fast. Two implementations:
- **Balanced search tree** (red-black): needs only comparable keys (`<,>,=`), order stable for the key's life. (C++ `std::map`, Java `TreeMap`.)
- **Hash table** (Python `dict`, C++ `unordered_map`, Java `HashMap`): a hash function maps key data → bounded integer; equal keys → equal hash, unequal → whatever. Collisions are inevitable (more possible inputs than slots) and resolved via chaining or probing.

Requirements for hash-table keys:
- a hash is computable for each key,
- equal keys have equal hashes,
- the hash doesn't change (at least the part used in the hash) and thus doesn't break placement.

Python specifics:
- Many objects define equality by **identity**, so hashing can be based on memory address. `function`, `type`, generators → distinct instances never equal, trivial hash.
- A custom class gets default `__eq__`/`__hash__` by identity — but **if you define `__eq__` yourself, the auto `__hash__` disappears** (define `__hash__` too if you need it hashable).
- `tuple`/`list` define equality by contents → hash from contents; a **mutable** key (list) can't have a stable hash → unhashable.

## 2. float vs Decimal (#67)

`0.1 + 0.2 != 0.3` because binary float represents `0.1` only approximately (`Decimal(0.1)` = `0.1000000000000000055...`). `sys.float_info.epsilon` (~2.22e-16) is the smallest distinguishable step near 1.0. `Decimal` can use arbitrary precision (`getcontext().prec`) but still can't represent π, ⅓ (use `fractions.Fraction` for exact ratios). Trade-off:
- `float` is ~3× faster (hardware-accelerated: ~8.75 ns vs ~27.7 ns for add) and stores huge/tiny magnitudes cheaply.
- **Use `float`** unless you need decimal-exact math (accounting/money) → then **`Decimal`**. Never compare floats with `==`; compare within a tolerance.

## 3. References, mutability & `is` (#28)

A Python variable is a name pointing to an object; assignment repoints the name (old value lives on). Operations may mutate (`list.append`) or return new (`+` usually). `+=` = assignment + `__iadd__`, which differs for mutable (list, in-place) vs immutable (str, new object) — so `+=` both mutates *and* rebinds. Python uses **pass-by-object-sharing** (a.k.a. pass-by-assignment): the callee gets a reference to the same object, so **mutating** it is visible to the caller, but **rebinding** the parameter does not rebind the caller's name (it is not C++ pass-by-reference). Copy explicitly via `copy`/`__copy__`/`__deepcopy__`.
- `is` compares **identity** (same object), can't be overridden — use only when logic truly needs identity, or for `None`/`Enum` singletons.
- Don't use `is` for numbers/strings: interning (small ints, some strings) is an unguaranteed optimization; `is` on values is a classic bug source. Two `[]` are always distinct objects; two `1`s *may* be the same — don't rely on it.

## 4. Object & connection pools (#19)

For objects that are costly to initialize and repeatedly created/destroyed, use a **pool**: a prepared set of initialized objects requested and returned rather than recreated (eager or lazy; may manage lifetime/size/reset). Standard practice: create the pool **once at startup**, reuse everywhere (multiple pools if logic needs); don't recreate pools routinely. Prime case — network connections (TCP + TLS setup is slow, and many protocols keep the connection open):
- `requests.Session` (has a connection pool — don't use bare `requests`),
- `aiohttp.ClientSession` (init once, reuse),
- `psycopg2.pool`,
- SQLAlchemy `Engine` (pool with `pool_recycle`, pre-ping, `pool_size`; `NullPool` is pool-compatible but not pooling).

## 5. Memory cost (#29)

CPython frees objects by reference count; freeing does **not** immediately return RSS to the OS (memory grabbed in big blocks, released lazily) — so "memory didn't drop" ≠ leak. `gc.collect()` is usually pointless; `del` only drops a reference. Avoid `__del__`; use context managers for deterministic cleanup. (macOS M-series: page size 16 KB — don't hardcode 4096 in `vm_stat` math.)

## 6. N+1 as a performance bug (#44)

The most common DB slowdown: 1 query for parent rows + N queries for children (implicit lazy loading in ORMs). Choose an explicit loading strategy (joined / select-in / subquery) — see `python-database-patterns`. Watch row duplication in joined loads (esp. with BLOBs) and huge `IN (...)` lists in select-in loads (chunk them).

## 7. Interpreter reality (#34)

Each Python version adds some (historically few) interpreter optimizations. Don't micro-optimize speculatively; for CPU-bound numeric work, native libs (numpy) sidestep the GIL and dominate hand-tuned Python. Measure before and after.

## Anti-Patterns

- Optimizing without profiling; assuming the bottleneck.
- Comparing floats with `==`; using `Decimal` where `float` suffices (3× slower).
- Defining `__eq__` without `__hash__` on a class you put in a set/dict; using mutable objects as dict keys.
- `is` for value comparison (numbers/strings).
- Recreating connections/sessions per call instead of pooling; bare `requests` without `Session`.
- Manual `gc.collect()` / `del` as a "memory fix."
- Leaving ORM lazy-loading to cause N+1.

## References
- Posts #69, #67, #28, #19, #29, #44, #33, #34
- [0.30000000000000004.com](https://0.30000000000000004.com), [SQLAlchemy pooling](https://docs.sqlalchemy.org/en/20/core/pooling.html), [GIL](https://en.wikipedia.org/wiki/Global_interpreter_lock), [datamodel](https://docs.python.org/3/reference/datamodel.html)

## Pair With
- `python-database-patterns` — loading strategies, pools
- `python-async-concurrency-deep-dive` — concurrency trade-offs
- `code-optimizer` (bundled) — systematic perf audit
