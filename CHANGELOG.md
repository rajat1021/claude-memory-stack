# Changelog

## [1.0.1] — 2026-04-18

### Fixed
- **L2 hooks — codebase-memory-mcp 0.6.0 compatibility**
  - `hooks/auto-index.sh` + `hooks/auto-index-incremental.sh` now pass `{"project": "<name>"}` to `index_status`/`detect_changes` (v0.6.0 dropped `repo_path` for these tools)
  - Accept both `"status":"ready"` (0.6.0) and `"status":"indexed"` (0.5.x) in freshness check
  - Check `~/.cache/codebase-memory-mcp/<project>.db` mtime for the 24h freshness gate (previously checked a non-existent `.codebase-memory/` dir, causing reindex on every session)
  - Regex tolerates both plain JSON (`"status":"ready"`) and escaped MCP wrapper output (`\"status\":\"ready\"`)

### Added
- **L3 conversation memory** — every user + assistant turn is embedded (384d all-MiniLM-L6-v2) and stored in Postgres `conversation_turns` for semantic recall across sessions:
  - `hooks/ingest-conversation.sh` wired to `UserPromptSubmit` + `Stop`
  - `scripts/ingest-conversation.py` — idempotent ingest via `transcript_uuid UNIQUE`
- **install.sh**: now deploys all 10 hooks + `scripts/` dir, installs L3 Python deps (`sentence-transformers`, `psycopg2-binary`)
- **config/global/settings.json**: full hook wiring — `PreToolUse` (no-leak), `PostToolUse` (incremental L2), `SessionStart` (memory-architecture-check + auto-index + ruflo-start), `Stop` (ruflo-end + reflect-reminder + ingest-conversation), `UserPromptSubmit` (ingest-conversation)
- **New hooks** in repo: `auto-index-incremental.sh`, `ingest-conversation.sh`, `memory-architecture-check.sh`, `reflect-reminder.sh`, `ruflo-session-start.sh`, `ruflo-session-end.sh`, `auto-index-codebase.sh`, `cbm-code-discovery-gate`
- **New scripts** in repo: `ingest-conversation.py`, `setup-memory-architecture.sh`, `obsidian-session-note.py`
- **New commands** in repo: `diary.md`, `reflect.md`, `reflect-skills.md`, `skip-reflect.md`, `view-queue.md`
- **New skills** in repo: `json-canvas`, `obsidian-bases`, `obsidian-cli`, `obsidian-markdown`, `project-memory.md`
- **docs/**: architecture reference, Windows setup guide, design spec + implementation plan

## [1.0.0] — 2026-04-12

Initial release — 3-layer memory architecture for Claude Code.
