#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_REPO="${PROJECT_REPO:-$HOME/YourProject}"
PROFILE=""
OVERWRITE=0
DRY_RUN=0
INCLUDES=()
EXCLUDES=()
GRAPHIFY_PLATFORMS=(claude codex pi)
STATE_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/gsd-pi-workstation"
RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)-$$"
BACKUP_DIR="$STATE_ROOT/backups/$RUN_ID"
SELECTED_COMPONENTS=()

usage() {
  cat <<'USAGE'
Usage: scripts/install.sh [options]

Install a reproducible GSD/Pi workstation profile on macOS.

Options:
  --project-repo PATH   Project checkout path (default: ~/YourProject)
  --profile NAME        minimal, developer, or full (default: full)
  --include NAMES       Add comma-separated components; repeatable
  --exclude NAMES       Remove comma-separated components; repeatable
  --list-components     Show profiles/components and exit
  --dry-run             Print the resolved plan without changing the machine
  --overwrite           Back up and replace different managed template files
  -h, --help            Show this help

Compatibility aliases (prefer --exclude):
  --skip-codex --skip-gsd-export-patch --skip-plugins --skip-cc-gsd
  --skip-graphify

Examples:
  ./scripts/install.sh --project-repo ~/code/app --dry-run
  ./scripts/install.sh --profile minimal --project-repo ~/code/app
  ./scripts/install.sh --profile developer --include python-skills
  ./scripts/install.sh --profile full --exclude graphify,marketplace
USAGE
}

append_exclude() {
  EXCLUDES+=("$1")
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-repo) PROJECT_REPO="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --include) INCLUDES+=("$2"); shift 2 ;;
    --exclude) EXCLUDES+=("$2"); shift 2 ;;
    --list-components) exec python3 "$ROOT/scripts/profile.py" list ;;
    --dry-run) DRY_RUN=1; shift ;;
    --overwrite) OVERWRITE=1; shift ;;
    --skip-codex) append_exclude codex; shift ;;
    --skip-gsd-export-patch) append_exclude compatibility-patch; shift ;;
    --skip-plugins) append_exclude marketplace; shift ;;
    --skip-cc-gsd) append_exclude claude-gsd; shift ;;
    --skip-graphify) append_exclude graphify; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

profile_args=(resolve)
if [[ -n "$PROFILE" ]]; then
  profile_args+=(--profile "$PROFILE")
fi
for item in "${INCLUDES[@]-}"; do
  [[ -n "$item" ]] && profile_args+=(--include "$item")
done
for item in "${EXCLUDES[@]-}"; do
  [[ -n "$item" ]] && profile_args+=(--exclude "$item")
done
resolved_components="$(python3 "$ROOT/scripts/profile.py" "${profile_args[@]}")"
while IFS= read -r component; do
  [[ -n "$component" ]] && SELECTED_COMPONENTS+=("$component")
done <<<"$resolved_components"

has_component() {
  local wanted="$1" component
  for component in "${SELECTED_COMPONENTS[@]}"; do
    [[ "$component" == "$wanted" ]] && return 0
  done
  return 1
}

print_plan() {
  echo "GSD/Pi workstation installation plan"
  echo "  profile: ${PROFILE:-full}"
  echo "  project: $PROJECT_REPO"
  echo "  overwrite managed files: $OVERWRITE"
  echo "  components:"
  local component
  for component in "${SELECTED_COMPONENTS[@]}"; do
    echo "    - $component"
  done
}

print_plan
if [[ "$DRY_RUN" == "1" ]]; then
  echo "Dry run complete; no changes made."
  exit 0
fi

on_error() {
  local status=$?
  echo "Installation failed (exit $status)." >&2
  if [[ -d "$BACKUP_DIR" ]]; then
    echo "Backups from this run: $BACKUP_DIR" >&2
  fi
  exit "$status"
}
trap on_error ERR

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

