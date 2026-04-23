<!-- claude-memory-stack v1.0.0 | Architecture Deep Dive -->
<!-- Author: Rajat Tanwar (@rajat1021) -->
# Architecture

## Data Flow

```
User Message
    │
    ▼
┌──────────────────────────────────────────────────────┐
│                  Claude Code Session                  │
│                                                      │
│  1. System prompt loads L1 automatically             │
│     ┌──────────────────────────────────────────┐     │
│     │  ~/.claude/CLAUDE.md                     │     │
│     │  ~/.claude/memory-bank/*.md              │     │
│     │  <project>/.claude/CLAUDE.md             │     │
│     │  <project>/.claude/memory-bank/*.md      │     │
│     └──────────────────────────────────────────┘     │
│                       │                              │
│          Answer found in L1? ── YES ──► Respond      │
│                       │ NO                           │
│                       ▼                              │
│  2. Code question? Auto-query L2                     │
│     ┌──────────────────────────────────────────┐     │
│     │  auto-index hook ──► code-review-graph   │     │
│     │                        │                 │     │
│     │                        ▼                 │     │
│     │                  codebase-memory-mcp     │     │
│     │                  (search_code,           │     │
│     │                   get_architecture,      │     │
│     │                   trace_call_path,       │     │
│     │                   query_graph)           │     │
│     └──────────────────────────────────────────┘     │
│                       │                              │
│          Answer found in L2? ── YES ──► Respond      │
│                       │ NO                           │
│                       ▼                              │
│  3. Ask user, then query L3                          │
│     ┌──────────────────────────────────────────┐     │
│     │  RuVector PostgreSQL (pgvector)          │     │
│     │  ┌────────────────┐ ┌────────────────┐   │     │
│     │  │ insights       │ │ note_chunks    │   │     │
│     │  └────────────────┘ └────────────────┘   │     │
│     │  Queried via postgres MCP server         │     │
│     └──────────────────────────────────────────┘     │
│                       │                              │
│                       ▼                              │
│                    Respond                           │
└──────────────────────────────────────────────────────┘
```

## How Each Layer Is Queried

| Layer | Trigger | Method | Permission |
|-------|---------|--------|------------|
| L1 | Every turn | Loaded into system prompt by Claude Code harness | None needed |
| L2 | Code questions (architecture, call chains, dependencies) | MCP tool calls to codebase-memory-mcp | Automatic |
| L3 | Historical knowledge, past sessions, debugging history | SQL via postgres MCP (`ILIKE` or vector similarity) | Ask user first |

**L3 exceptions:** Queries fire automatically (no user prompt) when the message contains keywords like "history", "what happened last time", "insights", or "previous session".

## Token Math

### Per-Turn Cost

| Component | Without Stack | With Stack |
|-----------|---:|---:|
| System prompt (CLAUDE.md + context) | 22,000 | 16,500 |
| Code exploration (grep/glob/read cycles) | 2,500 | 0-100 |
| Memory retrieval overhead | 1,200 | 0-300 |
| **Per-turn total** | **~25,700** | **~16,900** |

The 16,500 system prompt with the stack is larger than a vanilla Claude Code prompt (~8,000), but it front-loads context that eliminates downstream queries. Net savings: ~34% per turn.

### Per-Session Cost (25 turns)

| Component | Without Stack | With Stack |
|-----------|---:|---:|
| System prompt (x25 turns) | 550,000 | 412,500 |
| Code exploration (avg 5 tasks) | 325,000 | 11,500 |
| Memory/context rebuilding | 36,000 | 0-2,400 |
| Redundant re-reads | 45,000 | 0 |
| **Estimated input tokens** | **~380,000** | **~72,000** |

The -96% on code exploration is the biggest win. A single `search_code` call (~200-500 tokens) replaces 5-10 grep/read cycles (~13,000 tokens each).

## Component Interaction

```
┌─────────────────────────────────────────────────┐
│              ~/.claude/ (Global)                │
│                                                 │
│  CLAUDE.md ──────────► System Prompt (L1)       │
│  memory-bank/*.md ───► System Prompt (L1)       │
│  settings.json ──────► Hook + Skill registry    │
│  .mcp.json ──────────► MCP server connections   │
│                                                 │
│  hooks/                                         │
│    no-leak.sh ───────► Pre-commit gate          │
│    auto-index.sh ────► Session-start indexer    │
│                                                 │
│  skills/                                        │
│    codebase-memory-* ► L2 query patterns        │
│    defuddle ─────────► Web content extraction   │
│                                                 │
│  commands/                                      │
│    init-project.md ──► Project bootstrapper     │
│    tech-tip.md ──────► Tip capture workflow     │
└─────────────┬───────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────┐
│            MCP Servers (Running)                │
│                                                 │
│  codebase-memory-mcp ◄── code-review-graph      │
│    (Neo4j-style graph,     (builds the graph    │
│     query interface)        from source code)   │
│                                                 │
│  postgres MCP ◄────────── RuVector PostgreSQL   │
│    (SQL interface)         (Docker container,   │
│                             pgvector extension) │
│                                                 │
│  github MCP ─────────────► GitHub API           │
│    (repos, PRs, issues)                         │
│                                                 │
│  ruflo ──────────────────► Task orchestration    │
│    (multi-step routing)                         │
│                                                 │
│  superpowers ────────────► 8 discipline skills   │
│    (brainstorm, plan,                           │
│     debug, review, ...)                         │
└─────────────────────────────────────────────────┘
```

## Security

The `no-leak` hook runs before every commit and blocks files matching:

- `*.env`, `.env.*`
- `*.key`, `*.pem`
- `credentials*`, `secrets*`

This prevents accidental exposure of secrets in git history.
