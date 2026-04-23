# Design Spec: claude-memory-stack

**Date:** 2026-04-12
**Author:** Rajat Tanwar (@rajat1021)
**Repo:** https://github.com/rajat1021/claude-memory-stack
**Status:** Approved — ready for implementation

---

## 1. Problem Statement

Claude Code forgets everything between sessions. Existing solutions (pgvector, memorygraph) store data but retrieve poorly — more conversations = worse signal-to-noise ratio. The current 3-layer architecture works but wastes tokens: mandatory L2+L3 queries on every question, bloated system prompt (22K tokens/turn), no code scoping, no learning loop.

**Goal:** Rebuild the 3-layer architecture as a portable, deployable GitHub repo that:
- Reduces token consumption by ~81% per session
- Adds intelligent code scoping (blast-radius → targeted retrieval)
- Adds self-learning (ReasoningBank)
- Deploys on any new machine with one command

---

## 2. Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    CLAUDE CODE SESSION                    │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  L1 — ALWAYS-LOADED CONTEXT (free)                      │
│  ┌────────────────────────────────────────────────────┐  │
│  │ CLAUDE.md → @imports memory-bank/*.md              │  │
│  │ (project prefs, decisions, patterns, strategies)   │  │
│  └────────────────────────────────────────────────────┘  │
│                          │                               │
│  L2 — CODE INTELLIGENCE PIPELINE (auto on code queries) │
│  ┌──────────────────┐    ┌──────────────────────────┐   │
│  │ code-review-graph │───▶│ codebase-memory-mcp      │   │
│  │ "what's affected?"│    │ "get exactly that code"  │   │
│  │ blast-radius      │    │ get_code_snippet()       │   │
│  │ risk scoring      │    │ trace_call_path()        │   │
│  └──────────────────┘    └──────────────────────────┘   │
│                          │                               │
│  L3 — KNOWLEDGE + LEARNING (on-demand, ask user first)  │
│  ┌────────────────────────────────────────────────────┐  │
│  │ RuVector PostgreSQL                                │  │
│  │ Vector search (insights, note_chunks, etc)         │  │
│  │ ReasoningBank (RETRIEVE→JUDGE→DISTILL→ROUTE)      │  │
│  │ Graph ops (replaces memorygraph)                    │  │
│  │ Pattern tracking (confidence, success/failure)      │  │
│  └────────────────────────────────────────────────────┘  │
│                          │                               │
│  ORCHESTRATION — RUFLO                                   │
│  ┌────────────────────────────────────────────────────┐  │
│  │ Swarm coordination (Queen/Worker)                   │  │
│  │ Q-Learning task routing                             │  │
│  │ Multi-model selection (Opus/Sonnet/Haiku)           │  │
│  └────────────────────────────────────────────────────┘  │
│                          │                               │
│  DISCIPLINE — SUPERPOWERS (8 skills)                    │
│  ┌────────────────────────────────────────────────────┐  │
│  │ TDD │ Debugging │ Verification │ Code Review (give) │  │
│  │ Code Review (receive) │ Branch Finish │ Worktrees  │  │
│  │ Brainstorming                                       │  │
│  └────────────────────────────────────────────────────┘  │
│                          │                               │
│  SECURITY — no-leak hook                                │
│                                                          │
│  MCP SERVERS: 4                                          │
│  code-review-graph │ codebase-memory-mcp │ ruvector │ github │
└─────────────────────────────────────────────────────────┘
```

---

## 3. Memory Retrieval Protocol

```
L1 (check first, free) → L2 (auto for code) → L3 (ask user first)
```

### L1 — Always Loaded
CLAUDE.md + @imported memory-bank files. Check here FIRST — already in context.

### L2 — Code Intelligence (auto)
code-review-graph → codebase-memory-mcp pipeline.
Auto-fires on any code question. No permission needed.

### L3 — Knowledge + Learning (ask first)
RuVector PostgreSQL — long-term knowledge, patterns, history, graph.
If L1 doesn't have the answer, ASK before querying:
> "I don't have enough context. Want me to search the knowledge DB?"

Only query L3 when user approves.
**Exception:** If user explicitly mentions "history", "insights", or "patterns" — query L3 directly.

---

## 4. Components

### 4.1 MCP Servers (4 total)

| # | Server | Source | Role | Tools |
|---|--------|--------|------|------:|
| 1 | code-review-graph | tirth8205/code-review-graph | L2 scoping — blast-radius, risk scoring | 22 |
| 2 | codebase-memory-mcp | DeusData/codebase-memory-mcp | L2 retrieval — code snippets, call traces | 14 |
| 3 | ruvector MCP | ruvnet/ruflo (ruvector) | L3 — vectors, learning, graph, routing | 30+ |
| 4 | github MCP | @anthropic-ai/github-mcp-server | GitHub integration — PRs, issues, CI | 20+ |

### 4.2 Hooks (2 total)

| Hook | Event | Script | Purpose |
|------|-------|--------|---------|
| no-leak | PreToolUse (Read/Edit/Write/Bash/Glob) | no-leak.sh | Block .env, .pem, .key, credentials |
| auto-index | SessionStart | auto-index.sh | Re-index codebase if stale (>24h) |

### 4.3 Skills (5 custom + 8 superpowers)

**Custom skills (deployed to ~/.claude/skills/):**
- codebase-memory-exploring
- codebase-memory-tracing
- codebase-memory-quality
- codebase-memory-reference
- defuddle

**Superpowers plugin (8 of 14 active):**
- brainstorming
- writing-plans
- test-driven-development
- systematic-debugging
- requesting-code-review
- receiving-code-review
- verification-before-completion
- finishing-a-development-branch
- using-git-worktrees

**Superpowers skills KILLED (6):**
- using-superpowers (117 lines/turn system prompt tax)
- writing-skills (655 lines, rarely used)
- executing-plans (replaced by Ruflo orchestrator)
- dispatching-parallel-agents (replaced by Ruflo swarms)
- subagent-driven-development (replaced by Ruflo orchestrator)
- brainstorm (deprecated alias)

### 4.4 Orchestration — Ruflo

Install Ruflo but enable ONLY:
- Swarm coordination (Queen/Worker)
- Q-Learning task routing
- ReasoningBank (RETRIEVE→JUDGE→DISTILL→ROUTE)
- Multi-model selection

DO NOT enable: 130+ skills, hive-mind consensus, flow-nexus, pair-mode, neural-network, 598 commands. These bloat the system prompt and overlap with Superpowers.

### 4.5 RuVector PostgreSQL

Docker image: `ruvnet/ruvector-postgres:latest`

**Schema:**

```sql
-- Core tables
CREATE TABLE claude_flow.insights (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    insight_type VARCHAR(50) NOT NULL,
    project VARCHAR(50) DEFAULT 'default',
    model_name VARCHAR(100),
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    embedding ruvector(384),
    tags TEXT[] DEFAULT '{}',
    source VARCHAR(100),
    occurred_on DATE,
    importance FLOAT DEFAULT 0.5,
    reference_count INT DEFAULT 0,
    success BOOLEAN,                    -- was this insight correct?
    confidence FLOAT DEFAULT 0.5,       -- RuVector pattern confidence
    success_count INT DEFAULT 0,        -- times this pattern succeeded
    failure_count INT DEFAULT 0,        -- times this pattern failed
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE claude_flow.note_chunks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    file_path TEXT NOT NULL,
    chunk_index INT NOT NULL,
    content TEXT NOT NULL,
    embedding ruvector(384),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(file_path, chunk_index)
);

CREATE TABLE claude_flow.observations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID,
    tool_name VARCHAR(50) NOT NULL,
    summary TEXT NOT NULL,
    category VARCHAR(50) DEFAULT 'general',
    embedding ruvector(384),
    importance FLOAT DEFAULT 0.5,
    success BOOLEAN DEFAULT true,
    confidence FLOAT DEFAULT 0.5,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ReasoningBank patterns table
CREATE TABLE claude_flow.patterns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    embedding ruvector(384),
    pattern_type VARCHAR(50),
    confidence FLOAT DEFAULT 0.5,
    success_count INT DEFAULT 0,
    failure_count INT DEFAULT 0,
    ewc_importance FLOAT DEFAULT 1.0,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Agent routing table
CREATE TABLE claude_flow.agents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id VARCHAR(255) NOT NULL UNIQUE,
    agent_type VARCHAR(50),
    state JSONB DEFAULT '{}',
    memory_embedding ruvector(384),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_insights_embedding_hnsw ON claude_flow.insights
    USING hnsw (embedding ruvector_cosine_ops) WITH (m='16', ef_construction='64');
CREATE INDEX idx_note_chunks_embedding_hnsw ON claude_flow.note_chunks
    USING hnsw (embedding ruvector_cosine_ops) WITH (m='16', ef_construction='64');
CREATE INDEX idx_observations_embedding_hnsw ON claude_flow.observations
    USING hnsw (embedding ruvector_cosine_ops) WITH (m='16', ef_construction='64');
CREATE INDEX idx_patterns_embedding_hnsw ON claude_flow.patterns
    USING hnsw (embedding ruvector_cosine_ops) WITH (m='16', ef_construction='64');
```

---

## 5. What Gets Killed

| Component | Replaced By |
|-----------|------------|
| memorygraph MCP | RuVector graph ops |
| postgres MCP (pgvector) | RuVector MCP |
| claude-reflect plugin (4 hooks + 4 commands) | Ruflo ReasoningBank + session-end |
| claude-diary plugin (1 hook + 2 commands) | Ruflo session-memory |
| `using-superpowers` skill (117 lines/turn) | 2-line CLAUDE.md rule |
| `writing-skills` skill (655 lines) | On-demand only |
| `dispatching-parallel-agents` skill | Ruflo swarms |
| `subagent-driven-development` skill | Ruflo orchestrator |
| `executing-plans` skill | Ruflo orchestrator |
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` env | Ruflo swarms |
| Mandatory L2+L3 protocol | On-demand retrieval protocol |

---

## 6. Token Impact

### Per-Turn System Prompt

| Component | Current | New | Saved |
|-----------|--------:|----:|------:|
| Claude Code base | 6,800 | 6,800 | 0 |
| Global CLAUDE.md | 1,615 | 935 | 680 |
| @imported memory-bank | 4,590 | 3,400 | 1,190 |
| using-superpowers (full) | 2,550 | 0 | 2,550 |
| Skill descriptions (30→13) | 1,700 | 765 | 935 |
| MCP tool names | 850 | 680 | 170 |
| Auto-memory instructions | 3,400 | 3,400 | 0 |
| Environment info | 510 | 510 | 0 |
| **Total** | **22,015** | **16,490** | **5,525 (-25%)** |

### Per-Session Operational

| Category | Current | New | Saved |
|----------|--------:|----:|------:|
| System prompt (25 turns, cached) | 75,000 | 55,000 | 20,000 |
| Mandatory L2+L3 queries | 27,000 | 4,000 | 23,000 |
| Code exploration (4 tasks) | 260,000 | 9,200 | 250,800 |
| Hooks overhead | 7,500 | 0 | 7,500 |
| Skill deliberation | 6,500 | 0 | 6,500 |
| **Total per session** | **~380,000** | **~72,000** | **~308,000 (-81%)** |

### Effective Budget Multiplier

| Metric | Value |
|--------|------:|
| Sessions per $ budget | **~5x more** |
| Code exploration efficiency | **28x fewer tokens** |
| Memory queries saved | **73% fewer** |
| Bug-related rework | **-75%** (TDD + verification) |

---

## 7. Repository Structure

```
claude-memory-stack/
├── install.sh                    # One-command setup
├── uninstall.sh                  # Clean removal
├── verify.sh                     # Post-install health check
├── LICENSE                       # MIT
├── README.md                     # Full documentation
│
├── config/
│   ├── global/
│   │   ├── CLAUDE.md             # Global prefs + memory protocol
│   │   ├── settings.json         # Hooks, permissions
│   │   └── .mcp.json             # GitHub MCP (token from $GITHUB_TOKEN)
│   ├── project-template/
│   │   ├── CLAUDE.md             # Template project CLAUDE.md
│   │   ├── .mcp.json             # code-review-graph + codebase-memory + ruvector
│   │   └── memory-bank/
│   │       ├── architecture.md
│   │       ├── decisions.md
│   │       ├── patterns.md
│   │       └── troubleshooting.md
│   └── memory-bank/
│       └── tech-tips/
│           ├── python.md
│           ├── docker-infra.md
│           ├── claude-mcp.md
│           ├── react-typescript.md
│           └── power-automate.md
│
├── hooks/
│   ├── no-leak.sh                # PreToolUse — block sensitive files
│   └── auto-index.sh             # SessionStart — index if stale
│
├── skills/
│   ├── codebase-memory-exploring/SKILL.md
│   ├── codebase-memory-tracing/SKILL.md
│   ├── codebase-memory-quality/SKILL.md
│   ├── codebase-memory-reference/SKILL.md
│   └── defuddle/SKILL.md
│
├── docker/
│   ├── docker-compose.yml        # RuVector PostgreSQL
│   └── init-db.sql               # Full schema
│
├── migration/
│   ├── migrate-pgvector.sh       # pgvector → RuVector
│   ├── migrate-memorygraph.sh    # memorygraph → RuVector
│   └── rollback.sh               # Restore original
│
├── commands/
│   ├── init-project.md           # /init-project
│   └── tech-tip.md               # /tech-tip
│
└── docs/
    ├── architecture.md           # Deep dive
    └── superpowers/
        └── specs/
            └── 2026-04-12-claude-memory-stack-design.md
```

---

## 8. Install Flow

```
$ git clone https://github.com/rajat1021/claude-memory-stack.git
$ cd claude-memory-stack
$ ./install.sh
```

### install.sh Steps

1. **Check prerequisites** — Node.js 20+, Docker, Claude Code, jq
2. **Install MCP servers** — codebase-memory-mcp, code-review-graph, ruvector
3. **Start RuVector PostgreSQL** — docker compose up, wait for health, run init-db.sql
4. **Install Ruflo** — swarms + routing + ReasoningBank only
5. **Deploy global config** — backup existing → copy CLAUDE.md, settings.json, .mcp.json
6. **Deploy hooks & skills** — copy to ~/.claude/hooks/ and ~/.claude/skills/
7. **Install Superpowers** — claude plugins install superpowers
8. **Configure GitHub PAT** — read from $GITHUB_TOKEN env var
9. **Run verify.sh** — confirm all components operational

### verify.sh Checks

- All 4 MCP server binaries/packages exist
- RuVector PostgreSQL container running + schema created
- Hook scripts executable
- Skills deployed
- Config files in place
- Ruflo installed with correct features

---

## 9. Migration Plan (Existing Users)

### From pgvector → RuVector

```bash
./migration/migrate-pgvector.sh
```

1. Export source tables from existing PostgreSQL into `insights`, `note_chunks`, `observations`
2. Transform vector(384) → ruvector(384) column types
3. Add new columns (confidence, success_count, failure_count)
4. Import into RuVector PostgreSQL
5. Generate embeddings for any rows missing them
6. Verify row counts match

### From memorygraph → RuVector

```bash
./migration/migrate-memorygraph.sh
```

1. Export all nodes and relations from memorygraph SQLite
2. Transform into RuVector patterns table entries
3. Preserve entity-relation structure as JSONB metadata
4. Import into RuVector PostgreSQL

### Rollback

```bash
./migration/rollback.sh
```

Restores all backed-up files (.bak) and stops RuVector container.

---

## 10. /init-project Command

```bash
claude /init-project my-trading-bot
```

Creates:
```
my-trading-bot/
├── .mcp.json
├── CLAUDE.md
└── .claude/
    └── memory-bank/
        ├── architecture.md
        ├── decisions.md
        ├── patterns.md
        └── troubleshooting.md
```

Then runs:
```
code-review-graph build
codebase-memory-mcp cli index_repository
```

---

## 11. Author Signals

Every file carries a header:

**Shell:** `# claude-memory-stack v1.0.0 | Rajat Tanwar (@rajat1021)`
**SQL:** `-- claude-memory-stack v1.0.0 | Rajat Tanwar (@rajat1021)`
**Markdown:** `<!-- claude-memory-stack v1.0.0 | Rajat Tanwar (@rajat1021) -->`
**JSON:** `"_meta": {"stack": "claude-memory-stack", "author": "Rajat Tanwar"}`

Hidden marker at `~/.claude/.claude-memory-stack` with version + install timestamp.

---

## 12. Decisions Made

| Decision | Chosen | Over | Why |
|----------|--------|------|-----|
| Vector DB | RuVector PostgreSQL | pgvector | Learning loop, pattern tracking, graph ops |
| Knowledge graph | RuVector graph ops | memorygraph | One fewer dependency, SQL-native |
| Code scoping | code-review-graph | None (read everything) | 96% token reduction on exploration |
| Code retrieval | codebase-memory-mcp | grep/glob | 66 languages, sub-ms queries |
| Orchestration | Ruflo swarms | Agent Teams | Learning, routing, multi-model |
| Process discipline | Superpowers (8 skills) | Ruflo SPARC | Deeper methodology, iron laws |
| Memory queries | On-demand (L2 auto, L3 ask) | Mandatory every question | 73% fewer queries |
| Portability | Single repo + install.sh | Manual setup | One-command deploy |
| GitHub PAT | $GITHUB_TOKEN env var | Hardcoded in .mcp.json | Security |

---

## 13. Risks

| Risk | Mitigation |
|------|-----------|
| Ruflo is single-maintainer | Only use orchestration layer; DB (RuVector PostgreSQL) works independently |
| code-review-graph is new (Feb 2026) | codebase-memory-mcp is fallback for all code queries |
| RuVector extension maturity | Standard PostgreSQL underneath; can revert to pgvector |
| Superpowers + Ruflo skill overlap | Only 8 Superpowers skills active; Ruflo skills NOT loaded |
| Migration data loss | Full backup before migration; rollback.sh available |

---

## 14. Success Criteria

- [ ] `install.sh` completes on fresh Mac in <10 minutes
- [ ] `verify.sh` passes all checks
- [ ] Token consumption per session drops by >70%
- [ ] Code exploration uses <5K tokens (down from ~65K)
- [ ] L3 queries only fire when user approves
- [ ] L2 auto-fires on code questions without user intervention
- [ ] ReasoningBank stores learned patterns after sessions
- [ ] `/init-project` bootstraps new project in <30 seconds
- [ ] Migration scripts preserve all existing data
- [ ] Rollback restores previous setup completely
