#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INVENTORY="$ROOT/manifests/pinned-inventory.json"
read_pin() {
  python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["smoke_test"][sys.argv[2]])' "$INVENTORY" "$1"
}
IMAGE="${IMAGE:-$(read_pin image)}"
GSD_NPM_SPEC="${GSD_NPM_SPEC:-$(read_pin gsd_npm_spec)}"

if ! command -v docker >/dev/null 2>&1; then
  echo "Missing required command: docker" >&2
  exit 1
fi

# GSD_NPM_SPEC is passed as an environment value rather than interpolated into
# the shell program, so caller-controlled package specs cannot change the script.
docker run --rm \
  --env "GSD_NPM_SPEC=$GSD_NPM_SPEC" \
  --volume "$ROOT:/src:ro" \
  "$IMAGE" \
  bash -lc '
set -euo pipefail
export CI=1
show_failure_logs() {
  status=$?
  if [ "$status" -ne 0 ]; then
    echo "Docker smoke failed (exit $status). Captured logs:" >&2
    for log in /tmp/npm-gsd.log /tmp/tests.log /tmp/public-safe.log /tmp/install.log /tmp/verify.log; do
      if [ -f "$log" ]; then
        echo "--- $log ---" >&2
        command tail -80 "$log" >&2
      fi
    done
  fi
  exit "$status"
}
trap show_failure_logs EXIT
command -v git >/dev/null
command -v python3 >/dev/null
npm install -g "$GSD_NPM_SPEC" >/tmp/npm-gsd.log 2>&1
mkdir -p /tmp/dummy-project
cd /tmp/dummy-project
git init -q
printf "# Dummy project\n" >README.md
cp -a /src /tmp/gsd-pi-workstation-template
cd /tmp/gsd-pi-workstation-template
python3 -m unittest discover -s tests -v >/tmp/tests.log 2>&1
python3 scripts/check-public-safe.py >/tmp/public-safe.log
./scripts/install.sh \
  --profile developer \
  --include python-skills \
  --exclude codex \
  --project-repo /tmp/dummy-project \
  --overwrite >/tmp/install.log 2>&1
./scripts/verify.sh \
  --profile developer \
  --include python-skills \
  --exclude codex \
  --project-repo /tmp/dummy-project >/tmp/verify.log 2>&1
load_failures=$(grep -c "Failed to load extension" /tmp/install.log || true)
if [ "$load_failures" != "0" ]; then
  echo "FAIL extension load failures detected: $load_failures" >&2
  grep -n "Failed to load extension" /tmp/install.log >&2 || true
  exit 1
fi
printf "GSD=%s\n" "$(gsd --version)"
printf "PI=%s\n" "$(command -v pi)"
command cat /tmp/public-safe.log
printf "load_failures=%s\n" "$load_failures"
command tail -1 /tmp/verify.log
trap - EXIT
'
