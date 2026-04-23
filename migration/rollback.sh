#!/usr/bin/env bash
# ─────────────────────────────────────────────────
# claude-memory-stack v1.0.0 | MIT License
# Author: Rajat Tanwar (@rajat1021)
# https://github.com/rajat1021/claude-memory-stack
# ─────────────────────────────────────────────────
# Rollback: restore previous Claude Code config from backups
set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[rollback]${NC} $1"; }
warn() { echo -e "${YELLOW}[rollback]${NC} $1"; }
fail() { echo -e "${RED}[rollback]${NC} $1"; exit 1; }

CLAUDE_DIR="$HOME/.claude"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  claude-memory-stack Config Rollback"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "  This will restore your previous CLAUDE.md, settings.json,"
echo "  and .mcp.json from their most recent backups."
echo ""
echo "  NOTE: This does NOT stop Docker or remove data."
echo "  Use uninstall.sh for full removal."
echo ""

# ─────────────────────────────────────────────────
# Step 1: Confirm with user
# ─────────────────────────────────────────────────
read -p "  Continue? [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "  Cancelled."; exit 0; }
echo ""

# ─────────────────────────────────────────────────
# Step 2: Restore each config file from backup
# ─────────────────────────────────────────────────
RESTORED=0

for file in CLAUDE.md settings.json .mcp.json; do
  # Find most recent .bak file (sorted by timestamp suffix)
  backup=$(ls -t "$CLAUDE_DIR/${file}.bak."* 2>/dev/null | head -1 || true)

  if [[ -n "$backup" ]]; then
    cp "$backup" "$CLAUDE_DIR/$file"
    log "Restored $file from $(basename "$backup")"
    RESTORED=$((RESTORED + 1))
  else
    warn "No backup found for $file (skipped)"
  fi
done

# ─────────────────────────────────────────────────
# Step 3: Summary
# ─────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════"
if [[ $RESTORED -gt 0 ]]; then
  echo "  $RESTORED file(s) restored from backups"
else
  echo "  No backups found — nothing restored"
fi
echo "═══════════════════════════════════════════════════════"
echo ""
echo "  Restart Claude Code to pick up restored config."
echo "  To fully remove the stack, run: uninstall.sh"
echo ""
