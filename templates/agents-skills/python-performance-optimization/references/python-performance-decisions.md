# Python Performance Decisions

## Numeric types

Choose from correctness first:

- `float`: binary floating point, hardware-fast, approximate for many decimal fractions;
- `Decimal`: decimal arithmetic with explicit context/rounding, commonly slower;
- integer minor units: useful for fixed-scale amounts when range/rounding rules are explicit.

Do not preserve a “3x” multiplier across Python versions, hardware, operations, or precision
contexts. Benchmark representative operations.

## Dicts and hashing

Dict/set average lookup depends on stable `__hash__` and compatible `__eq__`:

```python
if left == right:
    assert hash(left) == hash(right)
```

Do not mutate fields that participate in hashing while the object is a key. Measure expensive
custom hashing only if profiles show it matters.

## Identity and mutation

Assignment rebinds a name; mutation changes an object. Use `is` only when object identity is the
question. Avoid copying merely to “be safe”; define ownership and mutation contracts.

## Pooling

Reuse expensive clients/connections when:

- construction dominates;
- the library documents safe sharing for the chosen scope;
- pool bounds, timeouts, health checks, and cleanup are configured;
- credentials/configuration do not require narrower isolation.

Prefer one session/client per thread/task when the object is mutable or undocumented for sharing.

## Database symptoms

N+1, over-fetching, row multiplication, missing indexes, lock waits, and chatty transactions are
database/data-access concerns even when Python latency exposes them. Fix them in repository/DAO
queries and verify with SQL/query-count evidence.
