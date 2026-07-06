# Recommended development flow

This template is optimized for agentic coding sessions that should stay observable, reviewable, and easy to resume.

## Source-of-truth order

For a GSD project, start with:

1. `.gsd/PROJECT.md`
2. `.gsd/REQUIREMENTS.md`
3. `.gsd/DECISIONS.md`
4. project `AGENTS.md`
5. project verification docs / test commands

Avoid putting large project facts directly into always-on prompts. Use docs, memory, code retrieval, and skills for the right kind of context.

## Coding flow

For non-trivial code edits:

1. Use `module_report` or LSP symbols before broad reads.
2. Use `read_symbol` / `read_enclosing` for exact code bodies.
3. Use LSP references or AST search for blast-radius and structural matches.
4. Make targeted edits.
5. Run `lsp_diagnostics` or `lens_diagnostics` after edits.
6. Run project verification before claiming completion.

## Parallel work

- Use `pi-subagents` when lanes are independent.
- Keep one parent session responsible for merge decisions and final verification.
- Workers should return diffs, verification commands, limitations, risks, and merge notes.
- Avoid multiple writers editing the same files at once unless isolated in worktrees.

## Guardrails

- `cc-safety-net` blocks many destructive local shell commands before execution.
- `/wait-what` pauses surprising agent behavior for explanation.
- Plannotator provides visual plan/review surfaces.
- Approval boundaries still apply for pushes, deployments, external services, secrets, paid API behavior, and destructive data changes.

## Memory guidance

Use durable memory sparingly:

- Good: stable gotchas, project conventions, architecture decisions, environment facts.
- Bad: raw code facts that retrieval tools can find, temporary task state, credentials, private documents.

Keep procedural knowledge in skills/runbooks rather than bloating always-on instructions.
