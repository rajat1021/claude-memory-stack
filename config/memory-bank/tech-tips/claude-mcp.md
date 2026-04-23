# Claude Code & MCP — Tips & Gotchas

## MCP Servers
- Project-level `.mcp.json` overrides global `~/.claude/.mcp.json` for same-named servers
- codebase-memory-mcp: use `--project-dir .` for project-scoped indexing
- codebase-memory-mcp CLI: parameter is `repo_path` (not `project_dir`) — e.g., `'{"repo_path": "/path/to/project"}'`
- codebase-memory-mcp returns zero results until `index_repository` is called — auto-index on SessionStart or call manually
- memorygraph: `--profile extended` enables all 11 tools; default profile is limited
- postgres MCP: connection string goes in args, not env

## CLAUDE.md
- `@import` paths are relative to the CLAUDE.md file location
- @imports load at session start — changes require new session
- Keep CLAUDE.md under ~200 lines — beyond that, split into memory-bank files

## Hooks
- `PreCompact` hooks run before context compression — good for saving state
- **Hooks cannot invoke slash commands** — `echo "/diary"` in a hook is a no-op. Hooks must perform actions directly (write files, call APIs, etc.)
- `UserPromptSubmit` hooks receive JSON on stdin: `{"prompt": "user text"}`
- `PreToolUse` hooks can block tool execution (exit non-zero to block)
- Hooks must exit 0 to not block — always wrap in try/except with fallback exit(0)
- stdout from hooks is injected as context into the conversation

## Session Memory
- `~/.claude/projects/{encoded-path}/` stores per-project session data
- Path encoding replaces `/` with `-` — spaces in folder names cause ambiguous encodings, fragmenting memory across multiple context folders
- Auto-memory under `~/.claude/projects/` is path-dependent and fragile — always create project-level `.claude/memory-bank/` as the durable, portable store
- `cleanupPeriodDays: 99999` in settings.json to prevent session cleanup
