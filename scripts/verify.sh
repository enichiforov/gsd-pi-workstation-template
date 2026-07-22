#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_REPO="${PROJECT_REPO:-$HOME/YourProject}"
PROFILE=""
INCLUDES=()
EXCLUDES=()
SELECTED_COMPONENTS=()

usage() {
  cat <<'USAGE'
Usage: scripts/verify.sh [options]

Read-only verification for one resolved workstation profile.

Options:
  --project-repo PATH   Project checkout path (default: ~/YourProject)
  --profile NAME        minimal, developer, or full (default: full)
  --include NAMES       Add comma-separated components; repeatable
  --exclude NAMES       Remove comma-separated components; repeatable
  -h, --help            Show this help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-repo) PROJECT_REPO="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --include) INCLUDES+=("$2"); shift 2 ;;
    --exclude) EXCLUDES+=("$2"); shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

profile_args=(resolve)
if [[ -n "$PROFILE" ]]; then profile_args+=(--profile "$PROFILE"); fi
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

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "FAIL missing command: $1" >&2
    exit 1
  fi
  echo "OK command: $1"
}

require_file() {
  if [[ ! -f "$1" ]]; then
    echo "FAIL missing file: $1" >&2
    exit 1
  fi
  echo "OK file: $1"
}

require_contains() {
  local path="$1" value="$2" label="$3"
  if grep -Fq "$value" "$path"; then
    echo "OK $label"
  else
    echo "FAIL $label ($path)" >&2
    exit 1
  fi
}

json_value() {
  local path="$1" expression="$2"
  python3 -c '
import json
import sys
value = json.load(open(sys.argv[1], encoding="utf-8"))
for key in sys.argv[2].split("."):
    value = value[key]
print(value)
' "$path" "$expression"
}

require_minimum_version() {
  local label="$1" actual="$2" required="$3"
  python3 -c '
import re
import sys

def parts(value):
    match = re.search(r"(\d+(?:\.\d+)*)", value)
    if match is None:
        raise SystemExit(2)
    return tuple(int(part) for part in match.group(1).split("."))

raise SystemExit(0 if parts(sys.argv[1]) >= parts(sys.argv[2]) else 1)
' "$actual" "$required" || {
    echo "FAIL $label $required or newer required; found: $actual" >&2
    return 1
  }
  echo "OK $label version: $actual"
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

verify_codex_marketplace_ref() {
  local name="$1" expected="$2" root actual
  root="$(codex_marketplace_root "$name")"
  [[ -d "$root/.git" ]] || { echo "FAIL Codex marketplace missing: $name" >&2; return 1; }
  actual="$(git -C "$root" rev-parse HEAD)"
  [[ "$actual" == "$expected" ]] || {
    echo "FAIL Codex marketplace $name ref $actual; expected $expected" >&2
    return 1
  }
  echo "OK pinned Codex marketplace: $name@$expected"
}

echo "Verifying profile: ${PROFILE:-full}"
echo "Components: $(IFS=,; echo "${SELECTED_COMPONENTS[*]}")"

require_cmd gsd
require_cmd pi
require_cmd git
require_cmd npm
require_cmd node
require_cmd python3
inventory="$ROOT/manifests/pinned-inventory.json"
require_minimum_version "Node.js" "$(node --version)" "$(json_value "$inventory" minimum_versions.node)"
require_minimum_version "GSD/Pi" "$(gsd --version)" "$(json_value "$inventory" minimum_versions.gsd)"
require_minimum_version "Python" "$(python3 --version)" "3.9"
pi --version >/dev/null 2>&1 || { echo "FAIL pi command exists but does not run" >&2; exit 1; }

if has_component compatibility-patch; then
  python3 "$ROOT/scripts/patch-gsd-exports.py" --check
  echo "OK GSD/Pi exports compatibility"
fi

