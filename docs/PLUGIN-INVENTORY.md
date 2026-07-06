# Plugin inventory

## Pi/GSD packages

| Package | Role | Why it is included |
|---|---|---|
| `pi-subagents` | Native delegation pool | Lets one parent agent delegate scouting, implementation, review, and research lanes while keeping orchestration centralized. |
| `pi-lens` | LSP/AST/code diagnostics | Reduces blind edits with module reports, symbol reads, LSP references, AST search, and diagnostics after edits. |
| `pi-simplify` | Changed-code simplification review | Provides a quick second pass for unnecessary complexity in changed code. |
| `@plannotator/pi-extension` | Visual plan/message/diff review | Adds review surfaces for plans and diffs before execution drifts too far. |
| `@narumitw/pi-wait-what` | Pause/explain command | `/wait-what` pauses surprising behavior and asks the agent to explain before continuing. |
| `github.com/hjanuschka/pi-multi-pass` | Provider pooling/fallback | Optional provider pool/fallback configuration for Codex-first workflows. |

## Codex hook

| Package/plugin | Role |
|---|---|
| `cc-safety-net` / `safety-net@cc-marketplace` | PreToolUse guard for destructive git/filesystem commands. Blocks commands like `git reset --hard`; allows normal read/test commands. |

## Deliberately not included

- Persistent memory plugins: avoid a second memory authority until you have a memory governance plan.
- Extra subagent orchestrators: avoid conflicting ownership of delegation tools.
- Web/search/browser plugins that duplicate your existing search/browser/Context7 surfaces.
- Project-specific private retrieval extensions. Keep those in private project repos.
