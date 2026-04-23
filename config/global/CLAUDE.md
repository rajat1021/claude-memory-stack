<!-- claude-memory-stack v1.0.0 | Rajat Tanwar (@rajat1021) -->
# Global Preferences

## Coding Style
- Use early returns, guard clauses
- Conventional commits (feat:, fix:, refactor:, docs:)
- Use `python3` not `python` on this Mac
- Never hardcode secrets — use environment variables

## Communication Style
- Keep responses short and tabular — no explanation until asked
- Show only system-defined data — don't add unsolicited commentary or analysis
- Verify claims with actual data/code before presenting — don't state things without evidence
- Don't change code until root cause is confirmed — explain the issue first, fix only after approval

## Projects
<!-- List your projects here, e.g.:
- **ProjectName**: ~/path/to/project — one-line description
-->

## Code Graph (codebase-memory-mcp) — USE IT
**Before using Grep/Glob to explore code, try the code graph first.**
- `search_code` — find functions, classes, routes by name
- `get_architecture` — get project structure overview
- `trace_call_path` — who calls this function, what does it call
- `query_graph` — Cypher queries for complex relationships
- `get_code_snippet` — get a specific function's code
**When to use Grep/Glob instead:** quick exact-string lookups, file existence checks, or when graph returns empty.

## Memory Retrieval Protocol

### L1 — Always Loaded (free)
CLAUDE.md + @imported memory-bank files. Check here FIRST — already in context.

### L2 — Code Intelligence (auto)
code-review-graph → codebase-memory-mcp pipeline.
Auto-use for any code question — no need to ask user.

### L3 — Knowledge + Learning (ask first)
RuVector PostgreSQL — long-term knowledge, patterns, history, graph.
If L1 doesn't have the answer, ASK before querying:
  "I don't have enough context. Want me to search the knowledge DB?"
Only query L3 when user approves.
Exception: If user explicitly mentions "history", "insights",
or "patterns" — query L3 directly without asking.

## Shared Tech Tips
@.claude/memory-bank/tech-tips/python.md
@.claude/memory-bank/tech-tips/docker-infra.md
@.claude/memory-bank/tech-tips/claude-mcp.md
@.claude/memory-bank/tech-tips/react-typescript.md
@.claude/memory-bank/tech-tips/power-automate.md
