---
name: python-authentication-and-authorization
description: "Design and review Python authentication, session, principal, and authorization boundaries. Use for login, API tokens, JWT, cookies, mTLS, Identity Provider adapters, RBAC/ABAC/ReBAC, object-level permissions, multi-tenant access, route guards, and tests for broken access control."
---

# Python Authentication and Authorization

Treat identity and access control as explicit trust-boundary design, not middleware decoration.

## Workflow

1. **Name the subject and operation.** Identify the caller, tenant, target object, action, and
   security consequence.
2. **Separate four concerns.**
   - Identification supplies a claimed identity.
   - Authentication verifies the claim.
   - Session/token management carries authenticated state across interactions.
   - Authorization decides whether this principal may perform this action on this object.
3. **Design the authentication mechanism.** Define credential verification, enumeration and
   abuse controls, MFA/recovery, reauthentication, and any federated-login callback guarantees.
4. **Authenticate at a trusted adapter boundary.** Verify the credential, token, certificate, or
   trusted upstream assertion before constructing a principal.
5. **Pass an explicit immutable principal inward.** Include stable subject/tenant identifiers and
   only the claims needed by the use case. Do not hide request-scoped identity behind a universal
   parameterless `get_current_user()` service locator.
6. **Authorize at the application/domain boundary.** Route checks may reject obviously invalid
   requests early, but the use case must enforce object-, tenant-, and state-dependent access.
7. **Choose the authorization model from requirements.** Use RBAC for role-shaped policy, ABAC for
   attribute/policy decisions, ReBAC for relationships, or a deliberate composition.
8. **Define lifecycle and failure behavior.** Specify expiry, rotation, revocation, privilege
   change, reauthentication, logout, clock skew, fail-open/fail-closed behavior, and audit events.
9. **Test adversarially.** Test cross-user and cross-tenant object IDs, role downgrade, revoked and
   expired credentials, missing claims, duplicate sessions, and direct use-case invocation.

## Core rules

- Never use an opaque or random object ID as authorization.
- Never rely only on UI hiding or route naming.
- Never trust client-supplied roles, tenant IDs, ownership, or upstream headers without a
  validated trust boundary.
- Keep secrets and raw credentials out of logs, domain objects, and exception text.
- Keep authentication adapters replaceable; keep authorization semantics owned by the
  application/domain requirements.
- Make denial the default for missing or ambiguous policy.
- Authorize against the target state used by the effect. When authorization-relevant state can
  change concurrently, couple decision and mutation with constrained DML, a row lock, an
  optimistic version check, or another atomic transaction invariant.
- Record enough audit context to explain a decision without recording secrets.

## Load references selectively

- For principal construction and adapter/use-case separation, read
  [auth-boundaries.md](references/auth-boundaries.md).
- For passwords, login abuse controls, MFA/recovery, and federated login, read
  [authentication-mechanisms.md](references/authentication-mechanisms.md).
- For RBAC, ABAC, ReBAC, tenancy, and object checks, read
  [authorization-models.md](references/authorization-models.md).
- For cookies, sessions, tokens, expiry, rotation, and revocation, read
  [session-and-token-checklist.md](references/session-and-token-checklist.md).
- For JWT algorithm, key, issuer, audience, token-kind, and key-discovery validation, read
  [jwt-validation.md](references/jwt-validation.md).
- For provenance and qualifications, read
  [advice17-source-map.md](references/advice17-source-map.md).

## Output contract

Return:

1. the trust boundaries and credential path;
2. the principal schema and owner;
3. credential verification, abuse controls, MFA/recovery, and reauthentication decisions;
4. where authentication and authorization execute;
5. the authorization model and atomic object/tenant constraints;
6. session/token lifecycle and revocation decisions;
7. denial and audit behavior;
8. adversarial and concurrency tests.

Flag unspecified threat, tenant, revocation, and recovery requirements instead of assuming them.
