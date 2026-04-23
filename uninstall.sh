#!/usr/bin/env bash
# ─────────────────────────────────────────────────
# claude-memory-stack v1.0.0 | MIT License
# Author: Rajat Tanwar (@rajat1021)
# https://github.com/rajat1021/claude-memory-stack
# ─────────────────────────────────────────────────
set -euo pipefail

CLAUDE_DIR="$HOME/.claude"

# ── 1. Confirm with user ────────────────────────
echo "This will remove claude-memory-stack and restore your previous config."
echo ""
read -p "Continue? [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "Cancelled."; exit 0; }

# ── 2. Stop and remove Docker container + volume ─
echo ""
echo "Stopping Docker container..."
docker stop claude-memory-stack-db 2>/dev/null || true
docker rm claude-memory-stack-db 2>/dev/null || true

read -p "Remove database volume (ALL DATA WILL BE LOST)? [y/N] " rm_vol
if [[ "$rm_vol" =~ ^[Yy]$ ]]; then
  docker volume rm claude-memory-stack_cms_postgres_data 2>/dev/null || true
  docker volume rm docker_cms_postgres_data 2>/dev/null || true
  echo "  Volume removed."
fi

# ── 3. Restore backed-up config files ────────────
echo ""
echo "Restoring config backups..."
for file in CLAUDE.md settings.json .mcp.json; do
  backup=$(ls -t "$CLAUDE_DIR/${file}.bak."* 2>/dev/null | head -1 || true)
  if [[ -n "$backup" ]]; then
    cp "$backup" "$CLAUDE_DIR/$file"
    echo "  Restored $file from $backup"
  else
    echo "  No backup found for $file (skipped)"
  fi
done

# ── 4. Remove deployed hooks ────────────────────
echo ""
echo "Removing hooks..."
rm -f "$CLAUDE_DIR/hooks/no-leak.sh"
rm -f "$CLAUDE_DIR/hooks/auto-index.sh"

# ── 5. Remove deployed skills ───────────────────
echo "Removing skills..."
for skill in codebase-memory-exploring codebase-memory-tracing codebase-memory-quality codebase-memory-reference defuddle; do
  rm -rf "$CLAUDE_DIR/skills/$skill"
done

# ── 6. Remove deployed commands ─────────────────
echo "Removing commands..."
rm -f "$CLAUDE_DIR/commands/init-project.md"
rm -f "$CLAUDE_DIR/commands/tech-tip.md"

# ── 6b. Remove project templates ────────────────
echo "Removing project templates..."
rm -rf "$CLAUDE_DIR/templates/project"

# ── 7. Remove marker file ───────────────────────
rm -f "$CLAUDE_DIR/.claude-memory-stack"

# ── 8. Print summary ────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  claude-memory-stack removed"
echo "═══════════════════════════════════════════════════════"
echo "  Restored configs from backups (if available)"
echo "  Docker container stopped and removed"
echo "  Restart Claude Code to pick up restored config"
echo ""
