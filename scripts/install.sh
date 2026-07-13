#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_REPO="${PROJECT_REPO:-$HOME/YourProject}"
OVERWRITE=0
SKIP_CODEX=0
SKIP_GSD_EXPORT_PATCH=0
SKIP_PLUGINS=0

usage() {
  cat <<'USAGE'
Usage: scripts/install.sh [--project-repo PATH] [--overwrite] [--skip-codex]

Installs the GSD/Pi workstation profile on this Mac.

Options:
  --project-repo PATH  Project checkout path (default: ~/YourProject)
  --overwrite              Replace existing AGENTS/settings/template files when different
  --skip-codex             Do not patch Codex config or install safety-net plugin
  --skip-gsd-export-patch  Do not patch GSD/Pi package exports for community extensions
  --skip-plugins           Do not install coding-workflow marketplace plugins
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-repo) PROJECT_REPO="$2"; shift 2 ;;
    --overwrite) OVERWRITE=1; shift ;;
    --skip-codex) SKIP_CODEX=1; shift ;;
    --skip-gsd-export-patch) SKIP_GSD_EXPORT_PATCH=1; shift ;;
    --skip-plugins) SKIP_PLUGINS=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

install_file() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [[ -e "$dst" ]]; then
    if cmp -s "$src" "$dst"; then
      echo "unchanged: $dst"
      return 0
    fi
    if [[ "$OVERWRITE" != "1" ]]; then
      echo "exists/different, skipped without --overwrite: $dst" >&2
      return 0
    fi
  fi
  cp "$src" "$dst"
  echo "installed: $dst"
}

install_gsd_package() {
  local source="$1"
  if gsd list 2>/dev/null | grep -Fq "$source"; then
    echo "gsd package already registered: $source"
  else
    echo "installing gsd package: $source"
    local log_file
    log_file="$(mktemp)"
    if ! gsd install "$source" >"$log_file" 2>&1; then
      cat "$log_file"
      rm -f "$log_file"
      echo "FAIL gsd install failed for: $source" >&2
      exit 1
    fi
    cat "$log_file"
    if grep -Fq "Failed to load extension" "$log_file"; then
      rm -f "$log_file"
      echo "FAIL extension load failure detected while installing: $source" >&2
      echo "Try rerunning without --skip-gsd-export-patch, or inspect scripts/patch-gsd-exports.py." >&2
      exit 1
    fi
    rm -f "$log_file"
  fi
}

manifest_field() {
  # $1 = python expression against the parsed manifest dict `d`
  python3 -c "import json; d=json.load(open('$ROOT/manifests/marketplace-plugins.json')); print($1)"
}

install_coding_plugins() {
  local manifest="$ROOT/manifests/marketplace-plugins.json"
  if [[ ! -f "$manifest" ]]; then
    echo "no manifests/marketplace-plugins.json; skipping coding-workflow plugins"
    return 0
  fi
  local mp_source mp_name
  mp_source="$(manifest_field "d['marketplace']['source']")"
  mp_name="$(manifest_field "d['marketplace']['name']")"

  # Claude Code coding plugins (git-native marketplace, no vendored plugin code).
  if command -v claude >/dev/null 2>&1; then
    claude plugin marketplace add "$mp_source" >/dev/null 2>&1 || true
    local claude_installed
    claude_installed="$(claude plugin list 2>/dev/null || true)"
    while IFS= read -r name; do
      [[ -z "$name" ]] && continue
      if grep -Fq "${name}@${mp_name}" <<<"$claude_installed"; then
        echo "claude plugin already installed: ${name}@${mp_name}"
      else
        echo "installing claude plugin: ${name}@${mp_name}"
        claude plugin install "${name}@${mp_name}" >/dev/null 2>&1 \
          || echo "WARN claude plugin install failed: ${name}@${mp_name}" >&2
      fi
    done < <(manifest_field "'\n'.join(d['claude_plugins'])")
  else
    echo "claude not found; skipped Claude coding plugins" >&2
  fi

  # Codex coding plugins — same public marketplace, resolved git-native.
  if [[ "$SKIP_CODEX" != "1" ]] && command -v codex >/dev/null 2>&1; then
    codex plugin marketplace add "$mp_source" >/dev/null 2>&1 || true
    local codex_list
    codex_list="$(codex plugin list 2>/dev/null || true)"
    while IFS= read -r name; do
      [[ -z "$name" ]] && continue
      if awk -v p="${name}@${mp_name}" '$1==p && /installed/{f=1} END{exit f?0:1}' <<<"$codex_list"; then
        echo "codex plugin already installed: ${name}@${mp_name}"
      else
        echo "installing codex plugin: ${name}@${mp_name}"
        codex plugin add "${name}@${mp_name}" >/dev/null 2>&1 \
          || echo "WARN codex plugin add failed: ${name}@${mp_name}" >&2
      fi
    done < <(manifest_field "'\n'.join(d['codex_plugins'])")
  fi
}

