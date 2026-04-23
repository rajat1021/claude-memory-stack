#!/usr/bin/env bash
# ─────────────────────────────────────────────────
# claude-memory-stack v1.0.0 | MIT License
# Author: Rajat Tanwar (@rajat1021)
# https://github.com/rajat1021/claude-memory-stack
# ─────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CMS_VERSION="1.0.1"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[cms]${NC} $1"; }
warn() { echo -e "${YELLOW}[cms]${NC} $1"; }
fail() { echo -e "${RED}[cms]${NC} $1"; exit 1; }

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  claude-memory-stack v${CMS_VERSION}"
echo "  Author: Rajat Tanwar (@rajat1021)"
echo "═══════════════════════════════════════════════════════"
echo ""

# ─────────────────────────────────────────────────
# Step 1: Check prerequisites
# ─────────────────────────────────────────────────
log "Checking prerequisites..."

command -v node >/dev/null 2>&1 || fail "node not found. Install Node.js v20+ first."
NODE_MAJOR=$(node -e 'console.log(process.versions.node.split(".")[0])')
[[ "$NODE_MAJOR" -ge 20 ]] || fail "Node.js v20+ required (found v$(node --version))"
log "  node $(node --version)"

command -v docker >/dev/null 2>&1 || fail "docker not found. Install Docker Desktop first."
docker info >/dev/null 2>&1 || fail "Docker daemon not running. Start Docker Desktop first."
log "  docker $(docker --version | awk '{print $3}' | tr -d ',')"

command -v claude >/dev/null 2>&1 || fail "claude CLI not found. Install: npm install -g @anthropic-ai/claude-code"
log "  claude CLI found"

command -v jq >/dev/null 2>&1 || fail "jq not found. Install: brew install jq"
log "  jq $(jq --version)"

# ─────────────────────────────────────────────────
# Step 2: Install MCP servers
# ─────────────────────────────────────────────────
log "Installing MCP servers..."

# codebase-memory-mcp
if command -v codebase-memory-mcp >/dev/null 2>&1; then
  log "  codebase-memory-mcp already installed"
else
  log "  Installing codebase-memory-mcp..."
  curl -fsSL https://raw.githubusercontent.com/DeusData/codebase-memory-mcp/main/install.sh | bash
fi
CMS_CODEBASE_BIN="$(command -v codebase-memory-mcp)"
log "  codebase-memory-mcp binary: $CMS_CODEBASE_BIN"

# code-review-graph
if command -v code-review-graph >/dev/null 2>&1; then
  log "  code-review-graph already installed"
else
  log "  Installing code-review-graph..."
  pip3 install code-review-graph
fi

# ruvector
if npm list -g ruvector >/dev/null 2>&1; then
  log "  ruvector already installed"
else
  log "  Installing ruvector..."
  npm install -g ruvector
fi

# ─────────────────────────────────────────────────
# Step 3: Start RuVector PostgreSQL
# ─────────────────────────────────────────────────
log "Starting RuVector PostgreSQL..."

cd "$SCRIPT_DIR/docker"

if docker ps --format '{{.Names}}' | grep -q '^claude-memory-stack-db$'; then
  log "  Container claude-memory-stack-db already running"
else
  log "  Starting container..."
  docker compose up -d
fi

log "  Waiting for database to be ready..."
RETRIES=0
MAX_RETRIES=30
until docker exec claude-memory-stack-db pg_isready -U claude -d claude_flow >/dev/null 2>&1; do
  RETRIES=$((RETRIES + 1))
  if [[ $RETRIES -ge $MAX_RETRIES ]]; then
    fail "Database not ready after 60 seconds. Check: docker logs claude-memory-stack-db"
  fi
  sleep 2
done
log "  Database ready"

