# claude-memory-stack Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a portable GitHub repo that deploys a 3-layer memory architecture for Claude Code on any Mac/Linux machine with one command, reducing token consumption by ~81%.

**Architecture:** Repo contains config files, hooks, skills, Docker setup (RuVector PostgreSQL), install/uninstall/verify scripts, and migration tools. install.sh backs up existing config, deploys everything, and runs verification. PostgreSQL auto-starts on laptop boot via Docker restart policy.

**Tech Stack:** Bash (scripts), Docker (RuVector PostgreSQL), Python (code-review-graph), Go (codebase-memory-mcp), Node.js (Ruflo, GitHub MCP), Markdown (configs, skills)

---

## File Map

```
~/Documents/claude-memory-stack/        # NEW repo root
├── install.sh                          # CREATE — main entry point
├── uninstall.sh                        # CREATE — clean removal
├── verify.sh                           # CREATE — health check
├── LICENSE                             # CREATE — MIT
├── README.md                           # CREATE — full docs
├── .gitignore                          # CREATE
│
├── config/
│   ├── global/
│   │   ├── CLAUDE.md                   # CREATE — global prefs + memory protocol
│   │   ├── settings.json               # CREATE — hooks, permissions
│   │   └── mcp.json                    # CREATE — GitHub MCP (template)
│   ├── project-template/
│   │   ├── CLAUDE.md                   # CREATE — template project config
│   │   ├── mcp.json                    # CREATE — 3 MCP servers
│   │   └── memory-bank/
│   │       ├── architecture.md         # CREATE
│   │       ├── decisions.md            # CREATE
│   │       ├── patterns.md             # CREATE
│   │       └── troubleshooting.md      # CREATE
│   └── memory-bank/
│       └── tech-tips/                  # COPY from existing ~/.claude/memory-bank/tech-tips/
│
├── hooks/
│   ├── no-leak.sh                      # COPY+MODIFY from existing ~/.claude/no-leak.sh
│   └── auto-index.sh                   # COPY+MODIFY from existing ~/.claude/hooks/auto-index-codebase.sh
│
├── skills/                             # COPY from existing ~/.claude/skills/
│   ├── codebase-memory-exploring/SKILL.md
│   ├── codebase-memory-tracing/SKILL.md
│   ├── codebase-memory-quality/SKILL.md
│   ├── codebase-memory-reference/SKILL.md
│   └── defuddle/SKILL.md
│
├── docker/
│   ├── docker-compose.yml              # CREATE — RuVector PostgreSQL + auto-restart
│   └── init-db.sql                     # CREATE — full schema from spec
│
├── migration/
│   ├── migrate-pgvector.sh             # CREATE — export pgvector → import RuVector
│   ├── migrate-memorygraph.sh          # CREATE — export memorygraph → RuVector
│   └── rollback.sh                     # CREATE — restore backups
│
├── commands/
│   ├── init-project.md                 # CREATE — /init-project slash command
│   └── tech-tip.md                     # CREATE — /tech-tip slash command
│
└── docs/
    └── architecture.md                 # CREATE — deep dive
```

---

### Task 1: Create Repo & Scaffold

**Files:**
- Create: `~/Documents/claude-memory-stack/` (entire directory tree)
- Create: `.gitignore`
- Create: `LICENSE`

- [ ] **Step 1: Create GitHub repo**

```bash
cd ~/Documents
mkdir claude-memory-stack && cd claude-memory-stack
git init
```

- [ ] **Step 2: Create .gitignore**

```
.DS_Store
*.bak
.env
*.key
*.pem
credentials.json
node_modules/
__pycache__/
```

- [ ] **Step 3: Create MIT LICENSE**

Standard MIT license with `Copyright (c) 2026 Rajat Tanwar`.

- [ ] **Step 4: Create directory structure**

```bash
mkdir -p config/global config/project-template/memory-bank config/memory-bank/tech-tips
mkdir -p hooks skills docker migration commands docs
```

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: scaffold repo structure"
```

---

### Task 2: Docker — RuVector PostgreSQL with Auto-Start

**Files:**
- Create: `docker/docker-compose.yml`
- Create: `docker/init-db.sql`

- [ ] **Step 1: Create docker-compose.yml**

```yaml
# ─────────────────────────────────────────────────
# claude-memory-stack v1.0.0 | MIT License
# Author: Rajat Tanwar (@rajat1021)
# https://github.com/rajat1021/claude-memory-stack
# ─────────────────────────────────────────────────
#
# RuVector PostgreSQL — L3 Knowledge + Learning DB
# Auto-starts on laptop boot via restart: always

