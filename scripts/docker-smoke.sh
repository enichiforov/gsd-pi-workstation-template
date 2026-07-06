#!/usr/bin/env bash
set -euo pipefail

IMAGE="${IMAGE:-node:22-bookworm}"
GSD_NPM_SPEC="${GSD_NPM_SPEC:-@opengsd/gsd-pi@1.8.1}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v docker >/dev/null 2>&1; then
  echo "Missing required command: docker" >&2
  exit 1
fi

docker run --rm \
  -v "$ROOT:/src:ro" \
  "$IMAGE" \
  bash -lc '
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
export CI=1
apt-get update -qq >/dev/null
apt-get install -y -qq git python3 ca-certificates >/dev/null
npm install -g "'"$GSD_NPM_SPEC"'" >/tmp/npm-gsd.log 2>&1
mkdir -p /tmp/dummy-project
cd /tmp/dummy-project
git init -q
printf "# Dummy project\n" > README.md
cp -a /src /tmp/gsd-pi-workstation-template
cd /tmp/gsd-pi-workstation-template
./scripts/check-public-safe.py >/tmp/public-safe.log
./scripts/install.sh --project-repo /tmp/dummy-project --overwrite --skip-codex >/tmp/install.log 2>&1
./scripts/verify.sh --project-repo /tmp/dummy-project >/tmp/verify.log 2>&1
load_failures=$(grep -c "Failed to load extension" /tmp/install.log || true)
if [ "$load_failures" != "0" ]; then
  echo "FAIL extension load failures detected: $load_failures" >&2
  grep -n "Failed to load extension" /tmp/install.log >&2 || true
  exit 1
fi
printf "GSD=%s\n" "$(gsd --version)"
cat /tmp/public-safe.log
printf "load_failures=%s\n" "$load_failures"
tail -1 /tmp/verify.log
'