backup_file() {
  local path="$1" backup
  [[ -e "$path" ]] || return 0
  backup="$BACKUP_DIR$path"
  if [[ ! -e "$backup" ]]; then
    mkdir -p "$(dirname "$backup")"
    cp -p "$path" "$backup"
    echo "backed up: $path -> $backup"
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
    backup_file "$dst"
  fi
  cp "$src" "$dst"
  echo "installed: $dst"
}

install_gsd_package() {
  local source="$1" log_file
  echo "ensuring pinned gsd package: $source"
  log_file="$(mktemp)"
  if ! gsd install "$source" >"$log_file" 2>&1; then
    command cat "$log_file"
    rm -f "$log_file"
    echo "GSD package installation failed: $source" >&2
    return 1
  fi
  command cat "$log_file"
  if grep -Fq "Failed to load extension" "$log_file"; then
    rm -f "$log_file"
    echo "Extension load failure detected: $source" >&2
    return 1
  fi
  rm -f "$log_file"
}

json_value() {
  local path="$1" expression="$2"
  python3 - "$path" "$expression" <<'PY'
import json
import sys

value = json.load(open(sys.argv[1], encoding="utf-8"))
for key in sys.argv[2].split("."):
    value = value[key]
if isinstance(value, list):
    print("\n".join(str(item) for item in value))
else:
    print(value)
PY
}

require_minimum_version() {
  local label="$1" actual="$2" required="$3"
  if ! python3 -c '
import re
import sys

def parts(value):
    match = re.search(r"(\d+(?:\.\d+)*)", value)
    if match is None:
        raise SystemExit(2)
    return tuple(int(part) for part in match.group(1).split("."))

raise SystemExit(0 if parts(sys.argv[1]) >= parts(sys.argv[2]) else 1)
' "$actual" "$required"; then
    echo "$label $required or newer is required; found: $actual" >&2
    return 1
  fi
  echo "verified $label version: $actual"
}

ensure_pi_command() {
  if command -v pi >/dev/null 2>&1; then
    echo "pi command available: $(command -v pi)"
    return 0
  fi

  local gsd_path gsd_dir user_bin user_shim
  gsd_path="$(command -v gsd)"
  gsd_dir="$(dirname "$gsd_path")"
  if [[ ! -e "$gsd_dir/pi" && -w "$gsd_dir" ]]; then
    ln -s "$gsd_path" "$gsd_dir/pi"
    echo "created pi symlink: $gsd_dir/pi -> $gsd_path"
  fi
  if ! command -v pi >/dev/null 2>&1; then
    user_bin="$HOME/.gsd/agent/bin"
    user_shim="$user_bin/pi"
    if [[ ! -e "$user_shim" ]]; then
      mkdir -p "$user_bin"
      printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' 'exec gsd "$@"' >"$user_shim"
      chmod +x "$user_shim"
      echo "created pi shim: $user_shim"
    fi
    export PATH="$user_bin:$PATH"
  fi
  command -v pi >/dev/null 2>&1 || { echo "Unable to provide a working pi command" >&2; return 1; }
}

install_selected_gsd_packages() {
  local package_args=("${profile_args[@]}" --packages) source package_sources_output
  package_sources_output="$(python3 "$ROOT/scripts/profile.py" "${package_args[@]}")"
  while IFS= read -r source; do
    [[ -n "$source" ]] && install_gsd_package "$source"
  done <<<"$package_sources_output"
}

install_workspace_config() {
  install_file "$ROOT/templates/root/AGENTS.md" "$HOME/AGENTS.md"
  install_file "$ROOT/templates/project/AGENTS.md" "$PROJECT_REPO/AGENTS.md"
  install_file "$ROOT/templates/gsd-agent/settings.json" "$HOME/.gsd/agent/settings.json"
  install_file "$ROOT/templates/gsd-agent/models.json" "$HOME/.gsd/agent/models.json"
  install_file "$ROOT/templates/gsd-agent/multi-pass.json" "$HOME/.gsd/agent/multi-pass.json"

  local legacy="$HOME/.gsd/agent/extensions/subagent"
  if [[ -d "$legacy" ]] && has_component delegation; then
    mkdir -p "$HOME/.gsd/agent/extensions-disabled"
    if [[ -e "$HOME/.gsd/agent/extensions-disabled/subagent-legacy-bundled" ]]; then
      echo "legacy subagent extension already disabled"
    else
      mv "$legacy" "$HOME/.gsd/agent/extensions-disabled/subagent-legacy-bundled"
      echo "disabled legacy bundled subagent extension"
    fi
  fi
}

