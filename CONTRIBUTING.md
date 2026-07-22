# Contributing

## Scope

This repository is a public, reproducible workstation template. Changes should improve one of:

- installation safety or idempotency;
- component/profile clarity;
- exact dependency reproduction;
- verification and diagnostics;
- public-safe documentation or templates.

Do not commit auth state, credentials, private prompts, personal paths, runtime databases, session
logs, browser state, or project data.

## Development workflow

1. Start from a clean checkout.
2. Change observable behavior with a focused test.
3. Keep profile/component definitions in `manifests/components.json`.
4. Keep exact versions and Git refs synchronized across manifests and docs.
5. Run the local checks.
6. Run the Docker smoke test for installer/package changes.

```bash
python3 -m unittest discover -s tests -v
bash -n scripts/*.sh
python3 scripts/python-skills.py validate
python3 scripts/check-public-safe.py
./scripts/install.sh --profile minimal --project-repo /tmp/example --dry-run
./scripts/install.sh --profile full --project-repo /tmp/example --dry-run
```

Optional end-to-end smoke test:

```bash
./scripts/docker-smoke.sh
```

## Profile design rules

- Profiles are curated starting points; components are the stable interface.
- Keep `minimal` portable and free from provider-specific configuration.
- A requested component must fail clearly when it cannot be installed; do not hide failures behind
  unconditional success messages.
- Security dependencies must be modeled explicitly. `codex` must continue to depend on
  `codex-safety-net`.
- Any high-autonomy configuration must be applied after its guard has been installed and tested.
- Avoid adding a component until it has a distinct install/verify contract.

## Dependency updates

For each version or ref change:

- confirm the upstream release/source;
- use an exact npm/PyPI version or Git commit;
- update `components.json`, `pinned-inventory.json`, and compatibility views as applicable;
- update documentation where behavior changed;
- run the Docker smoke test;
- record compatibility limitations in the pull request.

Do not replace pins with `latest`, a branch name, or an unqualified marketplace source.

## Documentation

Write for someone arriving without workstation context. Commands must be copyable, paths must be
portable, and profile-specific examples must pass the same selection to `install.sh` and
`verify.sh`.
