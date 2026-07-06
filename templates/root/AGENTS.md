# AGENTS.md - GSD/Pi Development Workstation

## Operating posture

- Use the lightest sufficient tool first.
- Read relevant files before editing or overwriting.
- Prefer targeted code navigation over broad file reads.
- Reproduce before fixing when possible.
- Work is not complete until relevant verification passes.
- Never print, echo, log, or restate secrets.
- Never ask the user to manually edit `.env` files; use secure secret collection when available.
- Never take outward-facing actions without explicit user confirmation: pushes, PR actions, deployments, messages, paid API changes, credential changes, or destructive data changes.

## Coding flow

For non-trivial code edits, use pi-lens before and after changes:

1. Start with `module_report` or LSP symbols before broad reads.
2. Use `read_symbol` or `read_enclosing` for exact code bodies.
3. Use LSP references or AST search for blast-radius and structural matches.
4. Make targeted edits.
5. Run `lsp_diagnostics` or `lens_diagnostics` after edits.
6. Run project verification before claiming completion.

## Parallel work

Use `pi-subagents` for independent lanes. Keep the parent session responsible for orchestration, merge decisions, and final verification.

Workers should return:

- changed files / diff summary;
- verification commands and results;
- limitations and risks;
- merge notes.

Avoid multiple writers touching the same files unless using isolated worktrees.

## Guardrails

- Use `/wait-what` when the agent does something surprising and should explain before continuing.
- Use Plannotator for plan/diff review when the task is broad or risky.
- Treat `cc-safety-net` as defense-in-depth for destructive shell commands, not as a full sandbox.

## Documentation and memory

- Put stable project rules in project `AGENTS.md`.
- Put reusable procedures in skills/runbooks.
- Put durable gotchas/conventions in memory sparingly.
- Do not store raw secrets, private data, or temporary task state in memory.
