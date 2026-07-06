# AGENTS.md - Project Development Workspace

## Canonical development state

For GSD-backed projects, start with:

1. `.gsd/PROJECT.md`
2. `.gsd/REQUIREMENTS.md`
3. `.gsd/DECISIONS.md`
4. project verification docs / test commands
5. this `AGENTS.md`

Use historical planning archives only as reference; do not treat stale unchecked items as current backlog without confirmation.

## Repository path naming

Prefer stable capability/domain paths. Avoid embedding lifecycle labels, milestone IDs, or temporary task titles in source paths unless the GSD engine itself requires them.

## Approval boundary

Explicit approval is required before:

- pushing to GitHub or changing remote repository state;
- deploying or restarting live services;
- sending/editing/deleting external messages;
- changing credentials, paid API behavior, or production data;
- destructive filesystem/database operations.

Read-only inspection and local reversible edits are allowed unless project rules say otherwise.

## Parallel work

The parent session owns GSD state, merge decisions, and final verification.

For broad coding/refactor/audit/planning tasks, use `pi-subagents` with independent lanes where safe. Workers must not write GSD databases directly.

## Companion Pi tools

For non-trivial code edits, `pi-lens` is mandatory before and after changes:

- `module_report` / LSP symbols before broad reads;
- `read_symbol` / `read_enclosing` for exact bodies;
- LSP references or AST search for blast-radius and structural matches;
- `lsp_diagnostics` / `lens_diagnostics` after edits.

Use Plannotator and `/wait-what` for review/pause points when work becomes ambiguous or surprising.

## Verification

Before claiming completion, run current verification evidence. Do not rely on stale summaries.

If no-match/absence is the proof, use an explicit proof helper when available rather than treating raw grep exit code 1 as a failure.

## Behavior docs

When behavior changes, update matching project docs in the same change. Keep current-state docs current; put historical details only in explicitly historical files.
