#!/usr/bin/env bash
# ─────────────────────────────────────────────────
# claude-memory-stack v1.0.0 | MIT License
# Author: Rajat Tanwar (@rajat1021)
# https://github.com/rajat1021/claude-memory-stack
# ─────────────────────────────────────────────────
set -uo pipefail  # NOTE: no -e, we want to continue checking even if one fails

PASS=0; FAIL=0; WARN=0
pass() { echo -e "  \033[0;32m✓\033[0m $1"; ((PASS++)); }
fail() { echo -e "  \033[0;31m✗\033[0m $1"; ((FAIL++)); }
warn() { echo -e "  \033[1;33m⚠\033[0m $1"; ((WARN++)); }

# ─────────────────────────────────────────────────
# MCP Servers
# ─────────────────────────────────────────────────
echo ""
echo "MCP Servers"
echo "───────────────────────────────────────────────"

if path=$(command -v codebase-memory-mcp 2>/dev/null); then
  pass "codebase-memory-mcp found at $path"
else
  fail "codebase-memory-mcp not found"
fi

if path=$(command -v code-review-graph 2>/dev/null); then
  pass "code-review-graph found at $path"
elif pip3 show code-review-graph &>/dev/null; then
  pass "code-review-graph installed (pip3)"
else
  fail "code-review-graph not found"
fi

if npm list -g ruvector 2>/dev/null | grep -q ruvector; then
  pass "ruvector installed globally"
else
  fail "ruvector not found in global npm"
fi

MCP_JSON="$HOME/.claude/.mcp.json"
if [ -f "$MCP_JSON" ]; then
  gh_token=$(jq -r '.mcpServers.github.env.GITHUB_PERSONAL_ACCESS_TOKEN // empty' "$MCP_JSON" 2>/dev/null)
  if [ -z "$gh_token" ]; then
    fail "GitHub PAT missing from .mcp.json"
  elif [ "$gh_token" = "__GITHUB_TOKEN__" ]; then
    warn "GitHub PAT is still placeholder (__GITHUB_TOKEN__)"
  else
    pass "GitHub PAT configured"
  fi
else
  fail "GitHub PAT — .mcp.json not found"
fi

# ─────────────────────────────────────────────────
# RuVector PostgreSQL
# ─────────────────────────────────────────────────
echo ""
echo "RuVector PostgreSQL"
echo "───────────────────────────────────────────────"

db_status=$(docker ps --filter name=claude-memory-stack-db --format '{{.Status}}' 2>/dev/null)
if [ -n "$db_status" ]; then
  pass "Container running — $db_status"
else
  fail "Container claude-memory-stack-db not running"
fi

if docker exec claude-memory-stack-db pg_isready -U claude -d claude_flow &>/dev/null; then
  pass "PostgreSQL accepting connections"
else
  fail "PostgreSQL not ready"
fi

table_count=$(docker exec claude-memory-stack-db psql -U claude -d claude_flow -tAc \
  "SELECT count(*) FROM information_schema.tables WHERE table_schema='claude_flow'" 2>/dev/null)
if [ "$table_count" = "5" ]; then
  pass "Schema has $table_count tables"
else
  fail "Expected 5 tables, found ${table_count:-0}"
fi

restart_policy=$(docker inspect claude-memory-stack-db --format '{{.HostConfig.RestartPolicy.Name}}' 2>/dev/null)
if [ "$restart_policy" = "always" ]; then
  pass "Restart policy: always"
else
  warn "Restart policy: ${restart_policy:-unknown} (expected: always)"
fi

# ─────────────────────────────────────────────────
# Hooks
# ─────────────────────────────────────────────────
echo ""
echo "Hooks"
echo "───────────────────────────────────────────────"

for hook in no-leak.sh auto-index.sh; do
  hook_path="$HOME/.claude/hooks/$hook"
  if [ -f "$hook_path" ] && [ -x "$hook_path" ]; then
    pass "$hook exists and is executable"
  elif [ -f "$hook_path" ]; then
    fail "$hook exists but is NOT executable"
  else
    fail "$hook not found"
  fi
done

# ─────────────────────────────────────────────────
# Skills
# ─────────────────────────────────────────────────
echo ""
echo "Skills"
echo "───────────────────────────────────────────────"

for skill in codebase-memory-exploring codebase-memory-tracing codebase-memory-quality codebase-memory-reference defuddle; do
  skill_path="$HOME/.claude/skills/$skill/SKILL.md"
  if [ -f "$skill_path" ]; then
    pass "skill: $skill"
  else
    fail "skill: $skill — SKILL.md not found"
  fi
done

# ─────────────────────────────────────────────────
# Config
# ─────────────────────────────────────────────────
echo ""
echo "Config"
echo "───────────────────────────────────────────────"

for cfg in CLAUDE.md settings.json .mcp.json .claude-memory-stack; do
  cfg_path="$HOME/.claude/$cfg"
  if [ -f "$cfg_path" ]; then
    pass "$cfg"
  else
    fail "$cfg not found"
  fi
done

# ─────────────────────────────────────────────────
# Commands
# ─────────────────────────────────────────────────
echo ""
echo "Commands"
echo "───────────────────────────────────────────────"

for cmd in init-project.md tech-tip.md; do
  cmd_path="$HOME/.claude/commands/$cmd"
  if [ -f "$cmd_path" ]; then
    pass "command: $cmd"
  else
    fail "command: $cmd not found"
  fi
done

# ─────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Results: $PASS passed, $FAIL failed, $WARN warnings"
echo "═══════════════════════════════════════════════════════"
echo ""

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
