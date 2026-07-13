---
name: python-environment-and-config
description: "Set up and review Python environment/config — settings injection principles, environment variables & dotenv, current-directory & path handling, imports & sys.path & project structure, import side effects, virtual environments. Use when bootstrapping a service/agent, wiring LaunchAgent/systemd/docker env, or debugging path/import/config issues."
---

# Python Environment & Config

**Source:** @advice17 — #6 (settings management), #26 (env vars & dotenv), #37 (cwd & paths), #24 (imports & project structure), #25 (import side effects), #57 (virtual environments).

## When to Use

- Bootstrapping a new service/agent (config, structure, venv)
- Reviewing how settings are loaded and injected
- Debugging "works on my machine" / wrong-path / import errors
- Setting up LaunchAgent/systemd/docker env for a Python process
- Deciding project layout and packaging

## 1. Settings principles (#6)

An app is **not** one monolith configured once — it's independent, reusable parts; some singletons, some not; some settings loaded at start, some before creating specific instances (e.g. in tests). SOLID-aligned rules:
1. Settings arrive as **external data**: env vars (and sometimes files).
2. Each module depends only on **its own** settings, unaware of others.
3. Module settings are **injected**, not read implicitly (no calling a parse function / reading a global).
4. Settings are read when the **main code starts**, not at import time.
5. A module must not know *how* settings are read, though it may offer helper(s).

**Anti-patterns:** `settings.py` of constants edited on deploy; `settings.py` of globals filled from env at import; one global settings object imported everywhere; a `load_config()` everyone calls (often `@lru_cache`d and triggered in global scope you don't control); one giant `Settings` class every class demands whole even if it uses one field. All make testing hard (settings already read by test time) or force configuring the whole app to test a part. Framework settings mechanisms belong only in framework-facing parts.

## 2. Environment variables & dotenv (#26)

Two standard config channels: **files** (good for many/nested settings, but hard to deliver in Lambda/k8s/Heroku) and **env vars** (easy to set per-process, but flat).

Env vars are set at process start by the launcher or inherited from the parent; changing them mid-run is surprising (most settings are read at start). Ways to pass them: shell `export` / inline before command; a file of `export`s applied via `source`; IDE run configs; OS-global; systemd service file (`Environment=` / `EnvironmentFile=`); `docker run --env-file` / compose.

`python-dotenv`-style libs read a config file at runtime and mutate the current process env. Risks: the app is **already running** when the file loads, so values can conflict with already-initialized objects (needs sound architecture); some implementations search parent dirs → unpredictable. Note the `.env` formats for dotenv / docker / systemd / bash are **not** interchangeable (spaces around `=`, `export`, multi-line values all differ).

## 3. Current directory & paths (#37)

- **Absolute path** (`/usr/bin/python`) — stable, unambiguous, independent of process state; long.
- **Relative path** (`.venv/bin/python`, `../file.dat`) — resolved against the **current working directory**, which is unrelated to your code's location and is set independently.
- cwd: inherited from parent (changeable at runtime); under systemd it's the service-file `WorkingDirectory` (or `/`); `pwd`/`cd` in bash; `os.getcwd()`/`os.chdir()` in Python. `open("filename")` resolves against cwd, not the script's dir — a program in `/opt/app` run from `/root` opens `/root/filename`.
- Don't `os.chdir()` unless the whole program was designed for it. For non-user data prefer: `tempfile` for temp files, `importlib.resources` for package-bundled static data, OS-standard user-data locations (`~/.config`, `%LOCALAPPDATA%`), and accept paths via `sys.argv`.

## 4. Imports & project structure (#24)

Python resolves imports by **how the code was launched**, not by the importing file's location; search order is `sys.path`, roughly:
- launch dir / cwd (see below) → `PYTHONPATH` dirs → stdlib & extension-module dirs → then the `site` module appends **site-packages** (incl. the active venv's) last.
- `python script.py` → dir of the script is first (cwd irrelevant).
- `python -m package` → cwd is first.
- tools like pytest add their own entries.

Don't hand-edit `sys.path`; if the default doesn't fit, your structure is probably wrong. Because the project dir is searched first, don't name a module like a stdlib/third-party one (it shadows). Two good layouts:
1. Runnable scripts at top level, rest packaged (predictable `sys.path`, no name clashes).
2. **(recommended)** a distributable package (`src/appname/...` + `pyproject.toml`), run via `python -m appname.cli` or `entry_points`; install editable with `pip install -e .` so imports work from any cwd — this also fixes many Alembic import problems.

## 5. Import side effects (#25)

`import x` = "find x in cache; if absent, **execute its code** and cache it; bind name." Same for `from x import y`. Code runs **once** (cached in `sys.modules`). That lets you do init-time dynamics, but **don't** write module-global code that affects anything beyond the module. Imports are meant to expose names, so nobody expects import order to matter or removing an unused import to break code — if you import a module *for its side effects*, that's a landmine; put such code in a function and call it (e.g. in `main`). PEP 8: group imports, alphabetize, drop unused.

## 6. Virtual environments (#57)

Almost always use a venv. `python -m venv .venv`; then either run by path (`.venv/bin/python`) — note `PATH` is unchanged so `subprocess` without a path still runs outside the venv — or `source .venv/bin/activate` (changes `PATH`, sets `VIRTUAL_ENV`; `deactivate` to exit). Common mistakes:
- Not using venvs (breaks when two projects need different versions of a lib).
- Moving/copying a venv elsewhere or into VCS — it breaks; commit the **dependency list** and recreate. (Exception: copying between identical OS images, e.g. container builds.)
- Installing `pip` outside the venv; assuming the IDE knows where the venv is; putting project files *inside* the venv (keep the venv inside the project dir instead).

## Anti-Patterns

- Global settings object / `load_config()` called everywhere / `@lru_cache`d config read in global scope.
- Reading settings at import time; a module knowing *how* config is loaded.
- Relying on cwd for code-relative resources (use `importlib.resources`).
- `os.chdir()` in a program not designed for it.
- Shadowing stdlib module names; hand-editing `sys.path`.
- `import module` purely for side effects.
- Committing a venv; moving a venv; no venv at all.
- Plaintext secrets in `.env`/config committed to the repo.

## References
- Posts #6, #26, #37, #24, #25, #57
- [12factor](https://12factor.net/), [venv](https://docs.python.org/3/library/venv.html), [Python import system](https://docs.python.org/3/reference/import.html), [packaging](https://packaging.python.org/en/latest/)

## Pair With
- `python-architecture-patterns` — DI for settings, integration layer
- `python-code-quality-fundamentals` — why globals are bad
