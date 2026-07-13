# graphify — knowledge-graph tool

[graphify](https://github.com/Graphify-Labs/graphify) turns any folder of files —
code, docs, papers, images, video — into a navigable knowledge graph with
community detection and an honest audit trail (every edge tagged `EXTRACTED`,
`INFERRED`, or `AMBIGUOUS`). It complements the LSP/AST tools in this template:
`pi-lens` answers precise structural questions ("who calls this symbol"), while
graphify answers cross-cutting ones ("what concepts connect these two
subsystems") and produces a graph that survives across sessions.

## Why it is in this template

- **New-codebase onboarding.** Build a map of an unfamiliar repo before touching
  it, then query the graph instead of re-reading files each session.
- **Cross-document insight.** Community detection surfaces connections between
  concepts in different files you would not think to ask about directly.
- **Persistent, auditable context.** Relationships live in
  `graphify-out/graph.json` and each edge records how it was derived.

It is a **knowledge-graph / understanding** tool, not a code-writing plugin, so it
sits in its own category alongside the coding-workflow marketplace plugins.

## How it is installed

`scripts/install.sh` reference-installs graphify — no third-party code is
vendored into this repo:

1. Installs the CLI from the public PyPI package `graphifyy` (double-y; the
   command is still `graphify`) via `uv tool install graphifyy`, falling back to
   `pipx install graphifyy`.
2. Runs `graphify install --platform <p>` for `claude`, `codex`, and `pi` so the
   `/graphify` skill is registered for each assistant this workstation targets
   (`codex` is skipped when `--skip-codex` is passed).

Skip the whole step with `--skip-graphify`. If neither `uv` nor `pipx` is on the
machine, the installer warns and continues — install `uv`
(<https://astral.sh/uv>) and rerun, or install the CLI manually:

```bash
uv tool install graphifyy    # or: pipx install graphifyy
graphify install             # registers the /graphify skill
```

`scripts/verify.sh` treats graphify as optional: it prints `OK` when the CLI and
Claude skill are present and `WARN` (never `FAIL`) when they are absent.

## Using it

In a fresh assistant session:

```text
/graphify                                    # graph the current directory
/graphify <path>                             # graph a specific path
/graphify https://github.com/<owner>/<repo>  # clone a repo, then graph it
/graphify query "<question>"                 # traverse the graph to answer
/graphify path "ModuleA" "ModuleB"           # shortest path between two concepts
/graphify explain "<node>"                   # plain-language node explanation
/graphify <path> --update                    # re-extract only changed files
```

Outputs land in `graphify-out/`: `graph.html` (interactive), `graph.json` (raw
graph / GraphRAG-ready), and `GRAPH_REPORT.md` (god nodes, surprising
connections, suggested questions).

Requirements: Python 3.10+ and `uv` (recommended) or `pipx`. For richer, cheaper
semantic extraction, set `MOONSHOT_API_KEY` and
`uv tool install 'graphifyy[kimi]'`.