install_python_skills() {
  local args=(
    "$ROOT/scripts/python-skills.py"
    --manifest "$ROOT/manifests/python-skills.json"
    --source "$ROOT/templates/agents-skills"
    install
    --destination "$HOME/.agents/skills"
    --backup-root "$BACKUP_DIR"
  )
  if [[ "$OVERWRITE" == "1" ]]; then
    args+=(--overwrite)
  fi
  python3 "${args[@]}"
}

install_claude_gsd() {
  local version
  version="$(json_value "$ROOT/manifests/pinned-inventory.json" pinned_dependencies.get-shit-done-cc)"
  echo "installing Claude Code GSD layer: get-shit-done-cc@$version"
  npm install -g "get-shit-done-cc@$version"
  need_cmd get-shit-done-cc
  get-shit-done-cc --claude --global
}

codex_marketplace_root() {
  local name="$1"
  codex plugin marketplace list --json | python3 -c '
import json
import sys
name = sys.argv[1]
for marketplace in json.load(sys.stdin).get("marketplaces", []):
    if marketplace.get("name") == name:
        print(marketplace.get("root", ""))
        break
' "$name"
}

ensure_codex_marketplace() {
  local source="$1" ref="$2" name="$3" root=""
  root="$(codex_marketplace_root "$name")"
  if [[ -n "$root" ]] && { [[ ! -d "$root/.git" ]] || [[ "$(git -C "$root" rev-parse HEAD)" != "$ref" ]]; }; then
    echo "refreshing Codex marketplace at pinned ref: $name@$ref"
    codex plugin marketplace remove "$name" >/dev/null
    root=""
  fi
  if [[ -z "$root" ]]; then
    codex plugin marketplace add "$source" --ref "$ref" >/dev/null
    root="$(codex_marketplace_root "$name")"
  fi
  [[ -d "$root/.git" ]] || { echo "Codex marketplace is not a Git snapshot: $name" >&2; return 1; }
  [[ "$(git -C "$root" rev-parse HEAD)" == "$ref" ]] || {
    echo "Codex marketplace did not resolve to pinned ref: $name@$ref" >&2
    return 1
  }
  echo "verified Codex marketplace: $name@$ref"
}

claude_marketplace_location() {
  local name="$1"
  claude plugin marketplace list --json | python3 -c '
import json
import sys
name = sys.argv[1]
for marketplace in json.load(sys.stdin):
    if marketplace.get("name") == name:
        print(marketplace.get("installLocation", ""))
        break
' "$name"
}

ensure_claude_marketplace() {
  local snapshot="$1" ref="$2" name="$3" location=""
  location="$(claude_marketplace_location "$name")"
  if [[ -n "$location" ]] && { [[ ! -d "$location/.git" ]] || [[ "$(git -C "$location" rev-parse HEAD)" != "$ref" ]]; }; then
    echo "refreshing Claude marketplace at pinned ref: $name@$ref"
    claude plugin marketplace remove "$name" >/dev/null
    location=""
  fi
  if [[ -z "$location" ]]; then
    claude plugin marketplace add "$snapshot" >/dev/null
    location="$(claude_marketplace_location "$name")"
  fi
  [[ -n "$location" ]] || { echo "Claude marketplace was not registered: $name" >&2; return 1; }
  if [[ -d "$location/.git" ]] && [[ "$(git -C "$location" rev-parse HEAD)" != "$ref" ]]; then
    echo "Claude marketplace did not resolve to pinned ref: $name@$ref" >&2
    return 1
  fi
  [[ "$(git -C "$snapshot" rev-parse HEAD)" == "$ref" ]] || {
    echo "Claude marketplace source snapshot changed unexpectedly: $name@$ref" >&2
    return 1
  }
  echo "verified Claude marketplace: $name@$ref"
}

