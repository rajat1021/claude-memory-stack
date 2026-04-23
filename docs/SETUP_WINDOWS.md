# Windows Setup — claude-memory-stack

Handoff instructions for a Claude Code instance to set up the stack on a **Windows** machine. The install scripts are bash (POSIX), so the path of least resistance is **WSL2 + Ubuntu**. Native PowerShell is possible but not supported here.

## What you're setting up

A 3-layer memory architecture for Claude Code:

| Layer | Storage | Purpose |
|-------|---------|---------|
| **L1** | `~/.claude/CLAUDE.md` + `memory-bank/` | Always-loaded context (user prefs, project facts) |
| **L2** | `~/.cache/codebase-memory-mcp/*.db` (global) | Code knowledge graph — indexed per project |
| **L3** | Postgres `claude_flow.conversation_turns` | Every user + assistant message with 384-d vector embedding |

## Embedding model (L3)

- **Model:** `sentence-transformers/all-MiniLM-L6-v2`
- **Dimensions:** 384
- **Distance metric:** cosine (pgvector `vector_cosine_ops`, HNSW index)
- **Input truncation:** 8000 chars per turn
- **Source:** `scripts/ingest-conversation.py` line 24 — `MODEL_NAME = "sentence-transformers/all-MiniLM-L6-v2"`
- **Runtime:** CPU is fine (this model is ~80 MB, fast enough for per-turn embedding). GPU not required.

## Prereqs to install first

Ask the user to install these on Windows **before** you run anything:

1. **WSL2 + Ubuntu 22.04** — `wsl --install -d Ubuntu-22.04` in an elevated PowerShell. Reboot, finish Ubuntu first-run.
2. **Docker Desktop for Windows** — with "Use the WSL 2 based engine" enabled (Settings → General). In Settings → Resources → WSL integration, toggle ON for Ubuntu-22.04.
3. **Git for Windows** — https://git-scm.com/download/win (provides git inside WSL too, but WSL already has its own)
4. **GitHub CLI (`gh`)** — inside WSL: `sudo apt install gh` or from https://cli.github.com/
5. **Node 20+** — inside WSL: `curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -; sudo apt install -y nodejs`
6. **Python 3.10+** (usually pre-installed on Ubuntu) + pip: `sudo apt install -y python3-pip python3-venv`
7. **jq** — `sudo apt install -y jq`
8. **Claude Code CLI** — `npm install -g @anthropic-ai/claude-code`

> **All subsequent commands run inside WSL Ubuntu**, not native Windows PowerShell.

## Installation

```bash
# Inside WSL Ubuntu shell
cd ~
git clone https://github.com/rajat1021/claude-memory-stack.git
cd claude-memory-stack
./install.sh
```

`install.sh` will:

1. Verify prereqs (fails fast if anything is missing)
2. Install MCP servers (codebase-memory-mcp, code-review-graph, ruvector)
3. Start `claude-memory-stack-db` (pgvector on port 5433) via docker-compose
4. Install Ruflo
5. Deploy `~/.claude/CLAUDE.md`, `settings.json`, `.mcp.json` (backs up existing)
6. Deploy all 10 hooks to `~/.claude/hooks/` + `statusline.sh` to `~/.claude/`
7. Deploy `scripts/` (ingest-conversation.py, setup-memory-architecture.sh, obsidian-session-note.py) to `~/.claude/scripts/`
8. `pip3 install --user sentence-transformers psycopg2-binary` (downloads the MiniLM model on first run, ~80 MB)
9. Deploy 10 skills, 7 commands, 5 tech-tips, project templates
10. Install Superpowers plugin
11. Run `verify.sh`

## Git auth — pin to the rajat1021 account

The repo is public-read but push-protected. If this machine will push:

```bash
# Authenticate both accounts if needed
gh auth login   # pick github.com → HTTPS → paste PAT or login via browser

# Store PAT in the Linux credential store so git push works without prompts
cd ~/claude-memory-stack
{
  echo "protocol=https"
  echo "host=github.com"
  echo "username=rajat1021"
  echo "password=$(gh auth token --user rajat1021)"
  echo ""
} | git credential-cache store

git remote set-url origin https://rajat1021@github.com/rajat1021/claude-memory-stack.git
git config --local credential.helper 'cache --timeout=31536000'   # 1 year
```

