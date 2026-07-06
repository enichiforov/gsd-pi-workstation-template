# Security notes

This template helps set up a powerful coding-agent workstation. Powerful local agents need hard boundaries.

## Do not commit

Never commit:

- API keys, GitHub tokens, provider auth, 1Password output, SSH keys.
- `.env` files, except sanitized `.env.example` templates.
- `.codex/auth.json`, browser state, cookies, session files.
- `.gsd/gsd.db`, WAL files, runtime state, logs, caches.
- Private documents, personal knowledge bases, or production data.

## What safety-net does

`cc-safety-net` is a pre-tool guard for shell commands. It catches many destructive git/filesystem operations before execution, including wrapped forms such as shell one-liners.

Examples:

- `git reset --hard` => blocked
- `rm -rf /` => blocked
- `rg pi-lens AGENTS.md` => allowed

## What safety-net does not do

It is not:

- an OS sandbox;
- a network firewall;
- a secret scanner;
- a replacement for review and approval boundaries;
- a guarantee that every dangerous command is impossible.

Use it as defense-in-depth, not as permission to skip judgment.

## Public fork hygiene

Before making a fork public:

1. Search for tokens and private keys.
2. Search for private project names, personal paths, and operational details.
3. Check git history, not just the latest tree.
4. Prefer a new sanitized public repo over making a private repo public if earlier commits contained private material.
