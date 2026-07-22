# GSD Pi Workstation Template

A reproducible, selective installer for an opinionated GSD/Pi coding workstation on macOS.

It packages the workflow rather than personal machine state: pinned agent extensions, curated
instructions, Codex safety controls, optional Claude/Python tooling, verification, and public-safety
checks. No credentials, auth files, private prompts, or project data belong in this repository.

> [!WARNING]
> The default `full` profile intentionally configures Codex with
> `approval_policy = "never"` and `sandbox_mode = "danger-full-access"`.
> The installer enables those settings **only after** installing and self-testing `cc-safety-net`.
> This is a high-autonomy workstation, not a security sandbox. Start with `minimal` if you do not
> want that tradeoff.

## What you get

- pinned GSD/Pi packages for navigation, delegation, and review;
- global and project `AGENTS.md` templates;
- managed GSD settings, models, and multi-pass configuration;
- fail-closed Codex safety-net installation before autonomous settings;
- optional coding-workflow marketplaces for Claude Code and Codex;
- optional `get-shit-done-cc`, a hash-verified 10-skill Python engineering bundle, and Graphify;
- dry-run planning, component overrides, idempotent file installation, and backups;
- profile-aware verification and a public-safety scanner.

## Requirements

- macOS;
- Git;
- Node.js 22+ and npm;
- Python 3.9+;
- [GSD/Pi](https://opengsd.net/) 1.11+ available as `gsd`;
- a local project checkout when installing `workspace-config` or `codex`;
- Codex CLI for profiles containing `codex`;
- `uv` or `pipx` when installing `graphify`.

Claude Code is optional. When it is not installed, Claude-specific marketplace setup is reported as
a warning and the rest of the profile continues.

## Quick start

```bash
git clone https://github.com/enichiforov/gsd-pi-workstation-template.git
cd gsd-pi-workstation-template

./scripts/install.sh --list-components
./scripts/install.sh --project-repo "$HOME/code/your-project" --dry-run
./scripts/install.sh --project-repo "$HOME/code/your-project"
./scripts/verify.sh --project-repo "$HOME/code/your-project"
```

The default profile is `full`. No remote `curl | sh` bootstrap is provided: clone, inspect, dry-run,
then install.

## Profiles

| Profile | Intended use | Components |
|---|---|---|
| `minimal` | Portable starting point | core CLI compatibility and workstation templates |
| `developer` | Daily coding without large marketplaces/Graphify | minimal + version-gated compatibility patch, navigation, delegation, review, autonomous Codex |
| `full` (default) | Complete workstation reproduced from this repository | developer + marketplaces, Claude GSD, Python skills, Graphify |

The exact machine-readable definitions live in [`manifests/components.json`](manifests/components.json).
The profile name is only a starting point: components can be added or removed explicitly.

```bash
# Developer profile plus the vendored Python skills
./scripts/install.sh \
  --profile developer \
  --include python-skills \
  --project-repo "$HOME/code/your-project"

# Full profile without provider marketplaces or Graphify
./scripts/install.sh \
  --profile full \
  --exclude marketplace,graphify \
  --project-repo "$HOME/code/your-project"

# Verify the same resolved selection
./scripts/verify.sh \
  --profile full \
  --exclude marketplace,graphify \
  --project-repo "$HOME/code/your-project"
```

Dependencies are resolved automatically. An invalid request such as excluding
`codex-safety-net` while retaining `codex` fails before the machine is changed.

See [Configuration](docs/CONFIGURATION.md) for every component and CLI option.

## What the installer changes

Depending on the selected components, installation may update:

- `~/AGENTS.md`;
- `<project>/AGENTS.md`;
- `~/.gsd/agent/{settings,models,multi-pass}.json`;
- `~/.gsd/agent/npm/` and GSD package registration;
- `~/.codex/config.toml` and Codex plugin state;
- `~/.claude/` when Claude components are selected;
- `~/.agents/skills/` for complete portable Python skill trees, including references and
  `agents/openai.yaml` metadata;
- the user `uv`/`pipx` tool environment for Graphify.

Existing managed template files are preserved unless `--overwrite` is passed. Before replacement,
the installer copies them to:

```text
${XDG_STATE_HOME:-~/.local/state}/gsd-pi-workstation/backups/<run-id>/
```

Each Python skill is managed as one coherent directory. Without `--overwrite`, a different
existing skill is skipped in full; with `--overwrite`, its complete directory is backed up and
atomically replaced.

The last successful selection is recorded in `last-install.txt` under the same state directory.
Package/plugin operations are intentionally not auto-rolled back; configuration-file backups make
recovery explicit and inspectable.

## Updating

1. Review upstream changes and [`manifests/pinned-inventory.json`](manifests/pinned-inventory.json).
2. Run the installer with `--dry-run` and the same profile/overrides.
3. Run with `--overwrite` only when you intend to refresh managed templates.
4. Run `scripts/verify.sh` with the same profile/overrides.

```bash
git pull --ff-only
./scripts/install.sh --profile full --project-repo "$HOME/code/your-project" --dry-run
./scripts/install.sh --profile full --project-repo "$HOME/code/your-project" --overwrite
./scripts/verify.sh --profile full --project-repo "$HOME/code/your-project"
```

## Repository layout

```text
manifests/   profiles, exact versions, source refs, plugin inventory
templates/   public-safe files copied into user/project configuration
scripts/     install, verify, compatibility patches, smoke/public checks
tests/       standard-library unit and CLI contract tests
docs/        configuration, security, workflow, and troubleshooting guides
```

## Development checks

```bash
python3 -m unittest discover -s tests -v
bash -n scripts/*.sh
python3 scripts/python-skills.py validate
python3 scripts/check-public-safe.py
./scripts/install.sh --profile full --dry-run --project-repo /tmp/example
```

Docker-based end-to-end smoke testing is available with `scripts/docker-smoke.sh`.
See [Contributing](CONTRIBUTING.md) before changing profiles or dependency pins.

## Documentation

- [Configuration and component selection](docs/CONFIGURATION.md)
- [Security model](docs/SECURITY.md)
- [Plugin inventory](docs/PLUGIN-INVENTORY.md)
- [MacBook bootstrap](docs/BOOTSTRAP-MACBOOK.md)
- [Development flow](docs/DEVELOPMENT-FLOW.md)
- [Graphify notes](docs/GRAPHIFY.md)
- [Troubleshooting and recovery](docs/TROUBLESHOOTING.md)

## License

[MIT](LICENSE)
