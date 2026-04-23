#!/bin/bash
# SessionStart hook: auto-index codebase if stale or missing
# Runs codebase-memory-mcp index_repository in background if:
#   1. No index exists for this project, OR
#   2. Index is older than 24 hours

CODEBASE_MCP="${CODEBASE_MCP:-$HOME/.local/bin/codebase-memory-mcp}"
PROJECT_DIR="${CLAUDE_CWD:-$(pwd)}"
LOCK_FILE="/tmp/codebase-index-$(echo "$PROJECT_DIR" | md5 -q).lock"

# Skip if no .mcp.json with codebase-memory-mcp in this project
if [ ! -f "$PROJECT_DIR/.mcp.json" ]; then
  exit 0
fi

grep -q "codebase-memory-mcp" "$PROJECT_DIR/.mcp.json" 2>/dev/null || exit 0

# Skip if already indexing (lock file < 10 min old)
if [ -f "$LOCK_FILE" ]; then
  lock_age=$(( $(date +%s) - $(stat -f %m "$LOCK_FILE" 2>/dev/null || echo 0) ))
  if [ "$lock_age" -lt 600 ]; then
    exit 0
  fi
fi

# Check index status
STATUS=$("$CODEBASE_MCP" cli index_status "{\"repo_path\": \"$PROJECT_DIR\"}" 2>/dev/null | grep -o '"status":"[^"]*"' | head -1)

if echo "$STATUS" | grep -q "indexed"; then
  # Check if index is older than 24 hours
  INDEX_DIR="$PROJECT_DIR/.codebase-memory"
  if [ -d "$INDEX_DIR" ]; then
    index_age=$(( $(date +%s) - $(stat -f %m "$INDEX_DIR" 2>/dev/null || echo 0) ))
    if [ "$index_age" -lt 86400 ]; then
      exit 0  # Fresh enough
    fi
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