> On macOS the equivalent uses `osxkeychain` — this is the WSL/Linux variant. If you prefer libsecret (persistent), install `libsecret-tools` and use `credential.helper=/usr/share/doc/git/contrib/credential/libsecret/git-credential-libsecret`.

## Verification (run after install.sh)

```bash
# 1. MCP binary + version
codebase-memory-mcp --version            # expect 0.6.0+

# 2. Docker containers healthy
docker ps --format '{{.Names}}\t{{.Status}}' | grep claude-memory-stack-db

# 3. L3 table exists with the expected schema
docker exec claude-memory-stack-db psql -U claude -d claude_flow -c '\d conversation_turns'
# Must show: embedding | vector(384) and an hnsw(embedding vector_cosine_ops) index

# 4. Hooks deployed
ls ~/.claude/hooks/                      # expect 10 files
ls ~/.claude/scripts/                    # expect 3 files

# 5. Hooks wired in settings
jq -r '.hooks | keys[]' ~/.claude/settings.json
# expect: PostToolUse, PreToolUse, SessionStart, Stop, UserPromptSubmit

# 6. L3 ingest smoke test — launch Claude Code in any project with .mcp.json, send one prompt,
#    then:
docker exec claude-memory-stack-db psql -U claude -d claude_flow \
  -c "SELECT ts, role, LEFT(content,60) FROM conversation_turns ORDER BY ts DESC LIMIT 4;"
# Must show your prompt + Claude's response, both roles, with embedding populated.

# 7. L2 index a project
claude   # open Claude in a repo that has .mcp.json
# or manually:
codebase-memory-mcp cli index_repository '{"repo_path": "/full/path/to/repo"}'
codebase-memory-mcp cli list_projects '{}' | jq
```

## Windows-specific gotchas

1. **Line endings** — when cloning from Windows git, files may get CRLF. In WSL:
   ```bash
   git config --global core.autocrlf input
   ```
   If hook scripts fail with `/bin/bash^M: bad interpreter`, run:
   ```bash
   dos2unix ~/.claude/hooks/*.sh ~/.claude/scripts/*.sh
   ```

2. **Docker Desktop must be running** before `install.sh`. Check in WSL: `docker info` — if it errors, start Docker Desktop on Windows host.

3. **WSL filesystem location** — clone into the WSL native filesystem (`/home/<user>/`), **not** `/mnt/c/...`. Docker volume mounts and hook execution are ~10× faster on the WSL native FS.

4. **Path of `~/.claude/`** — this is `/home/<user>/.claude/` inside WSL, a different location from Windows's `%USERPROFILE%\.claude\` used by Claude Code Desktop. If the user runs Claude Code Desktop on Windows (not WSL), the hooks won't fire because Windows Claude Code won't see WSL's `~/.claude/`. The stack assumes **Claude Code CLI inside WSL**. Confirm this is the intended setup before installing.

5. **Python deps (L3)** — `sentence-transformers` pulls in `torch` (~2 GB). First `ingest-conversation.py` run downloads the MiniLM model (~80 MB) to `~/.cache/huggingface/`. Allow a few minutes on first run.

6. **PAT note** — do not paste the PAT into chat, shell history, or commit it. Use `gh auth token --user rajat1021` to retrieve on demand; pipe into the credential helper via here-doc as shown above.

## If Claude Code Desktop (Windows-native) is the target instead

Not supported by this stack. Paths, shell hooks, and Docker integration all assume a POSIX environment. Install WSL2 and use the CLI inside WSL, or open an issue before trying.

## Questions to confirm with the user before starting

1. WSL2 Ubuntu already installed? If not, do step 1 of prereqs first.
2. Docker Desktop installed with WSL integration enabled?
3. Are they using Claude Code CLI inside WSL, or Claude Code Desktop on Windows? (Only the former works.)
4. Do they want push access from this machine, or read-only clone?
5. Any existing `~/.claude/settings.json` to preserve? (install.sh backs up, but confirm nothing custom will be lost.)

## After install — persist this setup to memory

When install finishes, save a project memory so future sessions on this laptop know:

```
feedback_windows_setup.md
- Stack installed on <YYYY-MM-DD> via WSL2 Ubuntu 22.04
- Docker Desktop WSL backend
- Both postgres containers on ports 5432/5433
- L3 embedding model: sentence-transformers/all-MiniLM-L6-v2 (384d)
- Git auth: pinned to rajat1021 via credential-cache (rotate every 12 months)
```
