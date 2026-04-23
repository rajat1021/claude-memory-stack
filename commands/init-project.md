<!-- claude-memory-stack v1.0.0 | Rajat Tanwar (@rajat1021) -->
---
name: init-project
description: Bootstrap a new project with the claude-memory-stack 3-layer architecture
arguments:
  - name: project_name
    description: Name of the project to initialize
    required: true
---

# Initialize Project: $ARGUMENTS.project_name

Templates live in the claude-memory-stack install at `~/.claude/templates/project/`
(or `<repo>/templates/project/` if running from the repo). Resolve `$TEMPLATE_DIR`
to whichever exists before copying.

## Steps

1. **Create project CLAUDE.md**
   - Copy `$TEMPLATE_DIR/CLAUDE.md` to `./CLAUDE.md`
   - Replace `__PROJECT_NAME__` with `$ARGUMENTS.project_name`

2. **Create project .mcp.json**
   - Copy `$TEMPLATE_DIR/.mcp.json` to `./.mcp.json`
   - Replace `__CMS_CODEBASE_MEMORY_BIN__` with `$(which codebase-memory-mcp)`
   - Replace `__CMS_DB_PASSWORD__` with `$CMS_DB_PASSWORD` env var, or default `dev_password_change_me`

3. **Create memory-bank directory**
   - Copy `$TEMPLATE_DIR/memory-bank/` → `./.claude/memory-bank/` (preserve subdirs: architecture, decisions, patterns, troubleshooting)
   - Replace `__PROJECT_NAME__` in each copied file

4. **Build code indexes**
   - Run: `code-review-graph build` (if installed)
   - Run: `codebase-memory-mcp cli index_repository '{"repo_path": "."}'` (if installed)
   - Report node/edge counts

5. **Confirm**
   - Print: "Project $ARGUMENTS.project_name initialized with claude-memory-stack"
   - List all created files