services:
  ruvector-postgres:
    image: ruvnet/ruvector-postgres:latest
    container_name: claude-memory-stack-db
    restart: always    # ← auto-start on boot when Docker Desktop starts
    environment:
      POSTGRES_USER: claude
      POSTGRES_PASSWORD: ${CMS_DB_PASSWORD:-claude-memory-stack}
      POSTGRES_DB: claude_flow
    ports:
      - "5433:5432"    # 5433 to avoid conflict with existing postgres on 5432
    volumes:
      - cms_postgres_data:/var/lib/postgresql/data
      - ./init-db.sql:/docker-entrypoint-initdb.d/01-init.sql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U claude -d claude_flow"]
      interval: 5s
      timeout: 5s
      retries: 10
    command: >
      postgres
      -c work_mem=256MB
      -c maintenance_work_mem=512MB
      -c shared_buffers=256MB

volumes:
  cms_postgres_data:
```

Key decisions:
- `restart: always` — container starts when Docker Desktop starts (which should be set to open at login)
- Port `5433` to avoid conflict with any existing Postgres on `5432`
- Password from env var `$CMS_DB_PASSWORD` with fallback default
- Named volume `cms_postgres_data` for persistence

- [ ] **Step 2: Create init-db.sql**

Full schema from design spec Section 4.5. Include:
- `CREATE EXTENSION IF NOT EXISTS ruvector VERSION '0.1.0';`
- `CREATE EXTENSION IF NOT EXISTS pgcrypto;`
- `CREATE SCHEMA IF NOT EXISTS claude_flow;`
- All 5 tables: insights, note_chunks, observations, patterns, agents
- All HNSW indexes
- All btree indexes (type, date, importance, category, etc.)
- Author header comment

- [ ] **Step 3: Ensure Docker Desktop starts on login**

```bash
osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/Docker.app", hidden:false}' 2>/dev/null || echo "Set Docker Desktop to start at login manually in Docker Desktop → Settings → General → Start Docker Desktop when you sign in"
```

- [ ] **Step 4: Test docker compose**

```bash
cd ~/Documents/claude-memory-stack/docker
docker compose up -d
# Wait for healthy
sleep 10
docker exec claude-memory-stack-db psql -U claude -d claude_flow -c "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'claude_flow';"
```

Expected: 5 tables created.

- [ ] **Step 5: Test auto-restart**

```bash
docker restart claude-memory-stack-db
sleep 5
docker exec claude-memory-stack-db pg_isready -U claude -d claude_flow
```

Expected: `accepting connections`

- [ ] **Step 6: Commit**

```bash
git add docker/
git commit -m "feat: add RuVector PostgreSQL with auto-restart on boot"
```

---

### Task 3: Global Config Files

**Files:**
- Create: `config/global/CLAUDE.md`
- Create: `config/global/settings.json`
- Create: `config/global/mcp.json`

- [ ] **Step 1: Create global CLAUDE.md**

Trimmed version (~55 lines instead of 95). Contains:
- Coding style (early returns, conventional commits, python3, no secrets)
- Communication style (short, tabular, verify before presenting, don't change code until root cause confirmed)
- Projects list
- Code Graph usage instructions (prefer over Grep)
- Memory Retrieval Protocol (L1 check first → L2 auto for code → L3 ask user first)
- NO mandatory 3-layer protocol
- NO `using-superpowers` reference
- @import references to memory-bank/tech-tips/

- [ ] **Step 2: Create settings.json**

```json
{
  "_meta": {
    "stack": "claude-memory-stack",
    "version": "1.0.0",
    "author": "Rajat Tanwar"
  },
  "cleanupPeriodDays": 99999,
  "permissions": {
    "allow": [
      "Bash(venv/bin/python:*)"
    ]
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Read|Edit|Write|Bash|Glob",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/no-leak.sh"
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/auto-index.sh"
          }
        ]
      }
    ]
  },
  "enabledPlugins": {
    "superpowers@claude-plugins-official": true
  },
  "voiceEnabled": true
}
```

Removed:
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` env (Ruflo replaces)
- UserPromptSubmit hook (capture_learning — Ruflo replaces)
- PostToolUse hook (post_commit_reminder — Ruflo replaces)
- PreCompact hooks (check_learnings + diary — Ruflo replaces)
- `skipDangerousModePermissionPrompt` (security conscious)
- statusLine (optional, user can re-add)

