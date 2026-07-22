# Plugin and package inventory

The machine-readable source of truth is split deliberately:

- `manifests/components.json` maps packages to selectable components;
- `manifests/pinned-inventory.json` records exact versions and Git refs;
- `manifests/marketplace-plugins.json` records curated provider plugin names.

This document explains why each group exists. It is not a lockfile substitute.

## GSD/Pi packages

| Component | Package | Role |
|---|---|---|
| `delegation` | `pi-subagents` | Parent-owned scout, worker, reviewer, and research delegation |
| `delegation` | `pi-multi-pass` | Multi-pass agent/model orchestration used by the managed settings |
| `navigation` | `pi-lens` | LSP, AST search, symbol reads, and post-edit diagnostics |
| `review` | `pi-simplify` | Changed-code simplification pass |
| `review` | `@plannotator/pi-extension` | Visual plan, message, and diff review |
| `review` | `@narumitw/pi-wait-what` | Pause/explain command for surprising agent behavior |

All npm package specs are exact. The Git package uses an immutable commit ref.

## Codex safety

| Component | Tool | Role |
|---|---|---|
| `codex-safety-net` | `cc-safety-net` npm package | CLI self-test and guard implementation |
| `codex-safety-net` | `safety-net@cc-marketplace` | Codex plugin hook |
| `codex` | managed Codex TOML | Enables the intentionally autonomous workstation defaults |

`codex` depends on `codex-safety-net`. The installer verifies a known destructive command is blocked
before changing the Codex autonomy settings.

## Coding-workflow marketplace

The `marketplace` component installs a curated set from the pinned `wshobson/agents` snapshot for
available Claude Code and Codex CLIs. Groups cover:

- agent teams and developer essentials;
- API/backend/security/database work;
- debugging, review, performance, and observability;
- documentation and framework migration;
- Python, JavaScript/TypeScript, Go, Rust, and JVM workflows;
- Kubernetes, deployment, incident response, and dependency management.

The exact names are kept in `manifests/marketplace-plugins.json` so selection remains reviewable and
provider commands do not contain hidden lists.

## Claude GSD layer

The `claude-gsd` component installs an exact `get-shit-done-cc` version and runs its global Claude
installer. Verification checks canonical planner, executor, and verifier agents.

## Portable Python skills

The `python-skills` component copies the vendored `templates/agents-skills/python-*` directories to
`~/.agents/skills`. They are vendored because they are workstation instruction assets rather than
runtime package dependencies.

## Graphify

The `graphify` component installs the exact `graphifyy` PyPI version through `uv` or `pipx`, then
registers its skill for Claude, Pi, and Codex when Codex is selected.

## Updating inventory

Never edit only this document. Update exact sources in the manifests, run unit/public-safety checks,
exercise both minimal and full dry-runs, and run `scripts/docker-smoke.sh` for installation changes.
