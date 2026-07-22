# Python Language Design Decisions

## Explicit state

Mutable globals make initialization order, tests, concurrency, and multiple configurations hard.
Inject or own mutable state. Module-level immutable constants and composition-root factories are
fine when their lifecycle is truly process-wide and deterministic.

## Object versus mapping

Use a typed object/record when field names and meanings are known. Use a mapping for a dynamic key
set or homogeneous lookup. Convert external mappings at the boundary instead of passing loosely
typed dictionaries across every layer.

## Visibility

- `name`: supported public API when exported/documented.
- `_name`: non-public convention; still accessible for tooling/testing.
- `__name`: name mangling for subclass-collision avoidance, not access security.

Curate package APIs with explicit exports when the project follows that convention.

## Constructors and factories

Keep `__init__` deterministic and leave the instance valid. Avoid hidden network/database I/O and
half-initialized flags. Use a factory for acquisition or conversion:

```python
class Client:
    def __init__(self, transport: Transport) -> None:
        self._transport = transport

    @classmethod
    async def connect(cls, settings: ClientSettings) -> "Client":
        transport = await open_transport(settings)
        return cls(transport)
```

## Nested definitions and closures

Nested functions/classes are not inherently untestable, but they cannot be imported and tested in
isolation directly and are recreated per call. Use them for genuine closures and small callbacks.
Lift them to module scope or an explicit stateful object when reuse, direct tests, or clear mutable
state ownership matters.

## Python decorators

Use decorators for declaration-time cross-cutting behavior with a documented callable contract.
Preserve metadata:

```python
from collections.abc import Callable
from functools import wraps
from typing import ParamSpec, TypeVar

P = ParamSpec("P")
R = TypeVar("R")


def traced(function: Callable[P, R]) -> Callable[P, R]:
    @wraps(function)
    def wrapper(*args: P.args, **kwargs: P.kwargs) -> R:
        record_call(function.__qualname__)
        return function(*args, **kwargs)

    return wrapper
```

Avoid decorators that secretly require a parameter name, install uncontrolled global state, or
hard-wire an optional cache/provider. Use an injected object decorator when configuration,
lifetime, or test substitution varies.

## DTO and anti-corruption boundaries

Transport/schema validation is legitimate at a boundary. Keep business invariants in domain/use
case logic. Do not force one Pydantic/vendor schema to serve HTTP, persistence, provider, and
domain concerns simultaneously.

Use an ACL adapter with separate responsibilities when needed:

- client facade calls the provider;
- translator maps provider data/errors;
- adapter implements the application-owned port.
