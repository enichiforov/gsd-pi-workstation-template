# Dependency Composition

## Dependency Injection

Make dependencies explicit through constructors or function parameters. Keep object creation in a
composition root:

```python
def build_application(settings: Settings) -> Application:
    engine = create_engine(settings.database_url)
    orders = SqlAlchemyOrderRepository(engine)
    notifier = EmailNotifier(HttpClient(), settings.mail)
    return Application(place_order=PlaceOrder(orders, notifier))
```

Do not inject every implementation detail. A class may construct private, cheap, deterministic
helpers that are inseparable from its implementation.

## Dependency Inversion

Define the abstraction from the high-level consumer's required operations. Do not let a provider
SDK dictate the port:

```python
class QuoteProvider(Protocol):
    def latest(self, symbol: Symbol) -> Quote: ...
```

Translate provider models and errors in the adapter.

## Container decision

Start with a manual composition root. Add a container only when at least one concrete need exists:

- request/task/application scopes;
- async or deterministic cleanup;
- multiple provider modules;
- reusable environment-specific bindings;
- dependency-graph validation and useful cycle diagnostics;
- volume of wiring that obscures rather than documents construction.

Validate the graph at startup. Reject cycles with the full dependency path. Keep business code
independent of container APIs and avoid runtime service-location calls.

## Python decorator versus object decorator

Use a Python `@decorator` for declaration-time, cross-cutting behavior with a stable callable
contract. Preserve metadata with `functools.wraps` and make signature assumptions explicit.

Use an object decorator when behavior must vary by instance, lifetime, environment, or test:

```python
provider: QuoteProvider = CachedQuoteProvider(
    inner=HttpQuoteProvider(client),
    cache=redis_cache,
)
```

Avoid decorator-time global registries and hard-wired caches unless a framework intentionally owns
that global registration lifecycle.
