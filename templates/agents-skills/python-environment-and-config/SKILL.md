---
name: python-environment-and-config
description: "Configure and debug Python environments and process boundaries: settings composition, environment variables and secret injection, pyproject/dependency locking, package/import layout, import side effects, cwd/path/resource handling, virtual environments, argv/PATH/env/stdin/stdout/stderr, and safe cross-platform subprocess launch. Use for bootstrapping services or fixing config/import/path/venv/child-process failures."
---

# Python Environment and Configuration

Make startup, configuration, imports, paths, and process launch deterministic across shells, IDEs,
services, containers, tests, and operating systems.

## Workflow

1. **Identify the process launcher and environment.** Record executable, argv, cwd, PATH, env,
   user, platform, virtual environment, and configuration sources.
2. **Compose settings once at startup.** Validate required configuration at the application
   boundary and inject narrow immutable settings into consumers.
3. **Separate config from secrets.** Keep credentials in environment/secret providers; never in
   source, logs, committed dotenv files, or import-time globals.
4. **Use an installable package layout.** Prefer `src/` when appropriate, explicit package APIs,
   and no `sys.path` mutation. Keep the root package side-effect-free.
5. **Resolve paths by owner.** Accept user/external paths explicitly; use `pathlib` and
   `importlib.resources` for package data; do not rely on ambient cwd.
6. **Keep environments reproducible.** Declare and lock dependencies with the repository's chosen
   tool; recreate virtual environments instead of copying or committing them.
7. **Launch child processes explicitly.** Prefer argv lists, explicit cwd/env, bounded timeout,
   and an output sink with a deliberate memory/disk limit. Use `check=True` where nonzero exit is
   failure and a shell only when shell language is intentionally required.
8. **Reproduce outside the IDE.** Run the exact executable/module from the intended launcher and
   compare effective configuration without printing secret values.

## Core rules

- Fail required configuration once at settings construction; do not add downstream `None`
  fallbacks.
- Avoid one mutable global Settings object imported everywhere. Inject the smallest slice each
  component needs.
- Treat dotenv as a local loading convenience, not a deployment or secret-management architecture.
- Keep import execution free of network calls, migrations, process starts, registration side
  effects, and environment-dependent mutation.
- Use `python -m package.module` or installed entry points rather than assumptions about script
  directory and cwd.
- Do not move/copy a venv or commit it. Lock inputs and recreate it.
- Pass untrusted child-process values as argv elements. Do not interpolate them into shell source.
- Remember that venv activation changes PATH for the shell; invoking `.venv/bin/python` directly
  does not rewrite PATH for its child processes.

## Load references selectively

- For settings, env, secrets, imports, resources, dependencies, and venvs, read
  [configuration-and-packaging.md](references/configuration-and-packaging.md).
- For argv, PATH, cwd/env, streams, shell behavior, and subprocess, read
  [process-execution.md](references/process-execution.md).
- For provenance and qualified claims, read
  [advice17-source-map.md](references/advice17-source-map.md).

## Output contract

Return:

1. launcher/executable/environment facts;
2. configuration source and validation owner;
3. import/package/path diagnosis;
4. process-launch contract when relevant;
5. smallest deterministic fix;
6. a reproduction command with secrets redacted.