verify_gsd_package() {
  local source="$1" spec name expected manifest actual repository checkout
  case "$source" in
    npm:*)
      spec="${source#npm:}"
      expected="${spec##*@}"
      name="${spec%@"$expected"}"
      manifest="$HOME/.gsd/agent/npm/node_modules/$name/package.json"
      [[ -f "$manifest" ]] || { echo "FAIL missing pinned gsd package: $source" >&2; return 1; }
      actual="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$manifest")"
      [[ "$actual" == "$expected" ]] || {
        echo "FAIL gsd package $name version $actual; expected $expected" >&2
        return 1
      }
      ;;
    git:github.com/*)
      spec="${source#git:github.com/}"
      expected="${spec##*@}"
      repository="${spec%@"$expected"}"
      checkout="$HOME/.gsd/agent/git/github.com/$repository"
      [[ -d "$checkout/.git" ]] || { echo "FAIL missing pinned gsd package: $source" >&2; return 1; }
      actual="$(git -C "$checkout" rev-parse HEAD)"
      [[ "$actual" == "$expected" ]] || {
        echo "FAIL gsd package $repository ref $actual; expected $expected" >&2
        return 1
      }
      ;;
    *)
      echo "FAIL unsupported package source in manifest: $source" >&2
      return 1
      ;;
  esac
  echo "OK pinned gsd package: $source"
}

package_args=("${profile_args[@]}" --packages)
package_sources_output="$(python3 "$ROOT/scripts/profile.py" "${package_args[@]}")"
while IFS= read -r package; do
  [[ -n "$package" ]] && verify_gsd_package "$package"
done <<<"$package_sources_output"

if has_component workspace-config; then
  [[ -d "$PROJECT_REPO" ]] || { echo "FAIL project path does not exist: $PROJECT_REPO" >&2; exit 1; }
  require_file "$HOME/AGENTS.md"
  require_file "$PROJECT_REPO/AGENTS.md"
  require_file "$HOME/.gsd/agent/settings.json"
  require_file "$HOME/.gsd/agent/models.json"
  require_file "$HOME/.gsd/agent/multi-pass.json"
fi

if has_component codex-safety-net; then
  require_cmd codex
  inventory="$ROOT/manifests/pinned-inventory.json"
  expected_safety_version="$(json_value "$inventory" pinned_dependencies.cc-safety-net)"
  safety_manifest="$HOME/.gsd/agent/npm/node_modules/cc-safety-net/package.json"
  require_file "$safety_manifest"
  actual_safety_version="$(json_value "$safety_manifest" version)"
  [[ "$actual_safety_version" == "$expected_safety_version" ]] || {
    echo "FAIL cc-safety-net version $actual_safety_version; expected $expected_safety_version" >&2
    exit 1
  }
  verify_codex_marketplace_ref cc-marketplace "$(json_value "$inventory" codex_safety_net.ref)"
  if codex plugin list --json 2>/dev/null | grep -Fq 'safety-net@cc-marketplace'; then
    echo "OK Codex safety-net plugin installed"
  else
    echo "FAIL Codex safety-net plugin missing" >&2
    exit 1
  fi
  if (cd "$HOME/.gsd/agent/npm" && npx cc-safety-net explain "git reset --hard" 2>/dev/null | grep -Fq 'Status: BLOCKED'); then
    echo "OK safety-net blocks git reset --hard"
  else
    echo "FAIL safety-net did not block git reset --hard" >&2
    exit 1
  fi
fi

if has_component codex; then
  require_file "$HOME/.codex/config.toml"
  require_contains "$HOME/.codex/config.toml" 'approval_policy = "never"' "Codex approval policy"
  require_contains "$HOME/.codex/config.toml" 'sandbox_mode = "danger-full-access"' "Codex sandbox mode"
fi

if has_component marketplace; then
  if command -v claude >/dev/null 2>&1; then
    claude plugin list 2>/dev/null | grep -Eq 'python-development@' \
      || { echo "FAIL Claude coding plugins missing" >&2; exit 1; }
    echo "OK Claude coding plugins"
  else
    echo "WARN claude not found; skipped Claude marketplace verification" >&2
  fi
  if command -v codex >/dev/null 2>&1; then
    coding_ref="$(json_value "$ROOT/manifests/marketplace-plugins.json" marketplace.ref)"
    coding_name="$(json_value "$ROOT/manifests/marketplace-plugins.json" marketplace.name)"
    verify_codex_marketplace_ref "$coding_name" "$coding_ref"
    codex plugin list 2>/dev/null | grep -Eq 'python-development@' \
      || { echo "FAIL Codex coding plugins missing" >&2; exit 1; }
    echo "OK Codex coding plugins"
  else
    echo "WARN codex not found; skipped Codex marketplace verification" >&2
  fi
fi

if has_component python-skills; then
  python3 "$ROOT/scripts/python-skills.py" \
    --manifest "$ROOT/manifests/python-skills.json" \
    --source "$ROOT/templates/agents-skills" \
    verify \
    --destination "$HOME/.agents/skills"
fi

if has_component claude-gsd; then
  for agent in gsd-planner gsd-executor gsd-verifier; do
    require_file "$HOME/.claude/agents/$agent.md"
  done
fi

if has_component graphify; then
  require_cmd graphify
  require_file "$HOME/.claude/skills/graphify/SKILL.md"
  if has_component codex; then
    require_file "$HOME/.codex/skills/graphify/SKILL.md"
  fi
fi

python3 "$ROOT/scripts/check-public-safe.py"
echo "Verification complete: ${PROFILE:-full} profile is ready."