prepare_git_snapshot() {
  local repository="$1" ref="$2" name="$3"
  local cache_root="${XDG_CACHE_HOME:-$HOME/.cache}/gsd-pi-workstation/marketplaces"
  local destination="$cache_root/$name-$ref"
  if [[ ! -d "$destination/.git" ]]; then
    mkdir -p "$cache_root"
    git clone --filter=blob:none --no-checkout "https://github.com/$repository.git" "$destination" >&2
  fi
  git -C "$destination" fetch --depth 1 origin "$ref" >&2
  git -C "$destination" checkout --detach "$ref" >&2
  [[ "$(git -C "$destination" rev-parse HEAD)" == "$ref" ]] || {
    echo "Marketplace snapshot did not resolve to pinned ref: $repository@$ref" >&2
    return 1
  }
  printf '%s\n' "$destination"
}

install_coding_plugins() {
  local manifest="$ROOT/manifests/marketplace-plugins.json"
  local source name ref plugin installed claude_snapshot
  source="$(json_value "$manifest" marketplace.source)"
  name="$(json_value "$manifest" marketplace.name)"
  ref="$(json_value "$manifest" marketplace.ref)"

  if command -v claude >/dev/null 2>&1; then
    claude_snapshot="$(prepare_git_snapshot "$source" "$ref" "$name")"
    ensure_claude_marketplace "$claude_snapshot" "$ref" "$name"
    installed="$(claude plugin list 2>/dev/null || true)"
    while IFS= read -r plugin; do
      [[ -n "$plugin" ]] || continue
      if grep -Fq "${plugin}@${name}" <<<"$installed"; then
        echo "claude plugin already installed: ${plugin}@${name}"
      else
        echo "installing claude plugin: ${plugin}@${name}"
        claude plugin install "${plugin}@${name}" >/dev/null
      fi
    done < <(json_value "$manifest" claude_plugins)
  else
    echo "WARN claude not found; Claude marketplace plugins were not installed" >&2
  fi

  if command -v codex >/dev/null 2>&1; then
    ensure_codex_marketplace "$source" "$ref" "$name"
    installed="$(codex plugin list 2>/dev/null || true)"
    while IFS= read -r plugin; do
      [[ -n "$plugin" ]] || continue
      if grep -Fq "${plugin}@${name}" <<<"$installed"; then
        echo "codex plugin already installed: ${plugin}@${name}"
      else
        echo "installing codex plugin: ${plugin}@${name}"
        codex plugin add "${plugin}@${name}" >/dev/null
      fi
    done < <(json_value "$manifest" codex_plugins)
  else
    echo "WARN codex not found; Codex marketplace plugins were not installed" >&2
  fi
}

install_graphify() {
  local version
  version="$(json_value "$ROOT/manifests/pinned-inventory.json" pinned_dependencies.graphifyy)"
  if command -v uv >/dev/null 2>&1; then
    uv tool install --force "graphifyy==$version"
  elif command -v pipx >/dev/null 2>&1; then
    pipx install --force "graphifyy==$version"
  else
    echo "Graphify requires uv or pipx so its pinned version can be enforced; install one or exclude graphify" >&2
    return 1
  fi
  command -v graphify >/dev/null 2>&1 || {
    echo "Graphify installed outside PATH; open a new shell and rerun, or exclude graphify" >&2
    return 1
  }
  local platform
  for platform in "${GRAPHIFY_PLATFORMS[@]}"; do
    if [[ "$platform" == codex ]] && ! has_component codex; then
      continue
    fi
    graphify install --platform "$platform" >/dev/null
    echo "registered graphify skill for: $platform"
  done
}

