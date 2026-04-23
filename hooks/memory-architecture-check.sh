#!/usr/bin/env bash
# SessionStart hook — verify 3-layer memory architecture is configured.
# Warns + shows fix commands if any layer is missing.

CWD="${CLAUDE_PROJECT_DIR:-${CLAUDE_CWD:-$(pwd)}}"

# Skip non-project dirs (no .git, no manifest) — don't nag in ~/Downloads etc.
is_project=0
for marker in .git package.json pyproject.toml Cargo.toml go.mod requirements.txt CLAUDE.md; do
  [ -e "$CWD/$marker" ] && { is_project=1; break; }
done
[ "$is_project" -eq 0 ] && exit 0

missing=()
fixes=()

# L1 — .claude/memory-bank/ with standard folders
L1_DIR="$CWD/.claude/memory-bank"
if [ ! -d "$L1_DIR" ]; then
  missing+=("L1 structured memory-bank")
  fixes+=("mkdir -p '$L1_DIR'/{architecture,decisions,patterns,troubleshooting}")
else
  for sub in architecture decisions patterns troubleshooting; do
    if [ ! -d "$L1_DIR/$sub" ]; then
      missing+=("L1/$sub folder")
      fixes+=("mkdir -p '$L1_DIR/$sub'")
    fi
  done
fi

# L2 — .mcp.json referencing codebase-memory-mcp
if [ ! -f "$CWD/.mcp.json" ]; then
  missing+=("L2 code graph (.mcp.json)")
  fixes+=("cp ~/.claude/templates/.mcp.json '$CWD/.mcp.json'  # or: claude mcp add --scope=project codebase-memory-mcp ~/.local/bin/codebase-memory-mcp -- --project-dir .")
elif ! grep -q "codebase-memory-mcp" "$CWD/.mcp.json" 2>/dev/null; then
  missing+=("L2 codebase-memory-mcp entry in .mcp.json")
  fixes+=("claude mcp add --scope=project codebase-memory-mcp ~/.local/bin/codebase-memory-mcp -- --project-dir .")
fi

# L3 — global; just verify DB reachable
PGVECTOR_CONTAINER="${PGVECTOR_CONTAINER:-claude-memory-stack-db}"
if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${PGVECTOR_CONTAINER}$"; then
  missing+=("L3 pgvector (${PGVECTOR_CONTAINER} not running)")
  fixes+=("docker start ${PGVECTOR_CONTAINER}  # or: cd <repo> && docker compose up -d postgres")
fi

# CLAUDE.md exists?
if [ ! -f "$CWD/CLAUDE.md" ]; then
  missing+=("CLAUDE.md (project instructions)")
  fixes+=("touch '$CWD/CLAUDE.md'  # then add memory-bank @imports")
fi

# All good — silent
[ ${#missing[@]} -eq 0 ] && exit 0

# Warn
echo ""
echo "⚠️  3-Layer Memory Architecture — incomplete in $(basename "$CWD")"
echo "────────────────────────────────────────────────────────────"
for i in "${!missing[@]}"; do
  echo "  ✗ ${missing[$i]}"
  echo "    → ${fixes[$i]}"
done
echo ""
echo "  Quick setup: run  bash ~/.claude/scripts/setup-memory-architecture.sh '$CWD'"
echo ""
exit 0
