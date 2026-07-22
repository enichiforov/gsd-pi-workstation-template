# JWT Validation

Treat JWT parsing as a cryptographic protocol boundary. Use a maintained library and configure the
acceptable profile in application code; never infer it from attacker-controlled token headers.

## Validation contract

- Allow only explicitly configured algorithms. Never accept `none` and never derive the allowed
  algorithm from `alg` alone.
- Bind each configured issuer to its allowed algorithms, key set, audiences, and token kinds.
  Reject an RSA/EC key used as an HMAC secret and other algorithm/key-type mismatches.
- Validate issuer, audience, expiration, required claims, and an explicit `nbf`/clock-skew policy.
  Validate `iat` when the application contract uses it.
- Separate access, ID, refresh, logout, and other JWT kinds with mutually exclusive rules. Use a
  validated `typ`, distinct audiences/issuers/keys, or claim profiles strong enough to prevent
  cross-JWT substitution.
- Constrain `kid` to lookup inside the configured issuer key set. Do not fetch arbitrary `jku`,
  `x5u`, or other remote key URLs supplied by the token.
- Define key-rotation overlap, cache refresh, unknown-key behavior, and failure when the trusted
  discovery endpoint is unavailable. Fail closed.
- Treat validated claims as authentication evidence, not automatically current authorization.
  Recheck server-side session, membership, privilege version, or revocation state when the
  required revocation latency demands it.

## Negative tests

Test:

- `alg=none`, algorithm confusion, and wrong key type;
- unknown/malformed `kid` and attacker-controlled `jku`/`x5u`;
- wrong issuer, audience, token kind, or subject binding;
- an ID/refresh token substituted where an access token is required;
- missing, expired, future-`nbf`, and excessive clock-skew claims;
- old and new keys during the declared rotation overlap;
- revoked server-side session before token expiry;
- trusted key discovery outage and stale-cache limits.

Primary references:

- https://datatracker.ietf.org/doc/html/rfc8725
- https://www.rfc-editor.org/rfc/rfc7519