- [ ] **Step 3: Create mcp.json (global)**

```json
{
  "_meta": {
    "stack": "claude-memory-stack",
    "version": "1.0.0",
    "author": "Rajat Tanwar"
  },
  "mcpServers": {
    "codebase-memory-mcp": {
      "command": "__CMS_CODEBASE_MEMORY_BIN__"
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@anthropic-ai/github-mcp-server"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "__GITHUB_TOKEN__"
      }
    }
  }
}
```

Placeholders `__CMS_CODEBASE_MEMORY_BIN__` and `__GITHUB_TOKEN__` replaced by install.sh at deploy time.

- [ ] **Step 4: Commit**

```bash
git add config/global/
git commit -m "feat: add global config (CLAUDE.md, settings.json, mcp.json)"
```

---

### Task 4: Project Template

**Files:**
- Create: `config/project-template/CLAUDE.md`
- Create: `config/project-template/mcp.json`
- Create: `config/project-template/memory-bank/architecture.md`
- Create: `config/project-template/memory-bank/decisions.md`
- Create: `config/project-template/memory-bank/patterns.md`
- Create: `config/project-template/memory-bank/troubleshooting.md`

- [ ] **Step 1: Create project template CLAUDE.md**

```markdown
<!-- claude-memory-stack v1.0.0 | Rajat Tanwar (@rajat1021) -->
# Project: __PROJECT_NAME__

## Overview
<!-- Describe what this project does -->

## Tech Stack
<!-- List technologies used -->

## Key Conventions
<!-- Project-specific coding conventions -->

## Memory Bank
@.claude/memory-bank/architecture.md
@.claude/memory-bank/decisions.md
@.claude/memory-bank/patterns.md
@.claude/memory-bank/troubleshooting.md
```

- [ ] **Step 2: Create project template mcp.json**

```json
{
  "_meta": {"stack": "claude-memory-stack", "version": "1.0.0"},
  "mcpServers": {
    "codebase-memory-mcp": {
      "command": "__CMS_CODEBASE_MEMORY_BIN__",
      "args": ["--project-dir", "."]
    },
    "code-review-graph": {
      "command": "code-review-graph",
      "args": ["mcp"]
    },
    "ruvector-mcp": {
      "command": "npx",
      "args": ["ruvector", "mcp-server"],
      "env": {
        "PGHOST": "localhost",
        "PGPORT": "5433",
        "PGDATABASE": "claude_flow",
        "PGUSER": "claude",
        "PGPASSWORD": "__CMS_DB_PASSWORD__"
      }
    }
  }
}
```

- [ ] **Step 3: Create memory-bank template files**

Each file gets a header and empty sections:
- `architecture.md` — System overview, components, data flow
- `decisions.md` — ADR log
- `patterns.md` — Recurring patterns and solutions
- `troubleshooting.md` — Known issues and fixes

- [ ] **Step 4: Commit**

```bash
git add config/project-template/
git commit -m "feat: add project template with memory-bank scaffold"
```

---

### Task 5: Copy Existing Tech Tips & Skills

**Files:**
- Copy: `~/.claude/memory-bank/tech-tips/*.md` → `config/memory-bank/tech-tips/`
- Copy: `~/.claude/skills/codebase-memory-*` → `skills/`
- Copy: `~/.claude/skills/defuddle/` → `skills/defuddle/`

- [ ] **Step 1: Copy tech tips**

```bash
cp ~/.claude/memory-bank/tech-tips/*.md ~/Documents/claude-memory-stack/config/memory-bank/tech-tips/
```

- [ ] **Step 2: Copy skills (add author headers)**

```bash
for skill in codebase-memory-exploring codebase-memory-tracing codebase-memory-quality codebase-memory-reference; do
  mkdir -p ~/Documents/claude-memory-stack/skills/$skill
  cp ~/.claude/skills/$skill/SKILL.md ~/Documents/claude-memory-stack/skills/$skill/SKILL.md
done
mkdir -p ~/Documents/claude-memory-stack/skills/defuddle
cp ~/.claude/skills/defuddle/SKILL.md ~/Documents/claude-memory-stack/skills/defuddle/SKILL.md
```

Then prepend author header to each SKILL.md.

- [ ] **Step 3: Commit**

