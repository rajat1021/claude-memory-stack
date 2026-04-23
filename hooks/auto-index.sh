#!/usr/bin/env bash
# ─────────────────────────────────────────────────
# claude-memory-stack v1.0.1 | MIT License
# Author: Rajat Tanwar (@rajat1021)
# https://github.com/rajat1021/claude-memory-stack
# ─────────────────────────────────────────────────
# SessionStart hook — auto-index codebase if stale or missing
#
# v1.0.1: compatible with codebase-memory-mcp 0.6.0
#   - index_status now takes {"project": "<name>"}, not repo_path
#   - MCP stores indexes at ~/.cache/codebase-memory-mcp/<name>.db (global)
#   - v0.6.0 returns status:"ready" (was "indexed")

CODEBASE_MCP="$(command -v codebase-memory-mcp || echo "$HOME/.local/bin/codebase-memory-mcp")"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-${CLAUDE_CWD:-$(pwd)}}"
PROJECT_NAME="$(echo "$PROJECT_DIR" | sed 's|^/||; s|/|-|g')"
INDEX_DB="$HOME/.cache/codebase-memory-mcp/${PROJECT_NAME}.db"
LOCK_FILE="/tmp/codebase-index-$(echo "$PROJECT_DIR" | md5 -q).lock"

# Skip if no .mcp.json with codebase-memory-mcp in this project
[ -f "$PROJECT_DIR/.mcp.json" ] || exit 0
grep -q "codebase-memory-mcp" "$PROJECT_DIR/.mcp.json" 2>/dev/null || exit 0
[ -x "$CODEBASE_MCP" ] || exit 0

# Skip if already indexing (lock file < 10 min old)
if [ -f "$LOCK_FILE" ]; then
  lock_age=$(( $(date +%s) - $(stat -f %m "$LOCK_FILE" 2>/dev/null || echo 0) ))
  [ "$lock_age" -lt 600 ] && exit 0
fi

# Check index status via project name (v0.6.0 API)
STATUS_JSON=$("$CODEBASE_MCP" cli index_status "{\"project\": \"$PROJECT_NAME\"}" 2>/dev/null)

# If status is ready/indexed AND index db is < 24h old → skip
if echo "$STATUS_JSON" | grep -qE 'status[^a-z]+(ready|indexed)'; then
  if [ -f "$INDEX_DB" ]; then
    index_age=$(( $(date +%s) - $(stat -f %m "$INDEX_DB" 2>/dev/null || echo 0) ))
    [ "$index_age" -lt 86400 ] && exit 0
  fi
fi

# Index in background
touch "$LOCK_FILE"
(
  "$CODEBASE_MCP" cli index_repository "{\"repo_path\": \"$PROJECT_DIR\"}" >/dev/null 2>&1
  rm -f "$LOCK_FILE"
) &

echo "🔍 Codebase index updating in background..."
exit 0
