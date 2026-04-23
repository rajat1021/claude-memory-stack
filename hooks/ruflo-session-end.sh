#!/usr/bin/env bash
# SessionEnd hook — close out the most recent open session row for this cwd.

set -u

CWD="${CLAUDE_CWD:-$(pwd)}"

(
  PGVECTOR_CONTAINER="${PGVECTOR_CONTAINER:-claude-memory-stack-db}"
  PGVECTOR_USER="${PGVECTOR_USER:-claude}"
  PGVECTOR_DB="${PGVECTOR_DB:-claude_flow}"
  docker exec -i "$PGVECTOR_CONTAINER" psql -U "$PGVECTOR_USER" -d "$PGVECTOR_DB" -v ON_ERROR_STOP=1 >/dev/null 2>&1 <<SQL
UPDATE ruflo.sessions
   SET ended_at = now()
 WHERE id = (
   SELECT id FROM ruflo.sessions
    WHERE cwd = '$(printf %s "$CWD" | sed "s/'/''/g")'
      AND ended_at IS NULL
    ORDER BY started_at DESC
    LIMIT 1
 );
SQL
) &

exit 0