```bash
git add config/memory-bank/ skills/
git commit -m "feat: add tech tips and custom skills"
```

---

### Task 6: Hooks

**Files:**
- Create: `hooks/no-leak.sh` (copy + add author header from existing)
- Create: `hooks/auto-index.sh` (copy + add author header from existing)

- [ ] **Step 1: Copy no-leak.sh with author header**

Copy from `~/.claude/no-leak.sh`, prepend:
```bash
#!/usr/bin/env bash
# ─────────────────────────────────────────────────
# claude-memory-stack v1.0.0 | MIT License
# Author: Rajat Tanwar (@rajat1021)
# https://github.com/rajat1021/claude-memory-stack
# ─────────────────────────────────────────────────
```

- [ ] **Step 2: Copy auto-index.sh with author header**

Copy from `~/.claude/hooks/auto-index-codebase.sh`, prepend author header.

- [ ] **Step 3: Make executable and commit**

```bash
chmod +x hooks/*.sh
git add hooks/
git commit -m "feat: add no-leak and auto-index hooks"
```

---

### Task 7: Slash Commands

**Files:**
- Create: `commands/init-project.md`
- Create: `commands/tech-tip.md`

- [ ] **Step 1: Create init-project.md**

Slash command that:
1. Takes project name as argument
2. Creates `.mcp.json` from project template (replaces placeholders)
3. Creates `CLAUDE.md` from template (replaces `__PROJECT_NAME__`)
4. Creates `.claude/memory-bank/` with 4 template files
5. Runs `code-review-graph build` and `codebase-memory-mcp cli index_repository`

- [ ] **Step 2: Create tech-tip.md**

Slash command that:
1. Takes technology name and tip as arguments
2. Appends to `~/.claude/memory-bank/tech-tips/{technology}.md`
3. Creates the file if it doesn't exist
4. Also stores as a pattern in RuVector via ruvector MCP

- [ ] **Step 3: Commit**

```bash
git add commands/
git commit -m "feat: add /init-project and /tech-tip commands"
```

---

### Task 8: install.sh

**Files:**
- Create: `install.sh`

This is the main entry point. It must be idempotent (safe to run multiple times).

- [ ] **Step 1: Write install.sh**

