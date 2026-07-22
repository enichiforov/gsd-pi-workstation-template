# Troubleshooting and recovery

## Start with the resolved plan

```bash
./scripts/install.sh --profile full --project-repo ~/code/app --dry-run
```

If a component is not required, exclude it rather than tolerating its failed installation. A
requested component is expected to complete successfully.

## Installer failed

The installer prints the failing command and, when managed files were replaced, the backup path:

```text
~/.local/state/gsd-pi-workstation/backups/<run-id>/
```

The directory mirrors absolute destination paths. Inspect the diff, then restore only the file you
intend to recover. Package registrations and marketplace operations are not automatically rolled
back.

The last successful selection is recorded in:

```text
~/.local/state/gsd-pi-workstation/last-install.txt
```

Use its profile/component list when reproducing a problem.

## Codex was not configured

This is fail-closed behavior. `scripts/install.sh` will not write the autonomous Codex settings
until all of these succeed:

1. the pinned `cc-safety-net` npm package installs;
2. the pinned Codex marketplace snapshot is added;
3. `safety-net@cc-marketplace` appears in `codex plugin list --json`;
4. `cc-safety-net explain "git reset --hard"` reports `Status: BLOCKED`.

Resolve the reported safety-net failure and rerun the installer. Do not manually bypass this order.

## Existing files were skipped

Different existing managed files are preserved unless `--overwrite` is supplied. Review the source
under `templates/` and your destination before rerunning:

```bash
./scripts/install.sh --profile full --project-repo ~/code/app --overwrite
```

A backup is created before replacement.

For `python-skills`, the unit of replacement is the complete skill directory. This prevents an
updated `SKILL.md` from being combined with stale references. The backup mirrors the whole
previous directory, including local extra files.

If verification reports a skill-tree mismatch, inspect it before replacing:

```bash
python3 scripts/python-skills.py validate
./scripts/install.sh \
  --profile developer \
  --include python-skills \
  --project-repo ~/code/app \
  --overwrite
./scripts/verify.sh \
  --profile developer \
  --include python-skills \
  --project-repo ~/code/app
```

## `pi` is missing

The installer first looks for `pi`, then creates an alias next to `gsd` when writable. Otherwise it
creates `~/.gsd/agent/bin/pi`. If a new shell still cannot find it, confirm that GSD is installed and
that `~/.gsd/agent/bin` is in `PATH`.

## Graphify is unavailable

Graphify requires `uv` or `pipx`. Install one of those tools and rerun, or remove the component:

```bash
./scripts/install.sh --profile full --exclude graphify --project-repo ~/code/app
./scripts/verify.sh --profile full --exclude graphify --project-repo ~/code/app
```

## Marketplace plugin failure

Marketplace sources are pinned to Git commits. A failure usually means the provider CLI changed,
the pinned snapshot is no longer compatible, or the network is unavailable. Do not replace the ref
with a moving branch as a quick fix. Validate an updated ref in `manifests/pinned-inventory.json` and
`manifests/marketplace-plugins.json`, run tests, then run the Docker smoke flow.

## GSD extension fails to load

Run:

```bash
python3 scripts/patch-gsd-exports.py --check
```

If it reports a required compatibility change, include `compatibility-patch` and reinstall. The
patch is restricted to observed compatible GSD release lines and creates adjacent `.bak` copies; it
becomes a no-op when the installed package already exposes the required exports.

## Verification fails after a selective install

`verify.sh` defaults to `full`. Pass the same selection used during installation:

```bash
./scripts/verify.sh \
  --profile developer \
  --include python-skills \
  --project-repo ~/code/app
```

## Public-safety scanner reports a finding

`scripts/check-public-safe.py` reports the rule, relative path, and line. Remove the sensitive value
from the repository; do not add a broad ignore for real source/docs. Runtime directories and
symlinks are intentionally excluded to avoid reading private machine state outside repository
content.
