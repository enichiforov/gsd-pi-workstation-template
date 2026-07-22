# FastAPI Boundary

Keep FastAPI-specific objects and dependency declarations in the delivery adapter. Pass ordinary
commands, principals, ports, and results across the application boundary.

Callable dependencies are a supported FastAPI mechanism. Do not repeat the outdated absolute
claim that `Depends(real_provider)` is inherently not dependency injection. Evaluate coupling at
the boundary:

```python
from typing import Annotated

from fastapi import Depends


def get_service() -> OrderService:
    ...


@router.post("/orders")
def create_order(
    request: CreateOrderRequest,
    service: Annotated[OrderService, Depends(get_service)],
) -> OrderResponse:
    result = service.create(request.to_command())
    return OrderResponse.from_result(result)
```

Override the original dependency callable in tests and restore overrides after the test:

```python
missing = object()
previous = app.dependency_overrides.get(get_service, missing)
app.dependency_overrides[get_service] = lambda: fake_service
try:
    response = client.post("/orders", json=payload)
finally:
    if previous is missing:
        app.dependency_overrides.pop(get_service, None)
    else:
        app.dependency_overrides[get_service] = previous
```

Prefer a fresh application instance per test. Do not mutate one app's override dictionary from
concurrently executing tests; the mapping is application-wide.

Prefer a separate composition function when providers require environment-specific policy,
lifetimes, or cleanup. Avoid importing framework dependencies into domain models or use cases.

Current primary sources:

- https://fastapi.tiangolo.com/tutorial/dependencies/
- https://fastapi.tiangolo.com/advanced/testing-dependencies/
