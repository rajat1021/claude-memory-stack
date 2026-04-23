#!/bin/bash
# ─────────────────────────────────────────────────
# claude-memory-stack v1.0.0 | MIT License
# Author: Rajat Tanwar (@rajat1021)
# https://github.com/rajat1021/claude-memory-stack
# ─────────────────────────────────────────────────
# Status line: model | context bar | tokens | git branch | project

INPUT=$(cat)

# Extract values
MODEL=$(echo "$INPUT" | jq -r '.model.display_name // "Unknown"')
USED_PCT=$(echo "$INPUT" | jq -r '.context_window.used_percentage // 0')
INPUT_TOKENS=$(echo "$INPUT" | jq -r '.context_window.total_input_tokens // 0')
OUTPUT_TOKENS=$(echo "$INPUT" | jq -r '.context_window.total_output_tokens // 0')
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
PROJECT=$(basename "$CWD")

# Git branch (read from cwd)
GIT_BRANCH=""
if [ -d "$CWD/.git" ] || git -C "$CWD" rev-parse --git-dir >/dev/null 2>&1; then
  GIT_BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null)
fi

# Format tokens as K
format_tokens() {
  local t=$1
  if [ "$t" -ge 1000 ]; then
    echo "$((t / 1000))k"
  else
    echo "$t"
  fi
}

IN_FMT=$(format_tokens "$INPUT_TOKENS")
OUT_FMT=$(format_tokens "$OUTPUT_TOKENS")

# Progress bar (10 chars wide)
BAR_WIDTH=10
FILLED=$(echo "$USED_PCT $BAR_WIDTH" | awk '{printf "%d", ($1/100)*$2}')
EMPTY=$((BAR_WIDTH - FILLED))
BAR=""
for ((i=0; i<FILLED; i++)); do BAR+="▓"; done
for ((i=0; i<EMPTY; i++)); do BAR+="░"; done

# Build status line with pipe separator
OUTPUT="$MODEL | $BAR ${USED_PCT}% | ↑${IN_FMT} ↓${OUT_FMT}"
[ -n "$GIT_BRANCH" ] && OUTPUT="$OUTPUT | ⎇ $GIT_BRANCH"
OUTPUT="$OUTPUT | $PROJECT"
echo "$OUTPUT"
