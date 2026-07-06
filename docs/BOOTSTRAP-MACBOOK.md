# Bootstrap a GSD/Pi development MacBook

This checklist sets up a MacBook with the GSD/Pi + Codex coding workflow captured by this template.

## Target outcome

After this checklist:

- `gsd` / Pi starts with useful coding-agent instructions.
- Your project has a project-level `AGENTS.md`.
- Pi/GSD has `pi-subagents`, `pi-lens`, `pi-simplify`, Plannotator, `/wait-what`, and pi-multi-pass installed.
- Codex has `cc-safety-net` configured as a destructive-command guard, if Codex is installed.
- `pi` is available as a CLI alias to `gsd` for extension runtimes that spawn `pi`.
- Community Pi extensions load without lifecycle `Failed to load extension` errors.
- `scripts/verify.sh` passes.

## 0. Pick paths

```bash
export PROJECT_REPO="$HOME/YourProject"
export WORKSTATION_REPO="$HOME/gsd-pi-workstation-template"
```

## 1. Install prerequisites

```bash
xcode-select --install || true

# Homebrew, if missing:
# /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

brew install git gh node python || true
node --version
npm --version
git --version
gh --version
python3 --version
```

Install GSD/Pi if missing:

```bash
if ! command -v gsd >/dev/null 2>&1; then
  npm install -g @opengsd/gsd-pi
fi

gsd --version
```

Install Codex CLI if you want Codex + safety-net, then verify:

```bash
codex --version
```

## 2. Authenticate GitHub if needed

Needed for private project repos or pushing changes:

```bash
gh auth status || gh auth login -h github.com -p https -w
gh auth setup-git -h github.com
gh auth status
```

Do not commit tokens or auth files.

## 3. Clone your project and this template

```bash
git clone <YOUR_PROJECT_REPO_URL> "$PROJECT_REPO"
git clone https://github.com/enichiforov/gsd-pi-workstation-template "$WORKSTATION_REPO"
```

## 4. Install the workstation profile

```bash
cd "$WORKSTATION_REPO"
./scripts/install.sh --project-repo "$PROJECT_REPO" --overwrite
```

Use `--skip-codex` if this machine does not use Codex.

The installer also creates a `pi` command alias to `gsd` when npm GSD does not publish a `pi` binary. This is needed because some extension runtimes still spawn `pi` directly.

The installer also runs `scripts/patch-gsd-exports.py` by default. That idempotent local patch adds missing export-map entries needed by some community Pi extensions. Use `--skip-gsd-export-patch` only if you intentionally do not want the compatibility patch.

## 5. Verify

```bash
./scripts/verify.sh --project-repo "$PROJECT_REPO"
```

Optional Docker smoke test from this repo, useful before publishing changes:

```bash
./scripts/docker-smoke.sh
```

Expected high-level result:

```text
OK gsd package: git:github.com/hjanuschka/pi-multi-pass
OK gsd package: npm:pi-subagents
OK gsd package: npm:pi-lens
OK gsd package: npm:pi-simplify
OK gsd package: npm:@plannotator/pi-extension
OK gsd package: npm:@narumitw/pi-wait-what
GSD/Pi package exports already compatible or no patch needed
OK npm extension packages
OK safety-net blocks git reset --hard
OK safety-net allows normal rg command
Verification complete.
```

## 6. Restart sessions

Restart any running GSD/Pi/Codex sessions so extensions load at startup.

Useful commands/tools after reload:

- `/wait-what`
- `/plannotator`
- `subagent`
- `module_report`
- `read_symbol`
- `lsp_diagnostics`
- `lens_diagnostics`

## 7. First smoke test

From your project repo:

```bash
cd "$PROJECT_REPO"
git status --short --branch --untracked-files=all
```

Start a fresh GSD/Pi session and ask a read-only codebase question. The agent should use `AGENTS.md`, LSP/AST tools, and targeted reads instead of broad blind file reads.

## Troubleshooting

### A package is missing from `gsd list`

Install it explicitly:

```bash
gsd install npm:pi-lens
gsd install npm:pi-subagents
gsd install npm:pi-simplify
gsd install npm:@plannotator/pi-extension
gsd install npm:@narumitw/pi-wait-what
gsd install git:github.com/hjanuschka/pi-multi-pass
```

### `/wait-what` or `/plannotator` is missing

Restart the GSD/Pi session. Package commands load at startup.

### Codex safety-net is missing

Rerun:

```bash
./scripts/install.sh --project-repo "$PROJECT_REPO" --overwrite
./scripts/verify.sh --project-repo "$PROJECT_REPO"
```

If Codex prompts about hook trust in the TUI, use `/hooks` and trust the safety-net PreToolUse hook.

### `verify.sh` says `pi` is missing

Run the installer again so it can create the `pi -> gsd` alias:

```bash
./scripts/install.sh --project-repo "$PROJECT_REPO" --overwrite
./scripts/verify.sh --project-repo "$PROJECT_REPO"
```

### `verify.sh` says GSD/Pi exports need patching

Run the installer again without `--skip-gsd-export-patch`:

```bash
./scripts/install.sh --project-repo "$PROJECT_REPO" --overwrite
./scripts/verify.sh --project-repo "$PROJECT_REPO"
```