Script flow:
```bash
#!/usr/bin/env bash
# ─────────────────────────────────────────────────
# claude-memory-stack v1.0.0 | MIT License
# Author: Rajat Tanwar (@rajat1021)
# https://github.com/rajat1021/claude-memory-stack
# ─────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CMS_VERSION="1.0.0"

# Colors
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'; BOLD='\033[1m'

log()  { echo -e "${GREEN}[cms]${NC} $1"; }
warn() { echo -e "${YELLOW}[cms]${NC} $1"; }
fail() { echo -e "${RED}[cms]${NC} $1"; exit 1; }

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  claude-memory-stack v${CMS_VERSION}"
echo "  Author: Rajat Tanwar (@rajat1021)"
echo "═══════════════════════════════════════════════════════"
echo ""

# ── Step 1: Prerequisites ──
log "Checking prerequisites..."
command -v node >/dev/null   || fail "Node.js not found. Install from https://nodejs.org"
command -v docker >/dev/null || fail "Docker not found. Install Docker Desktop."
command -v claude >/dev/null || fail "Claude Code not found. Install: npm install -g @anthropic-ai/claude-code"
command -v jq >/dev/null     || fail "jq not found. Install: brew install jq"
docker info >/dev/null 2>&1  || fail "Docker not running. Start Docker Desktop."

NODE_VER=$(node -v | sed 's/v//' | cut -d. -f1)
[ "$NODE_VER" -ge 20 ] || fail "Node.js 20+ required (found v$NODE_VER)"
log "  ✓ Node.js $(node -v), Docker, Claude Code, jq"

# ── Step 2: Install MCP servers ──
log "Installing MCP servers..."

# codebase-memory-mcp
if ! command -v codebase-memory-mcp >/dev/null 2>&1; then
  log "  Installing codebase-memory-mcp..."
  curl -fsSL https://raw.githubusercontent.com/DeusData/codebase-memory-mcp/main/install.sh | bash
fi
CMS_CODEBASE_BIN=$(which codebase-memory-mcp)
log "  ✓ codebase-memory-mcp: $CMS_CODEBASE_BIN"

# code-review-graph
if ! command -v code-review-graph >/dev/null 2>&1; then
  log "  Installing code-review-graph..."
  pip3 install code-review-graph
fi
log "  ✓ code-review-graph: $(which code-review-graph)"

# ruvector
if ! npx ruvector --version >/dev/null 2>&1; then
  log "  Installing ruvector..."
  npm install -g ruvector
fi
log "  ✓ ruvector"

# ── Step 3: Start RuVector PostgreSQL ──
log "Starting RuVector PostgreSQL..."
cd "$SCRIPT_DIR/docker"

if docker ps --format '{{.Names}}' | grep -q claude-memory-stack-db; then
  log "  Container already running"
else
  docker compose up -d
  log "  Waiting for health check..."
  for i in $(seq 1 30); do
    if docker exec claude-memory-stack-db pg_isready -U claude -d claude_flow >/dev/null 2>&1; then
      break
    fi
    sleep 2
  done
  docker exec claude-memory-stack-db pg_isready -U claude -d claude_flow >/dev/null 2>&1 \
    || fail "RuVector PostgreSQL failed to start"
fi
log "  ✓ RuVector PostgreSQL on port 5433"

# ── Step 4: Docker Desktop auto-start ──
log "Ensuring Docker Desktop starts on login..."
osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/Docker.app", hidden:false}' 2>/dev/null \
  || warn "  Could not set auto-start. Enable manually: Docker Desktop → Settings → General → Start on login"

# ── Step 5: Install Ruflo ──
log "Installing Ruflo (orchestration)..."
if ! command -v ruflo >/dev/null 2>&1 && ! npx ruflo --version >/dev/null 2>&1; then
  npm install -g ruflo
fi
log "  ✓ Ruflo installed"

# ── Step 6: Backup & Deploy Global Config ──
log "Deploying global config..."
cd "$SCRIPT_DIR"

CLAUDE_DIR="$HOME/.claude"
mkdir -p "$CLAUDE_DIR/hooks" "$CLAUDE_DIR/skills" "$CLAUDE_DIR/commands" "$CLAUDE_DIR/memory-bank/tech-tips"

# Backup existing
for f in CLAUDE.md settings.json .mcp.json; do
  [ -f "$CLAUDE_DIR/$f" ] && cp "$CLAUDE_DIR/$f" "$CLAUDE_DIR/$f.bak.$(date +%s)" && log "  Backed up $f"
done

# Deploy CLAUDE.md
cp config/global/CLAUDE.md "$CLAUDE_DIR/CLAUDE.md"

# Deploy settings.json
cp config/global/settings.json "$CLAUDE_DIR/settings.json"

# Deploy .mcp.json (replace placeholders)
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
if [ -z "$GITHUB_TOKEN" ]; then
  warn "  \$GITHUB_TOKEN not set. GitHub MCP will not work."
  warn "  Set it: export GITHUB_TOKEN='your_token' in ~/.zshenv"
fi
sed -e "s|__CMS_CODEBASE_MEMORY_BIN__|$CMS_CODEBASE_BIN|g" \
    -e "s|__GITHUB_TOKEN__|$GITHUB_TOKEN|g" \
    config/global/mcp.json > "$CLAUDE_DIR/.mcp.json"

log "  ✓ CLAUDE.md, settings.json, .mcp.json deployed"

# ── Step 7: Deploy hooks, skills, commands ──
log "Deploying hooks, skills, commands..."
cp hooks/*.sh "$CLAUDE_DIR/hooks/"
chmod +x "$CLAUDE_DIR/hooks/"*.sh

for skill_dir in skills/*/; do
  skill_name=$(basename "$skill_dir")
  mkdir -p "$CLAUDE_DIR/skills/$skill_name"
  cp "$skill_dir"* "$CLAUDE_DIR/skills/$skill_name/" 2>/dev/null || true
done

cp commands/*.md "$CLAUDE_DIR/commands/" 2>/dev/null || true
cp -r config/memory-bank/tech-tips/*.md "$CLAUDE_DIR/memory-bank/tech-tips/" 2>/dev/null || true

log "  ✓ Hooks, skills, commands, tech-tips deployed"

# ── Step 8: Install Superpowers plugin ──
log "Installing Superpowers plugin..."
claude plugins install superpowers 2>/dev/null || warn "  Superpowers already installed or install failed"
log "  ✓ Superpowers plugin"

# ── Step 9: Write marker file ──
cat > "$CLAUDE_DIR/.claude-memory-stack" <<MARKER
{
  "version": "$CMS_VERSION",
  "installed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "architecture": "3-layer-hybrid",
  "author": "Rajat Tanwar (@rajat1021)",
  "repo": "https://github.com/rajat1021/claude-memory-stack",
  "components": {
    "l1": "structured-files",
    "l2": "code-review-graph + codebase-memory-mcp",
    "l3": "ruvector-postgresql",
    "orchestration": "ruflo",
    "discipline": "superpowers-8"
  }
}
MARKER
log "  ✓ Marker file written"

# ── Step 10: Verify ──
log "Running verification..."
cd "$SCRIPT_DIR"
bash verify.sh

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
```

