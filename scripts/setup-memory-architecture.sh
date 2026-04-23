#!/usr/bin/env bash
# One-shot: bootstrap 3-layer memory architecture in a project.
# Usage: bash setup-memory-architecture.sh [project_dir]
set -e

PROJ="${1:-$(pwd)}"
PROJ="$(cd "$PROJ" && pwd)"  # absolutize
echo "Setting up 3-layer memory in: $PROJ"

# L1 — memory-bank folders + starter files
L1="$PROJ/.claude/memory-bank"
mkdir -p "$L1"/{architecture,decisions,patterns,troubleshooting}

[ -f "$L1/architecture/system-overview.md" ] || cat > "$L1/architecture/system-overview.md" <<EOF
# $(basename "$PROJ") — System Architecture

## Overview
## Components
| Component | Purpose | Tech |
|-----------|---------|------|

## Key Design Principles
-
EOF

[ -f "$L1/patterns/coding-standards.md" ] || cat > "$L1/patterns/coding-standards.md" <<EOF
# Coding Standards

## Language & Runtime
## Style
- Use early returns, guard clauses
- Never hardcode secrets — use environment variables
- Conventional commits (feat:, fix:, refactor:, docs:)
EOF

[ -f "$L1/troubleshooting/known-issues.md" ] || cat > "$L1/troubleshooting/known-issues.md" <<EOF
# Known Issues & Fixes

## Template
### FIXED: Issue Title
**Error:** What happened
**Cause:** Why it happened
**Fix:** What was done to fix it
EOF

echo "✅ L1 memory-bank created"

# L2 — .mcp.json
if [ ! -f "$PROJ/.mcp.json" ]; then
  cat > "$PROJ/.mcp.json" <<'EOF'
{
  "mcpServers": {
    "codebase-memory-mcp": {
      "command": "$HOME/.local/bin/codebase-memory-mcp",
      "args": ["--project-dir", "."]
    }
  }
}
EOF
  echo "✅ L2 .mcp.json created"
elif ! grep -q "codebase-memory-mcp" "$PROJ/.mcp.json"; then
  echo "⚠️  .mcp.json exists but missing codebase-memory-mcp — merge manually"
else
  echo "✅ L2 .mcp.json already configured"
fi

# CLAUDE.md skeleton
if [ ! -f "$PROJ/CLAUDE.md" ]; then
  cat > "$PROJ/CLAUDE.md" <<EOF
# $(basename "$PROJ") — Project Instructions

## Memory Bank (@imports — always loaded)
@.claude/memory-bank/architecture/system-overview.md
@.claude/memory-bank/patterns/coding-standards.md
@.claude/memory-bank/troubleshooting/known-issues.md

## What Is This Project
## Commands
## Key Rules
- Never hardcode secrets
EOF
  echo "✅ CLAUDE.md created"
fi

# L3 — check DB
PGVECTOR_CONTAINER="${PGVECTOR_CONTAINER:-claude-memory-stack-db}"
if docker ps --format '{{.Names}}' | grep -q "^${PGVECTOR_CONTAINER}$"; then
  echo "✅ L3 pgvector (${PGVECTOR_CONTAINER}) running"
else
  echo "⚠️  L3: ${PGVECTOR_CONTAINER} not running → docker start ${PGVECTOR_CONTAINER}"
fi

echo ""
echo "🎉 Memory architecture ready for $(basename "$PROJ")"
echo "   Next session open will auto-index L2 + capture L3 conversation turns."
