# Data-Access Patterns

## Pattern selection

| Pattern | Return shape | Best fit | Main cost |
|---|---|---|---|
| Row/Table Data Gateway | Rows/records | Thin SQL operations | Business rules can scatter |
| DAO/read repository | DTO/read model | Screens, reports, cross-cuts | Query-specific API surface |
| Active Record | Persistent object | Simple persistence-coupled domains | Domain depends on persistence |
| Data Mapper + Repository | Domain objects | Rich domain and testable core | Mapping and identity complexity |
| ORM Session/UoW | Identity-mapped entities | Coordinated object-graph mutation | Lifecycle/loading must be explicit |

Do not expose a generic `find(filters: dict)` as the domain contract. Prefer
`list_pending_for_owner(owner_id)`. A concrete repository may use a private generic query helper.

## Domain and persistence models

Using one ORM/domain model reduces mapping code and can be correct. Separate models protect the
domain from persistence details and can also be correct. When separating, define and test:

- identity and equality;
- mapping direction and missing fields;
- relationship loading;
- change tracking and save semantics;
- generated/default values;
- version/concurrency fields;
- transaction attachment/detachment.

Avoid ad-hoc mapper calls spread through services.

## Core versus ORM

Use SQLAlchemy Core for explicit statements, projections, bulk operations, and query-first flows.
Use ORM when identity-map/UoW behavior and relationships reduce application complexity. SQLAlchemy
2.x uses the same `select()` statement model across both; do not preserve legacy `Query` patterns
without a compatibility reason.

## Read projections

A read model may deliberately use JOINs, aggregates, JSON, arrays, window functions, and database
features. Keep it behind a DAO/repository DTO boundary. Do not force a rich domain entity to
represent a reporting projection.