# Enable pgvector + install pg driver for Ruflo CLI
log "  Enabling pgvector extension..."
docker exec claude-memory-stack-db psql -U claude -d claude_flow -c "CREATE EXTENSION IF NOT EXISTS vector;" >/dev/null
npm list -g pg >/dev/null 2>&1 || npm install -g pg >/dev/null
NODE_PATH_GLOBAL="$(npm root -g)"

cd "$SCRIPT_DIR"

# ─────────────────────────────────────────────────
# Step 4: Docker Desktop auto-start on login
# ─────────────────────────────────────────────────
log "Configuring Docker Desktop auto-start..."
osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/Docker.app", hidden:false}' 2>/dev/null \
  || warn "Set Docker Desktop to start at login manually"

# ─────────────────────────────────────────────────
# Step 5: Install Ruflo
# ─────────────────────────────────────────────────
log "Checking Ruflo..."
if command -v ruflo >/dev/null 2>&1 || npm list -g ruflo >/dev/null 2>&1; then
  log "  ruflo already installed"
else
  log "  Installing ruflo..."
  npm install -g ruflo
fi

# Initialize RuVector schema (idempotent — safe to re-run)
log "  Initializing RuVector schema..."
NODE_PATH="$NODE_PATH_GLOBAL" PGPASSWORD=claude-memory-stack ruflo ruvector init \
  --database claude_flow --user claude --host localhost --port 5433 >/dev/null 2>&1 \
  || warn "RuVector init reported issues (may already be initialized)"

# ─────────────────────────────────────────────────
# Step 6: Backup & deploy global config
# ─────────────────────────────────────────────────
log "Deploying global configuration..."

CLAUDE_DIR="$HOME/.claude"
BACKUP_TS="$(date +%s)"

mkdir -p "$CLAUDE_DIR/hooks"
mkdir -p "$CLAUDE_DIR/skills"
mkdir -p "$CLAUDE_DIR/commands"
mkdir -p "$CLAUDE_DIR/memory-bank/tech-tips"

# Backup existing files before overwriting
for f in CLAUDE.md settings.json .mcp.json; do
  if [[ -f "$CLAUDE_DIR/$f" ]]; then
    cp "$CLAUDE_DIR/$f" "$CLAUDE_DIR/${f}.bak.${BACKUP_TS}"
    log "  Backed up $f -> ${f}.bak.${BACKUP_TS}"
  fi
done

# Deploy CLAUDE.md
cp "$SCRIPT_DIR/config/global/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
log "  Deployed CLAUDE.md"

# Deploy settings.json
cp "$SCRIPT_DIR/config/global/settings.json" "$CLAUDE_DIR/settings.json"
log "  Deployed settings.json"

# Deploy .mcp.json with placeholder substitution
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
if [[ -z "$GITHUB_TOKEN" ]]; then
  warn "GITHUB_TOKEN not set in environment. GitHub MCP will not authenticate."
  warn "Set it later: export GITHUB_TOKEN=ghp_... and re-run install.sh"
fi

sed -e "s|__CMS_CODEBASE_MEMORY_BIN__|${CMS_CODEBASE_BIN}|g" \
    -e "s|__GITHUB_TOKEN__|${GITHUB_TOKEN}|g" \
    -e "s|__NODE_PATH__|${NODE_PATH_GLOBAL}|g" \
    "$SCRIPT_DIR/config/global/mcp.json" > "$CLAUDE_DIR/.mcp.json"
log "  Deployed .mcp.json"

# ─────────────────────────────────────────────────
# Step 7: Deploy hooks, skills, commands, tech-tips
# ─────────────────────────────────────────────────
log "Deploying hooks, skills, commands, tech-tips..."

# Hooks — deploy all to ~/.claude/hooks/
mkdir -p "$CLAUDE_DIR/hooks"
for hook in "$SCRIPT_DIR/hooks/"*; do
  name="$(basename "$hook")"
  # statusline.sh is special — it lives at ~/.claude/ root, not in hooks/
  [[ "$name" == "statusline.sh" ]] && continue
  cp "$hook" "$CLAUDE_DIR/hooks/$name"
  chmod +x "$CLAUDE_DIR/hooks/$name"
