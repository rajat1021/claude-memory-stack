#!/usr/bin/env bash
# ─────────────────────────────────────────────────
# claude-memory-stack v1.0.1 | MIT License
# Author: Rajat Tanwar (@rajat1021)
# https://github.com/rajat1021/claude-memory-stack
# ─────────────────────────────────────────────────
# PostToolUse hook — incremental re-index after Write/Edit/NotebookEdit
# Runs detect_changes in background, debounced (30s).
#
# v1.0.1: detect_changes takes {"project": "<name>"} in codebase-memory-mcp 0.6.0

CODEBASE_MCP="$(command -v codebase-memory-mcp || echo "$HOME/.local/bin/codebase-memory-mcp")"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-${CLAUDE_CWD:-$(pwd)}}"
PROJECT_NAME="$(echo "$PROJECT_DIR" | sed 's|^/||; s|/|-|g')"
DEBOUNCE_FILE="/tmp/codebase-incremental-$(echo "$PROJECT_DIR" | md5 -q).stamp"

# Skip if project has no .mcp.json with codebase-memory-mcp
[ -f "$PROJECT_DIR/.mcp.json" ] || exit 0
grep -q "codebase-memory-mcp" "$PROJECT_DIR/.mcp.json" 2>/dev/null || exit 0
[ -x "$CODEBASE_MCP" ] || exit 0

# Debounce: skip if ran in last 30s
if [ -f "$DEBOUNCE_FILE" ]; then
  age=$(( $(date +%s) - $(stat -f %m "$DEBOUNCE_FILE" 2>/dev/null || echo 0) ))
  [ "$age" -lt 30 ] && exit 0
fi
touch "$DEBOUNCE_FILE"

# Run detect_changes in background (v0.6.0: project-name API)
(
  "$CODEBASE_MCP" cli detect_changes "{\"project\": \"$PROJECT_NAME\"}" \
    >> ~/.claude/logs/auto-index.log 2>&1
) &

exit 0
