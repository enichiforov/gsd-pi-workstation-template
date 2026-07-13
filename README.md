# GSD Pi Workstation Template

A public, reusable bootstrap kit for a GSD/Pi + Codex coding workstation.

It captures a practical agentic development flow:

- Pi/GSD package installation
- LSP/AST-first code navigation via `pi-lens`
- native Pi subagents via `pi-subagents`
- changed-code simplification review via `pi-simplify`
- visual plan review via Plannotator
- `/wait-what` pause/explain command
- Codex destructive-command guard via `cc-safety-net`
- generic `AGENTS.md` templates for user-level and project-level instructions
- a `pi` CLI shim/alias for extension runtimes that still spawn `pi` while npm GSD publishes `gsd`
- a small GSD/Pi npm export compatibility patch for community extensions

This repo is intentionally public-safe. It contains no auth files, no API keys, no private project state, and no private runtime databases.

## Quick install

Prerequisites:

- `git`
- `node` / `npm`
- `python3`
- `gsd` / Pi
- Codex CLI, if you want the safety-net hook

```bash
git clone https://github.com/enichiforov/gsd-pi-workstation-template ~/gsd-pi-workstation-template
cd ~/gsd-pi-workstation-template
./scripts/install.sh --project-repo ~/YourProject --overwrite
./scripts/verify.sh --project-repo ~/YourProject
./scripts/check-public-safe.py
./scripts/docker-smoke.sh
```

Restart any open GSD/Pi/Codex sessions after installation.

## What gets installed

- `~/AGENTS.md` from `templates/root/AGENTS.md`
- project `AGENTS.md` from `templates/project/AGENTS.md`
- `~/.gsd/agent/settings.json`
- `~/.gsd/agent/multi-pass.json`
- GSD/Pi package registrations from `manifests/gsd-packages.txt`
- pinned npm extension packages from `manifests/agent-npm-package.json`
- Codex `cc-safety-net` plugin configuration, when Codex is installed
- coding-workflow marketplace plugins from `manifests/marketplace-plugins.json`
- portable `python-*` development skills from `templates/agents-skills/` into `~/.agents/skills/`
  ("how to write good code" — installed for both Claude Code and Codex from the
  public `wshobson/agents` marketplace; skip with `--skip-plugins`)

## Included packages

| Package | Purpose |
|---|---|
| `pi-subagents` | native Pi delegation pool |
| `pi-lens` | LSP, AST search, diagnostics, module reports |
| `pi-simplify` | changed-code simplification review |
| `@plannotator/pi-extension` | visual plan/message/diff review |
| `@narumitw/pi-wait-what` | `/wait-what` pause and explain command |
| `pi-multi-pass` | provider pooling/fallback configuration |
| `cc-safety-net` | Codex hook for destructive git/filesystem command blocking |

## Docs

- [`docs/BOOTSTRAP-MACBOOK.md`](docs/BOOTSTRAP-MACBOOK.md) — full fresh-machine checklist
- [`docs/PLUGIN-INVENTORY.md`](docs/PLUGIN-INVENTORY.md) — why each plugin is included
- [`docs/DEVELOPMENT-FLOW.md`](docs/DEVELOPMENT-FLOW.md) — recommended coding flow
- [`docs/SECURITY.md`](docs/SECURITY.md) — what not to commit and how safety-net fits

## Customize

Edit these before installing if your project needs different defaults:

- `templates/root/AGENTS.md`
- `templates/project/AGENTS.md`
- `templates/gsd-agent/settings.json`
- `templates/gsd-agent/models.json`
- `templates/gsd-agent/multi-pass.json`
- `templates/codex/config.toml`

## Safety notes

This template includes guardrails, but it does not make autonomous coding risk-free.

- `scripts/install.sh` creates a local `pi` command alias to `gsd` when needed. This prevents `spawn pi ENOENT` in extension runtimes.
- `scripts/install.sh` may patch local GSD/Pi npm package export maps so community extensions load cleanly. This is idempotent and local to the machine.
- `cc-safety-net` blocks many destructive shell commands; it is not a sandbox or firewall.
- Approval boundaries still matter for pushes, deployments, external services, secrets, and paid API behavior.
- Keep private project facts, personal data, credentials, and runtime state out of public forks.
