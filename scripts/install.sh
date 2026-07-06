#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_REPO="${PROJECT_REPO:-$HOME/YourProject}"
OVERWRITE=0
SKIP_CODEX=0

usage() {
  cat <<'USAGE'
Usage: scripts/install.sh [--project-repo PATH] [--overwrite] [--skip-codex]

Installs the GSD/Pi workstation profile on this Mac.

Options:
  --project-repo PATH  Project checkout path (default: ~/YourProject)
  --overwrite          Replace existing AGENTS/settings/template files when different
  --skip-codex         Do not patch Codex config or install safety-net plugin
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-repo) PROJECT_REPO="$2"; shift 2 ;;
    --overwrite) OVERWRITE=1; shift ;;
    --skip-codex) SKIP_CODEX=1; shift ;;
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
    gsd install "$source"
  fi
}

need_cmd git
need_cmd node
need_cmd npm
need_cmd python3
need_cmd gsd

if [[ ! -d "$PROJECT_REPO" ]]; then
  echo "Project repo path does not exist: $PROJECT_REPO" >&2
  echo "Clone your project first or pass --project-repo PATH." >&2
  exit 1
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
install_file "$ROOT/templates/gsd-agent/multi-pass.json" "$HOME/.gsd/agent/multi-pass.json"

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

echo "Install complete. Start a fresh gsd/Pi session, then run scripts/verify.sh."
