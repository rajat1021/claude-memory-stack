# __PROJECT_NAME__ — Project Description

## Memory Bank (@imports — always loaded at session start)

@.claude/memory-bank/architecture/system-overview.md
@.claude/memory-bank/patterns/coding-standards.md
@.claude/memory-bank/troubleshooting/known-issues.md

## Memory Architecture (3 Layers — ALL ACTIVE)
- **Layer 1 (Structured)**: `.claude/memory-bank/` — loaded every session via @imports
- **Layer 2 (Knowledge Graph)**: memorygraphMCP + codebase-memory-mcp — query for decisions, code relationships
- **Layer 3 (pgvector)**: Postgres (claude_flow DB) — semantic search across knowledge

## What Is This Project
<!-- describe -->

## Architecture
<!-- describe -->

## Project Structure
```
project/
├── src/              # Source code
├── tests/            # Tests
├── .claude/          # Claude Code config
│   ├── memory-bank/  # Layer 1 structured memory
│   │   ├── architecture/
│   │   ├── decisions/
│   │   ├── patterns/
│   │   └── troubleshooting/
│   └── agents/       # Project-specific agents
├── CLAUDE.md         # This file
└── .mcp.json         # Project MCP servers
```

## Key Rules
- Never hardcode secrets — use environment variables
- Document decisions in `.claude/memory-bank/decisions/` with ADR format

## Commands
<!-- project-specific commands -->

## Dependencies
<!-- list -->

## Mandatory Reading
| Document | Read Before |
|----------|------------|
| This CLAUDE.md | Any work on this project |
| memory-bank/architecture/ | Structural changes |
| memory-bank/decisions/ | Making new decisions |
| memory-bank/patterns/ | Writing new code |
| memory-bank/troubleshooting/ | Debugging |
