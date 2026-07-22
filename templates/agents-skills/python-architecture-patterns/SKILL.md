---
name: python-architecture-patterns
description: "Design and review Python application architecture: use cases/interactors, controllers/adapters, domain boundaries, repositories/ports, transaction ownership, Dependency Injection and Dependency Inversion, composition roots, IoC-container decisions, and object decorators. Use for structuring modules/services/agents or evaluating coupling and responsibility boundaries; use python-database-patterns for detailed ORM/query/migration choices and python-web-service-runtime for deployment topology."
---

# Python Architecture Patterns

Derive architecture from observable use cases and ownership boundaries. Add abstractions only
when they protect a real policy, substitution, lifecycle, or test seam.

## Workflow

1. **List use cases as black-box behavior.** State actor/input, preconditions, durable effects,
   result, authorization, and failure semantics.
2. **Assign boundary roles.**
   - Controller/delivery adapter: parse framework input and translate output.
   - Interactor/use case: orchestrate one application scenario and its atomicity.
   - Domain: enforce durable business rules.
   - Port/repository: express an application-owned capability.
   - Infrastructure adapter: implement a port with SQL, HTTP, files, queues, or providers.
   - Composition root: construct concrete objects and lifetimes.
3. **Draw dependency direction.** Keep policy-facing interfaces owned by the code that consumes
   them. Depend inward; translate at boundaries.
4. **Define transaction ownership.** Let the use case decide the atomic operation. Do not let each
   repository commit independently. Do not call a commit/rollback wrapper a full Unit of Work
   unless it also coordinates tracked changes; SQLAlchemy `Session` already implements ORM UoW.
5. **Choose the smallest composition mechanism.** Prefer explicit constructors and a manual
   composition root. Add a container only when scopes, cleanup, graph validation, or modular
   provider composition justify it.
6. **Check substitutes and decorators.** Preserve the consumed contract. Use an injected object
   decorator when behavior varies by instance, lifetime, or environment.
7. **Test boundaries.** Test use cases through ports, adapters against real boundary contracts,
   and composition with a smoke test.

## Core rules

- Keep framework, persistence, provider, and transport models at their adapters.
- Give ports domain/application language such as `load_pending_orders`, not generic query syntax.
- Put SQL JOINs, eager-loading mechanics, and database projections in repository/DAO SQL. Let the
  use case state the needed business view; do not make it assemble SQL-shaped rows.
- Avoid a public generic repository. A concrete adapter may reuse a private generic helper.
- Do not create an interface only to mirror a concrete class. Create it when the consumer owns a
  smaller stable contract or multiple substitutions/testing seams are real.
- Keep external I/O outside a database transaction unless the operation explicitly requires and
  can safely tolerate that coupling.
- Name a fat mixed-responsibility service as the anti-pattern; a cohesive application service or
  interactor is not inherently wrong.
- Reject circular dependencies rather than hiding them with import tricks or a service locator.

## Load references selectively

- For controllers, interactors, repositories, JOIN ownership, and UoW distinctions, read
  [application-boundaries.md](references/application-boundaries.md).
- For DI/DIP, composition roots, containers, and decorators, read
  [dependency-composition.md](references/dependency-composition.md).
- For channel provenance and qualified claims, read
  [advice17-source-map.md](references/advice17-source-map.md).

## Output contract

Return:

1. the use cases and invariants;
2. a responsibility/dependency map;
3. transaction and lifecycle owners;
4. the minimum required ports/adapters;
5. rejected alternatives with concrete costs;
6. tests that prove the boundaries.

Do not prescribe layers, repositories, or containers without tying each one to a use case.