- [ ] **Step 2: Make executable**

```bash
chmod +x install.sh
```

- [ ] **Step 3: Commit**

```bash
git add install.sh
git commit -m "feat: add install.sh — one-command deployment"
```

---

### Task 9: verify.sh

**Files:**
- Create: `verify.sh`

- [ ] **Step 1: Write verify.sh**

Checks all components and prints a status report:
- MCP binaries exist (codebase-memory-mcp, code-review-graph, ruvector)
- Docker container running + schema present (5 tables)
- Hook scripts exist and are executable
- Skills deployed to ~/.claude/skills/
- Config files in place (CLAUDE.md, settings.json, .mcp.json)
- GitHub token configured (non-empty in .mcp.json)
- Marker file exists

Each check prints `✓` or `✗` with details. Exit code 0 if all pass, 1 if any fail.

- [ ] **Step 2: Make executable and commit**

```bash
chmod +x verify.sh
git add verify.sh
git commit -m "feat: add verify.sh — post-install health check"
```

---

### Task 10: uninstall.sh

**Files:**
- Create: `uninstall.sh`

- [ ] **Step 1: Write uninstall.sh**

Script flow:
1. Confirm with user ("This will remove claude-memory-stack. Continue? [y/N]")
2. Stop and remove Docker container + volume
3. Restore backed-up config files (.bak → original)
4. Remove deployed hooks, skills, commands
5. Remove marker file
6. Print summary

- [ ] **Step 2: Make executable and commit**

```bash
chmod +x uninstall.sh
git add uninstall.sh
git commit -m "feat: add uninstall.sh — clean removal with backup restore"
```

---

### Task 11: Migration Scripts

**Files:**
- Create: `migration/migrate-pgvector.sh`
- Create: `migration/migrate-memorygraph.sh`
- Create: `migration/rollback.sh`

- [ ] **Step 1: Write migrate-pgvector.sh**

Script flow:
1. Check existing postgres on port 5432 is running
2. Export source tables to CSV/JSON (insights, note_chunks, observations)
3. Check RuVector postgres on port 5433 is running
4. Import data into claude_flow schema (map column types)
5. Add new columns (confidence, success_count, failure_count) with defaults
6. Verify row counts match
7. Print summary

```bash
# Export from existing pgvector (port 5432)
docker exec <old_container> psql -U "$SOURCE_USER" -d "$SOURCE_DB" \
  -c "\COPY insights TO '/tmp/insights.csv' CSV HEADER"

# Import to RuVector (port 5433)
docker cp <old_container>:/tmp/insights.csv /tmp/
docker cp /tmp/insights.csv claude-memory-stack-db:/tmp/
docker exec claude-memory-stack-db psql -U claude -d claude_flow \
  -c "\COPY claude_flow.insights(...) FROM '/tmp/insights.csv' CSV HEADER"
```

- [ ] **Step 2: Write migrate-memorygraph.sh**

Script flow:
1. Find memorygraph SQLite DB files
2. Export nodes and relations as JSON using sqlite3
3. Transform into patterns table format
4. Import into RuVector patterns table
5. Verify counts

- [ ] **Step 3: Write rollback.sh**

Script flow:
1. Stop RuVector container
2. Find all .bak files in ~/.claude/
3. Restore each .bak to original filename
4. Re-enable old hooks in settings.json
5. Print what was restored

- [ ] **Step 4: Make executable and commit**

```bash
chmod +x migration/*.sh
git add migration/
git commit -m "feat: add migration scripts (pgvector, memorygraph, rollback)"
```

---

### Task 12: README.md

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write README.md**

