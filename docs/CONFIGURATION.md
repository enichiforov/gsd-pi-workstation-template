# Configuration

The installer resolves a named profile into an ordered component plan. Profiles are conveniences;
components are the stable interface.

## Inspect before installing

```bash
./scripts/install.sh --list-components
./scripts/install.sh --profile full --project-repo ~/code/app --dry-run
```

`--dry-run` resolves dependencies and validates names without checking prerequisites or changing the
machine.

## Profiles

### `minimal`

- `core`
- `workspace-config`

Use this when you want the public instruction/settings templates but not autonomous Codex or the
optional tool stack.

### `developer`

- everything in `minimal`;
- `compatibility-patch`;
- `navigation`;
- `delegation`;
- `review`;
- `codex` (which requires `codex-safety-net`).

Use this for the normal LSP/AST, subagent, review, and autonomous Codex workflow without the larger
marketplace and knowledge-graph layers.

### `full`

The default. It adds:

- `marketplace`;
- `claude-gsd`;
- `python-skills`;
- `graphify`.

## Components

| Component | Installs/configures | Dependencies |
|---|---|---|
| `core` | required commands and a working `pi` command | none |
| `workspace-config` | global/project `AGENTS.md`, GSD settings/models/multi-pass | `core` |
| `compatibility-patch` | version-gated export repair for supported GSD 1.7/1.8 and 1.11 releases | `core` |
| `navigation` | pinned `pi-lens` | `core` |
| `delegation` | pinned `pi-subagents` and `pi-multi-pass` | `core` |
| `review` | pinned `pi-simplify`, Plannotator, and wait-what | `core` |
| `codex-safety-net` | Codex marketplace plugin and CLI self-test | `core` |
| `codex` | autonomous Codex config and project trust | `codex-safety-net` |
| `marketplace` | curated coding plugins for available Claude/Codex CLIs | `core` |
| `claude-gsd` | pinned `get-shit-done-cc` global Claude layer | `core` |
| `python-skills` | vendored `python-*` skills under `~/.agents/skills` | `core` |
| `graphify` | pinned Graphify CLI and assistant skill registrations | `core` |

The canonical definitions and package mapping are in `manifests/components.json`.

## Overrides

`--include` and `--exclude` accept comma-separated names and may be repeated.

```bash
./scripts/install.sh \
  --profile minimal \
  --include navigation,delegation \
  --include python-skills \
  --project-repo ~/code/app
```

```bash
./scripts/install.sh \
  --profile full \
  --exclude graphify,marketplace \
  --project-repo ~/code/app
```

The resolver adds transitive dependencies before dependants and rejects contradictions. Excluding
`codex-safety-net` while `codex` remains selected is therefore an error, not a partially protected
installation.

Always pass the same profile and overrides to `verify.sh`.

## Managed-file policy

The installer is idempotent:

- an identical destination is reported as unchanged;
- a different existing destination is preserved by default;
- `--overwrite` backs it up before replacement.

Codex config is merged by `scripts/patch-codex-config.py`; unrelated root keys and tables are
preserved. Because the default autonomy settings are security-sensitive, Codex config is patched
only after safety-net installation and its destructive-command self-test pass.

## Machine-readable inventory

- `manifests/components.json`: profile/component graph and selected GSD package sources;
- `manifests/pinned-inventory.json`: exact npm/PyPI versions and Git refs;
- `manifests/marketplace-plugins.json`: curated plugin names and pinned marketplace ref;
- `manifests/gsd-packages.txt`: compatibility/human-readable view of pinned GSD sources.

`compatibility-patch` runs before community extensions are loaded. It first detects whether a
change is needed, refuses unknown GSD release lines, and creates adjacent recovery copies named
`package.json.gsd-pi-workstation.bak` before editing an installed package manifest.

Dependency changes should update all relevant manifests in one pull request and pass the Docker
smoke test.