done

# Status line — deploys to ~/.claude/ root (referenced from settings.json)
cp "$SCRIPT_DIR/hooks/statusline.sh" "$CLAUDE_DIR/statusline.sh"
chmod +x "$CLAUDE_DIR/statusline.sh"

log "  Deployed hooks + statusline"

# Scripts — L3 ingest + memory-architecture setup
mkdir -p "$CLAUDE_DIR/scripts"
cp "$SCRIPT_DIR/scripts/"* "$CLAUDE_DIR/scripts/"
chmod +x "$CLAUDE_DIR/scripts/"*.sh 2>/dev/null || true
log "  Deployed scripts"

# L3 ingest — Python deps (sentence-transformers, psycopg2)
if command -v pip3 >/dev/null 2>&1; then
  pip3 install --quiet --user sentence-transformers psycopg2-binary 2>/dev/null \
    && log "  Installed L3 ingest Python deps (sentence-transformers, psycopg2-binary)" \
    || warn "  L3 ingest Python deps install failed — run: pip3 install --user sentence-transformers psycopg2-binary"
else
  warn "  pip3 not found — skip L3 Python deps. Install manually: pip3 install --user sentence-transformers psycopg2-binary"
fi

# Skills
for skill_dir in "$SCRIPT_DIR/skills"/*/; do
  skill_name="$(basename "$skill_dir")"
  mkdir -p "$CLAUDE_DIR/skills/$skill_name"
  cp "$skill_dir/SKILL.md" "$CLAUDE_DIR/skills/$skill_name/SKILL.md"
done
log "  Deployed skills"

# Commands
mkdir -p "$CLAUDE_DIR/commands"
cp "$SCRIPT_DIR/commands/"*.md "$CLAUDE_DIR/commands/"
log "  Deployed commands"

# Tech tips
cp "$SCRIPT_DIR/config/memory-bank/tech-tips/"*.md "$CLAUDE_DIR/memory-bank/tech-tips/"
log "  Deployed tech-tips"

# Project templates — used by /init-project to bootstrap new projects
mkdir -p "$CLAUDE_DIR/templates"
cp -R "$SCRIPT_DIR/templates/project" "$CLAUDE_DIR/templates/project"
log "  Deployed project templates"

# ─────────────────────────────────────────────────
# Step 8: Install Superpowers plugin
# ─────────────────────────────────────────────────
log "Installing Superpowers plugin..."
claude plugins install superpowers 2>/dev/null \
  || warn "Superpowers already installed or failed"

# ─────────────────────────────────────────────────
# Step 9: Write marker file
# ─────────────────────────────────────────────────
log "Writing install marker..."
cat > "$CLAUDE_DIR/.claude-memory-stack" <<MARKER
{
  "version": "${CMS_VERSION}",
  "installed_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "architecture": "3-layer-hybrid",
  "author": "Rajat Tanwar (@rajat1021)",
  "repo": "https://github.com/rajat1021/claude-memory-stack"
}
MARKER
log "  Marker written to $CLAUDE_DIR/.claude-memory-stack"

# ─────────────────────────────────────────────────
# Step 10: Run verify.sh
# ─────────────────────────────────────────────────
if [[ -f "$SCRIPT_DIR/verify.sh" ]]; then
  log "Running verification..."
  bash "$SCRIPT_DIR/verify.sh" || warn "Verification reported issues (see above)"
else
  warn "verify.sh not found — skipping verification"
fi

# ─────────────────────────────────────────────────
# Final banner
# ─────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  ✓ claude-memory-stack installed successfully"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "  Next steps:"
echo "    1. Restart Claude Code to pick up new config"
echo "    2. Run: claude /init-project <name> in any project"
echo "    3. Optional: ./migration/migrate-pgvector.sh"
echo ""