install_codex_safety_net() {
  need_cmd codex
  local npm_dir="$HOME/.gsd/agent/npm"
  local inventory="$ROOT/manifests/pinned-inventory.json"
  local marketplace_source marketplace_ref version
  marketplace_source="$(json_value "$inventory" codex_safety_net.marketplace)"
  marketplace_ref="$(json_value "$inventory" codex_safety_net.ref)"
  version="$(json_value "$inventory" pinned_dependencies.cc-safety-net)"

  mkdir -p "$npm_dir"
  if [[ ! -f "$npm_dir/package.json" ]]; then
    printf '%s\n' '{"private":true}' >"$npm_dir/package.json"
  fi
  (cd "$npm_dir" && npm install --save-exact "cc-safety-net@$version")

  ensure_codex_marketplace "$marketplace_source" "$marketplace_ref" cc-marketplace
  codex plugin add safety-net@cc-marketplace >/dev/null
  if ! codex plugin list --json 2>/dev/null | grep -Fq 'safety-net@cc-marketplace'; then
    echo "Codex safety-net plugin is not visible after installation" >&2
    return 1
  fi
  if ! (cd "$npm_dir" && npx cc-safety-net explain "git reset --hard" 2>/dev/null | grep -Fq 'Status: BLOCKED'); then
    echo "Safety-net self-test did not block git reset --hard" >&2
    return 1
  fi
  echo "verified Codex safety-net"
}

configure_codex_autonomy() {
  local config="$HOME/.codex/config.toml"
  backup_file "$config"
  python3 "$ROOT/scripts/patch-codex-config.py" "$config" --project-repo "$PROJECT_REPO"
  grep -Eq '^approval_policy = "never"$' "$config"
  grep -Eq '^sandbox_mode = "danger-full-access"$' "$config"
  echo "configured autonomous Codex defaults after safety-net verification"
}

need_cmd git
need_cmd node
need_cmd npm
need_cmd python3
need_cmd gsd
inventory="$ROOT/manifests/pinned-inventory.json"
require_minimum_version "Node.js" "$(node --version)" "$(json_value "$inventory" minimum_versions.node)"
require_minimum_version "GSD/Pi" "$(gsd --version)" "$(json_value "$inventory" minimum_versions.gsd)"
require_minimum_version "Python" "$(python3 --version)" "3.9"
ensure_pi_command

if { has_component workspace-config || has_component codex; } && [[ ! -d "$PROJECT_REPO" ]]; then
  echo "Project repo path does not exist: $PROJECT_REPO" >&2
  echo "Clone the project first or pass --project-repo PATH." >&2
  exit 1
fi

if has_component compatibility-patch; then
  python3 "$ROOT/scripts/patch-gsd-exports.py"
fi

install_selected_gsd_packages

if has_component claude-gsd; then install_claude_gsd; fi
if has_component workspace-config; then install_workspace_config; fi
if has_component python-skills; then install_python_skills; fi
if has_component codex-safety-net; then install_codex_safety_net; fi
if has_component codex; then configure_codex_autonomy; fi
if has_component marketplace; then install_coding_plugins; fi
if has_component graphify; then install_graphify; fi

mkdir -p "$STATE_ROOT"
{
  echo "run_id=$RUN_ID"
  echo "profile=${PROFILE:-full}"
  echo "project_repo=$PROJECT_REPO"
  printf 'components=%s\n' "$(IFS=,; echo "${SELECTED_COMPONENTS[*]}")"
  if [[ -d "$BACKUP_DIR" ]]; then echo "backup_dir=$BACKUP_DIR"; fi
} >"$STATE_ROOT/last-install.txt"

trap - ERR
echo "Install complete."
echo "Verify with: $ROOT/scripts/verify.sh --project-repo '$PROJECT_REPO' --profile '${PROFILE:-full}'"
