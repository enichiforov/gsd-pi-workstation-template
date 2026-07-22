# Authentication Boundaries

## Boundary flow

Use this direction:

```text
credential or trusted assertion
  -> authentication adapter
  -> immutable Principal
  -> application use case
  -> object-level authorization
  -> domain effect
```

The adapter may verify a cookie-backed session, JWT signature and claims, mTLS identity, Telegram
event origin, or a trusted reverse-proxy assertion. Document exactly why that input is trusted.

Prefer:

```python
@dataclass(frozen=True, slots=True)
class Principal:
    subject_id: UserId
    tenant_id: TenantId
    roles: frozenset[Role]


def handle(request: Request) -> Response:
    principal = authenticator.authenticate(request)
    result = use_case.execute(request.to_command(), principal)
    return Response.from_result(result)
```

Avoid ambient context inside core logic:

```python
def delete_document(document_id: int) -> None:
    user = get_current_user()  # hidden input and often hidden I/O
```

A request-scoped provider can be useful inside the adapter. Resolve it there and pass the
principal explicitly across the core boundary.

## Error mapping

Keep authentication failure, insufficient authorization, and missing target semantics deliberate.
Sometimes returning the same public response for “missing” and “forbidden” prevents object
enumeration. Preserve the internal audit reason even when the public response is intentionally
coarse.

Do not expose token parsing errors, secret material, password hashes, or upstream identity-provider
responses to clients.