ensure_pi_command() {
  if command -v pi >/dev/null 2>&1; then
    echo "pi command available: $(command -v pi)"
    return
  fi

  local gsd_path gsd_dir user_bin user_shim
  gsd_path="$(command -v gsd)"
  gsd_dir="$(dirname "$gsd_path")"

  # Prefer a real PATH-level alias next to gsd, so clean shells and child
  # runtimes that spawn `pi` do not depend on shell startup files.
  if [[ ! -e "$gsd_dir/pi" && -w "$gsd_dir" ]]; then
    ln -s "$gsd_path" "$gsd_dir/pi"
    echo "created pi symlink: $gsd_dir/pi -> $gsd_path"
  fi

  # Fallback for user-scoped GSD sessions. This path is first in the default
  # GSD agent PATH on this workstation profile.
  if ! command -v pi >/dev/null 2>&1; then
    user_bin="$HOME/.gsd/agent/bin"
    user_shim="$user_bin/pi"
    if [[ ! -e "$user_shim" ]]; then
      mkdir -p "$user_bin"
      cat >"$user_shim" <<'SHIM'
#!/usr/bin/env bash
set -euo pipefail
exec gsd "$@"
SHIM
      chmod +x "$user_shim"
      echo "created pi shim: $user_shim"
    fi
  fi

  if command -v pi >/dev/null 2>&1; then
    echo "pi command available: $(command -v pi)"
  else
    echo "FAIL could not make 'pi' available on current PATH" >&2
    echo "Ensure either $gsd_dir/pi or $user_shim is on PATH." >&2
    exit 1
  fi
}

need_cmd git
need_cmd node
need_cmd npm
need_cmd python3
need_cmd gsd
ensure_pi_command

if [[ ! -d "$PROJECT_REPO" ]]; then
  echo "Project repo path does not exist: $PROJECT_REPO" >&2
  echo "Clone your project first or pass --project-repo PATH." >&2
  exit 1
fi

if [[ "$SKIP_GSD_EXPORT_PATCH" != "1" ]]; then
  python3 "$ROOT/scripts/patch-gsd-exports.py"
fi

while IFS= read -r source; do
  [[ -z "$source" || "$source" =~ ^# ]] && continue
  install_gsd_package "$source"
done < "$ROOT/manifests/gsd-packages.txt"

if [[ -d "$HOME/.gsd/agent/npm" ]]; then
  echo "pinning npm package versions in ~/.gsd/agent/npm"
  (cd "$HOME/.gsd/agent/npm" && npm install \
    pi-subagents@0.33.1 \
    pi-lens@3.8.65 \
    pi-simplify@0.2.2 \
    @plannotator/pi-extension@0.22.0 \
    @narumitw/pi-wait-what@0.11.0 \
    cc-safety-net@1.0.6)
fi

install_file "$ROOT/templates/root/AGENTS.md" "$HOME/AGENTS.md"
install_file "$ROOT/templates/project/AGENTS.md" "$PROJECT_REPO/AGENTS.md"
install_file "$ROOT/templates/gsd-agent/settings.json" "$HOME/.gsd/agent/settings.json"
install_file "$ROOT/templates/gsd-agent/models.json" "$HOME/.gsd/agent/models.json"
install_file "$ROOT/templates/gsd-agent/multi-pass.json" "$HOME/.gsd/agent/multi-pass.json"

# Install portable python-* development skills into the agent skills dir.
# These live in ~/.agents/skills, are not in any npm package, and do not
# survive a fresh machine unless vendored here.
if [[ -d "$ROOT/templates/agents-skills" ]]; then
  for skill_md in "$ROOT"/templates/agents-skills/*/SKILL.md; do
    [[ -e "$skill_md" ]] || continue
    skill_name="$(basename "$(dirname "$skill_md")")"
    install_file "$skill_md" "$HOME/.agents/skills/$skill_name/SKILL.md"
  done
fi

# Let pi-subagents own the subagent tool if an older bundled extension exists.
if [[ -d "$HOME/.gsd/agent/extensions/subagent" ]]; then
  mkdir -p "$HOME/.gsd/agent/extensions-disabled"
  if [[ -e "$HOME/.gsd/agent/extensions-disabled/subagent-legacy-bundled" ]]; then
    echo "legacy subagent extension already disabled target exists"
  else
    mv "$HOME/.gsd/agent/extensions/subagent" "$HOME/.gsd/agent/extensions-disabled/subagent-legacy-bundled"
    echo "disabled legacy bundled subagent extension"
  fi
fi

if [[ "$SKIP_CODEX" != "1" ]]; then
  if command -v codex >/dev/null 2>&1; then
    python3 "$ROOT/scripts/patch-codex-config.py" "$HOME/.codex/config.toml" --project-repo "$PROJECT_REPO"
    codex plugin marketplace add kenryu42/cc-marketplace >/dev/null 2>&1 || true
    codex plugin marketplace upgrade cc-marketplace >/dev/null 2>&1 || true
    codex plugin add safety-net@cc-marketplace >/dev/null 2>&1 || true
    echo "Codex safety-net plugin configured"
  else
    echo "codex not found; skipped Codex safety-net config" >&2
  fi
fi

if [[ "$SKIP_PLUGINS" != "1" ]]; then
  install_coding_plugins
fi

echo "Install complete. Start a fresh gsd/Pi session, then run scripts/verify.sh."
