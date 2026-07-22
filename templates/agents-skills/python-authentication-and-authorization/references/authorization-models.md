# Authorization Models

## Select by policy shape

- **RBAC:** permissions follow organizational roles. Keep role-to-permission mapping explicit and
  avoid sprinkling role names throughout business code.
- **ABAC:** decisions depend on principal, resource, action, and environment attributes. Keep policy
  evaluation deterministic and explainable.
- **ReBAC:** permissions follow graph relationships such as owner, member, parent, or delegate.
  Define traversal depth, consistency, and revocation behavior.
- **Hybrid:** compose models only when each part owns a distinct rule.

## Object-level authorization

Route guards are insufficient. For state-changing operations, prefer a constrained write whose
predicate includes the authorization invariant:

```python
deleted = documents.delete_owned(
    document_id=document_id,
    owner_id=principal.subject_id,
    tenant_id=principal.tenant_id,
)
if not deleted:
    raise NotFoundOrForbidden
```

A load-check-act sequence is safe only when every authorization-relevant attribute is immutable
for the operation or protected by the same transaction invariant. When the policy needs richer
state, lock or version the target and any mutable policy rows:

```python
with uow.transaction():
    document = documents.get_scoped_for_update(
        document_id=document_id,
        tenant_id=principal.tenant_id,
    )
    if document is None or not policy.can_delete(principal, document):
        raise NotFoundOrForbidden
    documents.delete_if_version(document.id, expected_version=document.version)
```

The constrained SQL, row lock, or optimistic version predicate must make a stale decision unable
to commit. Keep a deliberately chosen isolation level and lock order.

## Tenancy

- Derive tenant context from the authenticated principal or trusted routing boundary.
- Constrain every tenant-owned query, including joins, aggregates, exports, and background jobs.
- Test cross-tenant identifiers explicitly.
- Decide whether privileged support/admin access is cross-tenant, time-bound, approved, and audited.

## Authorization test matrix

Test allowed and denied combinations for:

- owner versus another user;
- same role in another tenant;
- deleted, archived, or transferred resource;
- role/relationship change during a session;
- bulk operations containing mixed ownership;
- indirect references and nested resources;
- background jobs replayed after privilege revocation.
- authorization-relevant ownership, tenant, role, or state changing between check and effect;
- a barrier-driven race proving a stale actor cannot commit after that change.

Primary reference:
https://cheatsheetseries.owasp.org/cheatsheets/Business_Logic_Security_Cheat_Sheet.html
