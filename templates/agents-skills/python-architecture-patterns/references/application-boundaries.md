# Application Boundaries

## Request-to-effect flow

```text
framework event
  -> controller/adapter
  -> command + Principal
  -> interactor/use case
  -> domain rules + application-owned ports
  -> infrastructure adapters
  -> result
  -> response/event translation
```

Controllers know framework shapes. Interactors know scenarios. Domain code knows invariants.
Repositories know persistence mechanics. The composition root knows concrete construction.

## Use cases and interactors

Write the use-case contract before its class:

- input and validated command;
- caller/principal and authorization;
- loaded state;
- invariant checks;
- durable effects and atomicity;
- result and expected absence/failure states.

An interactor may be a function or class. Do not create one class per endpoint mechanically when a
cohesive application service expresses the same boundary clearly.

## Repository and query ownership

Use cases request domain-meaningful data:

```python
orders.list_ready_for_publication(cutoff)
```

The repository/DAO owns SQL, JOINs, grouping, loading strategies, and mapping. It may return domain
objects, repository DTOs, or read-model records according to the declared boundary. The use case
must not receive a query builder or compose SQL predicates.

Use a DAO/read repository for cross-cutting projections that do not need rich domain behavior.
Use a domain repository when entity identity and mutation semantics matter.

## Transaction manager versus Unit of Work

A wrapper that begins, commits, and rolls back a database transaction is a
`TransactionManager`. A Unit of Work additionally tracks or coordinates changed objects and their
persistence. SQLAlchemy `Session` supplies identity-map and UoW behavior.

```python
class PlaceOrder:
    def __init__(self, uow: OrderUnitOfWork) -> None:
        self._uow = uow

    def execute(self, command: PlaceOrderCommand) -> OrderId:
        with self._uow:
            order = Order.place(command)
            self._uow.orders.add(order)
            self._uow.inventory.reserve(order.items)
            self._uow.commit()
        return order.id
```

Do not commit inside `orders.add` or `inventory.reserve`. Keep transaction scope visible at the
application boundary. If the operation calls an external provider, split claim/checkpoint/finalize
transactions or use outbox/saga semantics instead of holding the transaction open.
