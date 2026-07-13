#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_REPO="${PROJECT_REPO:-$HOME/YourProject}"

usage() {
  cat <<'USAGE'
Usage: scripts/verify.sh [--project-repo PATH]

Read-only verification for the GSD/Pi workstation profile.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-repo) PROJECT_REPO="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "FAIL missing command: $1" >&2
    exit 1
  fi
}

require_file() {
  if [[ ! -f "$1" ]]; then
    echo "FAIL missing file: $1" >&2
    exit 1
  fi
  echo "OK file: $1"
}

require_cmd gsd
require_cmd pi
require_cmd npm
require_cmd node
require_cmd python3

if ! pi --version >/dev/null 2>&1; then
  echo "FAIL pi command exists but does not run" >&2
  exit 1
fi

if ! python3 "$ROOT/scripts/patch-gsd-exports.py" --check; then
  echo "FAIL GSD/Pi package exports need compatibility patching." >&2
  echo "Run: $ROOT/scripts/install.sh --project-repo '$PROJECT_REPO' --overwrite" >&2
  exit 1
fi

packages=(
  "git:github.com/hjanuschka/pi-multi-pass"
  "npm:pi-subagents"
  "npm:pi-lens"
  "npm:pi-simplify"
  "npm:@plannotator/pi-extension"
  "npm:@narumitw/pi-wait-what"
)

gsd_list="$(gsd list)"
for pkg in "${packages[@]}"; do
  if grep -Fq "$pkg" <<<"$gsd_list"; then
    echo "OK gsd package: $pkg"
  else
    echo "FAIL missing gsd package: $pkg" >&2
    exit 1
  fi
done

require_file "$HOME/AGENTS.md"
require_file "$PROJECT_REPO/AGENTS.md"
require_file "$HOME/.gsd/agent/settings.json"
require_file "$HOME/.gsd/agent/models.json"
require_file "$HOME/.gsd/agent/multi-pass.json"

if [[ -d "$HOME/.gsd/agent/npm" ]]; then
  (cd "$HOME/.gsd/agent/npm" && npm ls --depth=0 \
    pi-subagents \
    pi-lens \
    pi-simplify \
    @plannotator/pi-extension \
    @narumitw/pi-wait-what \
    cc-safety-net >/dev/null)
  echo "OK npm extension packages"
else
  echo "FAIL missing ~/.gsd/agent/npm" >&2
  exit 1
fi

if command -v codex >/dev/null 2>&1; then
  if codex plugin list --json 2>/dev/null | grep -Fq 'safety-net@cc-marketplace'; then
    echo "OK Codex safety-net plugin installed"
  else
    echo "FAIL Codex safety-net plugin missing" >&2
    exit 1
  fi
else
  echo "WARN codex not found; skipped Codex plugin verification"
fi

# Coding-workflow marketplace plugins ("how to write good code"), reproduced from
# public git. Guard on a representative plugin; marketplace-agnostic so it holds
# whether resolved as @claude-code-workflows (clone) or a pre-existing name.
if command -v claude >/dev/null 2>&1; then
  if claude plugin list 2>/dev/null | grep -Eq 'python-development@'; then
    echo "OK Claude coding plugins present (python-development)"
  else
    echo "FAIL Claude coding plugins missing (run install.sh)" >&2
    exit 1
  fi
else
  echo "WARN claude not found; skipped Claude coding plugin verification"
fi

if command -v codex >/dev/null 2>&1; then
  if codex plugin list 2>/dev/null | awk '/python-development@/ && /installed/{f=1} END{exit f?0:1}'; then
    echo "OK Codex coding plugins present (python-development)"
  else
    echo "FAIL Codex coding plugins missing (run install.sh)" >&2
    exit 1
  fi
fi

skills_dir="$HOME/.agents/skills"
required_skills=(
  python-architecture-patterns
  python-async-concurrency-deep-dive
  python-code-quality-fundamentals
  python-database-patterns
  python-debugging-and-observability
  python-environment-and-config
  python-performance-optimization
  python-testing-and-mocks
)
for skill in "${required_skills[@]}"; do
  if [[ -f "$skills_dir/$skill/SKILL.md" ]]; then
    echo "OK agent skill: $skill"
  else
    echo "FAIL missing agent skill: $skills_dir/$skill/SKILL.md" >&2
    exit 1
  fi
done

# Claude Code GSD layer (get-shit-done-cc). Guard on canonical subagents. If the
# agents dir is absent, the layer was skipped (--skip-cc-gsd) or this is not a CC
# machine — WARN and continue. If it exists, a missing canonical agent means a
# broken install → FAIL.
cc_agents_dir="$HOME/.claude/agents"
required_cc_agents=(gsd-planner gsd-executor gsd-verifier)
if [[ -d "$cc_agents_dir" ]]; then
  for agent in "${required_cc_agents[@]}"; do
    if [[ -f "$cc_agents_dir/$agent.md" ]]; then
      echo "OK Claude Code GSD agent: $agent"
    else
      echo "FAIL missing Claude Code GSD agent: $cc_agents_dir/$agent.md (run install.sh)" >&2
      exit 1
    fi
  done
else
  echo "WARN $cc_agents_dir not present; skipped Claude Code GSD layer verification"
fi

# graphify knowledge-graph CLI/skill is a reference-install (optional uv/pipx
# tooling), so a missing CLI is a WARN, not a FAIL. When present, confirm the
# skill was registered for Claude Code.
if command -v graphify >/dev/null 2>&1; then
  echo "OK graphify CLI: $(command -v graphify)"
  if [[ -f "$HOME/.claude/skills/graphify/SKILL.md" ]]; then
    echo "OK graphify skill registered (claude)"
  else
    echo "WARN graphify CLI present but skill not registered; run: graphify install"
  fi
else
  echo "WARN graphify not found; run install.sh (needs uv or pipx) or skip with --skip-graphify"
fi

if (cd "$HOME/.gsd/agent/npm" && npx cc-safety-net explain "git reset --hard" 2>/dev/null | grep -Fq 'Status: BLOCKED'); then
  echo "OK safety-net blocks git reset --hard"
else
  echo "FAIL safety-net did not block git reset --hard in explain mode" >&2
  exit 1
fi

if (cd "$HOME/.gsd/agent/npm" && npx cc-safety-net explain "rg pi-lens AGENTS.md" 2>/dev/null | grep -Fq 'Status: ALLOWED'); then
  echo "OK safety-net allows normal rg command"
else
  echo "FAIL safety-net did not allow normal rg command in explain mode" >&2
  exit 1
fi

echo "Verification complete. Restart gsd/Pi sessions to load command extensions."
