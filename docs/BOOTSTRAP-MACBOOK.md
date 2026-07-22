# Bootstrap a MacBook

This checklist sets up a new macOS workstation from an inspectable local clone. It does not restore
credentials or provider auth.

## 1. Install prerequisites

Confirm these commands exist:

```bash
git --version
node --version
npm --version
python3 --version
gsd --version
```

The template expects Node.js 22+, Python 3.9+, and GSD/Pi 1.11+. Install Codex before selecting a
profile containing `codex`. Install `uv` or `pipx` before selecting `graphify`.

Provider authentication is intentionally outside this repository. Sign in using each provider's
normal flow; never copy auth files into the template.

## 2. Clone the template and your project

```bash
mkdir -p "$HOME/code"
git clone https://github.com/enichiforov/gsd-pi-workstation-template.git \
  "$HOME/code/gsd-pi-workstation-template"
git clone <your-project-url> "$HOME/code/your-project"
cd "$HOME/code/gsd-pi-workstation-template"
```

## 3. Choose a profile

```bash
./scripts/install.sh --list-components
```

- `minimal`: instructions/settings only;
- `developer`: navigation, delegation, review, and autonomous Codex;
- `full` (default): complete workstation including marketplaces, Claude GSD, Python skills, and
  Graphify.

Read [Configuration](CONFIGURATION.md) and [Security](SECURITY.md) before choosing `developer` or
`full`. Those profiles intentionally configure Codex for maximum autonomy after safety-net passes.

## 4. Preview and install

```bash
./scripts/install.sh \
  --profile full \
  --project-repo "$HOME/code/your-project" \
  --dry-run

./scripts/install.sh \
  --profile full \
  --project-repo "$HOME/code/your-project"
```

If you do not need every optional layer:

```bash
./scripts/install.sh \
  --profile full \
  --exclude marketplace,graphify \
  --project-repo "$HOME/code/your-project"
```

Existing different managed files are not replaced unless `--overwrite` is explicit.

## 5. Verify the same selection

```bash
./scripts/verify.sh \
  --profile full \
  --project-repo "$HOME/code/your-project"
```

When using overrides, repeat them exactly in verification.

## 6. Restore private state separately

Restore provider auth and secrets through their supported login or secret-management flow. Do not
restore `.gsd` runtime databases, stale npm caches, Codex auth files, browser state, or old session
transcripts from this public repository.

## 7. Validate a real project

From the project checkout:

```bash
cd "$HOME/code/your-project"
gsd --version
pi --version
```

Open the agent, confirm the intended model/provider identity, and begin with a read-only task. For
Codex, confirm the safety-net plugin remains enabled before permitting unattended work.

## Updating later

```bash
cd "$HOME/code/gsd-pi-workstation-template"
git pull --ff-only
./scripts/install.sh --profile full --project-repo "$HOME/code/your-project" --dry-run
./scripts/install.sh --profile full --project-repo "$HOME/code/your-project" --overwrite
./scripts/verify.sh --profile full --project-repo "$HOME/code/your-project"
```

See [Troubleshooting](TROUBLESHOOTING.md) for recovery and partial-install diagnostics.
