# Authentication Mechanisms

Choose a maintained protocol/library and state the attack and recovery contract. Authentication
success is not authorization; construct a principal only after this boundary succeeds.

## Password authentication

- Store passwords with the project's current approved password-hashing library and parameters.
  Prefer Argon2id where supported; follow current OWASP guidance for alternatives and work factors.
- Verify through the library API and rehash after a successful login when parameters or legacy
  schemes need upgrading. Never compare password hashes manually.
- Return enumeration-resistant responses for unknown account, wrong password, disabled account,
  and recovery initiation. Keep timing differences within the documented threat model; perform
  equivalent bounded work for unknown accounts when needed.
- Rate-limit and monitor by account plus source/risk signals. Define backoff/lockout so attackers
  cannot trivially deny service to a victim.
- Require TLS, protect credentials from logs/traces, and use breached-password screening where
  product policy requires it.

## MFA, recovery, and reauthentication

- Define which factors are independent, how enrollment is verified, and how factor replacement is
  protected.
- Treat account recovery and MFA reset as authentication mechanisms with audit, notification,
  throttling, and recovery-code lifecycle. Do not make recovery weaker than normal login without
  an explicit accepted risk.
- Require reauthentication for sensitive changes and after risk events. Rotate or revoke sessions
  after credential, factor, or privilege changes.
- Test downgrade paths: lost factor, backup codes, support-assisted recovery, factor replacement,
  and replay.

## Federated OIDC/OAuth login

- Prefer Authorization Code flow with PKCE for browser/native clients. Register exact redirect
  URIs and validate `state`, authorization response issuer when applicable, and OIDC `nonce`.
- Validate the returned ID token under the issuer's configured JWT profile and bind it to the
  initiated browser session. Do not use an ID token as an API access token.
- Keep client secrets only in confidential clients. Never put them in public browser/native code.
- Define account linking explicitly; do not merge accounts solely on an unverified or mutable
  identifier.
- Test callback mix-up, state/nonce/PKCE failure, redirect mismatch, code replay, issuer mismatch,
  token substitution, and provider-key rotation.

## Required tests

- unknown account and wrong password have the same public contract;
- throttling and alerting resist credential stuffing without permanent victim lockout;
- successful legacy-hash login upgrades the stored hash atomically;
- MFA enrollment, replacement, recovery, replay, and downgrade attempts;
- password reset revokes or rotates the sessions required by policy;
- OIDC state, nonce, PKCE, issuer, redirect, and token-kind failures;
- sensitive action requires the declared recent-authentication evidence.

Primary references:

- https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html
- https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html
- https://www.rfc-editor.org/rfc/rfc9700
- https://www.rfc-editor.org/rfc/rfc7636
- https://openid.net/specs/openid-connect-core-1_0.html
