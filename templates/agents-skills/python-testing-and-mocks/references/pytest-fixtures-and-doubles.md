# Pytest Fixtures and Test Doubles

## Double taxonomy

- **Stub:** returns configured data; no behavioral simulation.
- **Fake:** working simplified implementation, such as an in-memory repository.
- **Mock:** verifies specified interactions.
- **Spy:** delegates to real behavior while recording calls.
- **Patch/monkey-patch:** mechanism that replaces/mutates a name; not itself a spy.

Type-correct fake:

```python
class FakeUserRepository:
    def __init__(self, users: Iterable[User] = ()) -> None:
        self._users = {user.id: user for user in users}

    def find(self, user_id: UserId) -> User | None:
        return self._users.get(user_id)
```

## Patch where looked up

Given:

```python
# app/service.py
from app.provider import fetch_user


def handle(user_id: int) -> User:
    return fetch_user(user_id)
```

Patch `app.service.fetch_user`, not `app.provider.fetch_user`:

```python
def test_handle() -> None:
    user = User(id=1)
    with patch("app.service.fetch_user", return_value=user) as fetch:
        assert handle(1) == user
    fetch.assert_called_once_with(1)
```

Prefer injecting a `UserProvider` when this boundary is under your control.

## Fixtures

Keep fixtures explicit and composable. Use function scope by default; widen scope only for measured
cost and reset state deliberately.

```python
@pytest.fixture
def service(repository: FakeUserRepository) -> UserService:
    return UserService(repository)
```

Use `tmp_path`, `monkeypatch`, and deterministic clock/random providers instead of global cleanup.
Do not use autouse fixtures to hide critical application setup.

## Parametrization and properties

Use parametrization for a finite behavior table. Use property-based tests for broad invariants,
parsers, serializers, numeric boundaries, and state transitions. Keep generated examples
reproducible and shrinkable.

## Interaction assertions

Assert a call only when calling that collaborator with those semantics is part of the contract.
Prefer state/output assertions for internal refactors. Avoid broad `assert_called` that proves
little or strict full-call ordering that makes harmless refactors fail.
