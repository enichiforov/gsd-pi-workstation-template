# Security model

This template configures powerful local coding agents. It reduces avoidable risk, but it is not a
sandbox or a substitute for backups, least-privilege credentials, and review.

## Default autonomy

The default `full` profile intentionally configures Codex with:

```toml
approval_policy = "never"
sandbox_mode = "danger-full-access"
sandbox = "danger-full-access"
```

That choice maximizes unattended execution and increases blast radius. The installer therefore
models safety-net as a hard dependency of Codex rather than an optional companion:

1. install the exact `cc-safety-net` version;
2. add the marketplace at a pinned Git ref;
3. install the plugin;
4. confirm the plugin appears in Codex;
5. prove the guard blocks `git reset --hard`;
6. only then patch autonomous Codex settings.

Any failure stops installation before the autonomy settings are written. Existing Codex config is
backed up before it is patched.

Use `--profile minimal` when this risk profile is not appropriate.

## What safety-net does and does not do

`cc-safety-net` is a pre-tool guard for many destructive shell commands, including wrapped forms.
It is defense in depth, not complete isolation.

It does not guarantee protection from:

- destructive but syntactically novel commands;
- application/API-level data deletion;
- credential misuse or data exfiltration;
- unsafe code executed through a trusted interpreter;
- malicious or compromised third-party plugins;
- mistakes outside the guarded tool path.

Keep credentials scoped, maintain backups, review requested permissions, and do not run the high-
autonomy profile against irreplaceable data.

## Supply chain

Runtime packages are not vendored. Exact npm/PyPI versions and Git refs are recorded in
`manifests/pinned-inventory.json`; profile package sources are in `manifests/components.json`.
Marketplace snapshots are pinned to commits.

Pins improve reproducibility but do not prove upstream code is safe. Review upstream release notes
and diffs before updating a pin. Do not replace exact refs with moving branches or `latest`.

## Secrets and private state

Never commit:

- API keys, GitHub tokens, provider auth, 1Password output, or SSH keys;
- `.env` files other than sanitized `.env.example` files;
- `.codex/auth.json`, browser state, cookies, or session files;
- `.gsd/gsd.db`, WAL files, runtime state, logs, caches, or transcripts;
- private documents, personal knowledge bases, or production data.

`scripts/check-public-safe.py` detects common credential patterns and private absolute home paths.
It intentionally ignores local runtime/cache directories and symlinks so it does not traverse
machine state outside repository content.

## Managed files and backups

Different existing templates are preserved unless `--overwrite` is explicit. Replaced files and
Codex config are copied under:

```text
${XDG_STATE_HOME:-~/.local/state}/gsd-pi-workstation/backups/<run-id>/
```

Package and marketplace operations are not transactionally reversible. If installation fails,
inspect the reported backup and the component that failed before retrying.

## Reporting a vulnerability

Do not open a public issue containing exploit details or credentials. Contact the repository owner
privately through the security-reporting channel configured on GitHub. Include the affected commit,
component/profile, reproduction steps, impact, and a proposed mitigation when available.
