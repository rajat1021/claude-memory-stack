#!/usr/bin/env bash
# SessionStart hook — log session into ruflo.sessions (Postgres central brain)
# Runs non-blocking. Silent on failure.

set -u

CWD="${CLAUDE_CWD:-$(pwd)}"
PROJECT="$(basename "$CWD")"
SESSION_ID="${CLAUDE_SESSION_ID:-session-$(date +%s)-$$}"
META="$(printf '{"host":"%s","user":"%s"}' "$(hostname -s)" "${USER:-unknown}")"

# Fire-and-forget; don't block session start
(
  PGVECTOR_CONTAINER="${PGVECTOR_CONTAINER:-claude-memory-stack-db}"
  PGVECTOR_USER="${PGVECTOR_USER:-claude}"
  PGVECTOR_DB="${PGVECTOR_DB:-claude_flow}"
  docker exec -i "$PGVECTOR_CONTAINER" psql -U "$PGVECTOR_USER" -d "$PGVECTOR_DB" -v ON_ERROR_STOP=1 >/dev/null 2>&1 <<SQL
INSERT INTO ruflo.sessions (session_id, cwd, project, meta)
VALUES ('$(printf %s "$SESSION_ID" | sed "s/'/''/g")',
        '$(printf %s "$CWD" | sed "s/'/''/g")',
        '$(printf %s "$PROJECT" | sed "s/'/''/g")',
        '$(printf %s "$META" | sed "s/'/''/g")'::jsonb);
SQL
) &

exit 0