Full content from Section 3 of design presentation. Includes:
- Badges (MIT, Claude Code, Stars)
- Problem statement
- Architecture diagram
- Impact metrics table (token reduction numbers)
- Quick start (clone + install)
- Architecture deep dive (L1, L2, L3)
- Memory retrieval protocol
- Components table with sources
- Migration instructions
- Configuration reference
- Credits (all upstream repos + authors)
- License

Author: `Rajat Tanwar (@rajat1021)`

- [ ] **Step 2: Create docs/architecture.md**

Detailed architecture doc covering:
- Data flow diagrams
- Component interaction
- How each layer works
- When each layer is queried
- Token math

- [ ] **Step 3: Commit**

```bash
git add README.md docs/
git commit -m "docs: add README and architecture documentation"
```

---

### Task 13: Create GitHub Repo & Push

- [ ] **Step 1: Create remote repo**

```bash
cd ~/Documents/claude-memory-stack
gh repo create rajat1021/claude-memory-stack --public --description "Stop Claude from forgetting. 3-layer memory architecture for Claude Code — reduces tokens by 81%, adds self-learning. One-command deploy." --source . --push
```

- [ ] **Step 2: Add topics**

```bash
gh repo edit rajat1021/claude-memory-stack --add-topic claude-code,memory,knowledge-graph,mcp,ruvector,ai-coding,token-optimization,claude,anthropic
```

- [ ] **Step 3: Verify repo is live**

```bash
gh repo view rajat1021/claude-memory-stack --web
```

---

### Task 14: Run install.sh on This Mac

- [ ] **Step 1: Run the installer**

```bash
cd ~/Documents/claude-memory-stack
./install.sh
```

Expected: All steps pass, verify.sh shows all green.

- [ ] **Step 2: Verify Docker auto-start**

```bash
# Check Docker is in login items
osascript -e 'tell application "System Events" to get the name of every login item'
```

Expected: "Docker" in the list.

- [ ] **Step 3: Verify RuVector container restart policy**

```bash
docker inspect claude-memory-stack-db --format '{{.HostConfig.RestartPolicy.Name}}'
```

Expected: `always`

- [ ] **Step 4: Test reboot simulation**

```bash
docker stop claude-memory-stack-db
# Docker restart policy will bring it back
sleep 10
docker ps --filter name=claude-memory-stack-db --format '{{.Status}}'
```

Expected: Container is back up.

- [ ] **Step 5: Verify full stack in Claude Code**

```bash
claude --version
# Start a new Claude Code session and check:
# - CLAUDE.md loads correctly
# - MCP servers connect
# - Hooks fire
# - Skills listed
```

---

### Task 15: Run Migration (Existing Data)

- [ ] **Step 1: Run pgvector migration**

```bash
cd ~/Documents/claude-memory-stack
./migration/migrate-pgvector.sh
```

Expected: rows from your source DB successfully migrated into `insights`, `note_chunks`, and `observations`.

- [ ] **Step 2: Run memorygraph migration**

```bash
./migration/migrate-memorygraph.sh
```

Expected: Graph nodes imported as patterns.

- [ ] **Step 3: Verify data in RuVector**

```bash
docker exec claude-memory-stack-db psql -U claude -d claude_flow -c "
SELECT 'insights' as tbl, count(*) FROM claude_flow.insights
UNION ALL SELECT 'note_chunks', count(*) FROM claude_flow.note_chunks
UNION ALL SELECT 'observations', count(*) FROM claude_flow.observations
UNION ALL SELECT 'patterns', count(*) FROM claude_flow.patterns;
"
```

- [ ] **Step 4: Commit migration success**

```bash
git add -A
git commit -m "feat: complete installation and data migration"
git push
```

---

## Execution Order & Dependencies

```
Task 1 (scaffold)
  ↓
Task 2 (docker) ─── Task 3 (global config) ─── Task 4 (project template)
  ↓                    ↓                           ↓
Task 5 (copy skills/tips) ── Task 6 (hooks) ── Task 7 (commands)
  ↓                            ↓                    ↓
            Task 8 (install.sh)
                    ↓
            Task 9 (verify.sh)
                    ↓
            Task 10 (uninstall.sh)
                    ↓
            Task 11 (migration scripts)
                    ↓
            Task 12 (README + docs)
                    ↓
            Task 13 (GitHub repo + push)
                    ↓
            Task 14 (run install on this Mac)
                    ↓
            Task 15 (run migration)
```

Tasks 2-7 are independent and can run in parallel.
Tasks 8-12 depend on 2-7 being complete.
Tasks 13-15 are sequential.
