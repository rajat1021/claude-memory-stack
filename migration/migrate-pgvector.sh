#!/usr/bin/env bash
# ─────────────────────────────────────────────────
# claude-memory-stack v1.0.0 | MIT License
# Author: Rajat Tanwar (@rajat1021)
# https://github.com/rajat1021/claude-memory-stack
# ─────────────────────────────────────────────────
# Migrate existing pgvector data → RuVector PostgreSQL
#
# Configure source via env vars:
#   SOURCE_USER, SOURCE_DB              (required — your existing DB creds)
#   SOURCE_INSIGHTS_TABLE               (default: insights)
#   SOURCE_NOTES_TABLE                  (default: note_chunks)
#   SOURCE_OBS_TABLE                    (default: observations)
#   SOURCE_INSIGHTS_DATE_COL            (default: occurred_on — source column for insights date)
#   SOURCE_NOTES_TS_COL                 (default: created_at — source column for note timestamp)
#
# Target schema is defined in docker/init-db.sql.
set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[migrate]${NC} $1"; }
warn() { echo -e "${YELLOW}[migrate]${NC} $1"; }
fail() { echo -e "${RED}[migrate]${NC} $1"; exit 1; }

TARGET_CONTAINER="${TARGET_CONTAINER:-claude-memory-stack-db}"
TARGET_USER="${TARGET_USER:-claude}"
TARGET_DB="${TARGET_DB:-claude_flow}"

SOURCE_USER="${SOURCE_USER:?set SOURCE_USER to your existing Postgres user}"
SOURCE_DB="${SOURCE_DB:?set SOURCE_DB to your existing Postgres database}"

SOURCE_INSIGHTS_TABLE="${SOURCE_INSIGHTS_TABLE:-insights}"
SOURCE_NOTES_TABLE="${SOURCE_NOTES_TABLE:-note_chunks}"
SOURCE_OBS_TABLE="${SOURCE_OBS_TABLE:-observations}"
SOURCE_INSIGHTS_DATE_COL="${SOURCE_INSIGHTS_DATE_COL:-occurred_on}"
SOURCE_NOTES_TS_COL="${SOURCE_NOTES_TS_COL:-created_at}"

TARGET_TABLES=("insights" "note_chunks" "observations")

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  pgvector → RuVector Migration"
echo "═══════════════════════════════════════════════════════"
echo ""

# ─────────────────────────────────────────────────
# Step 1: Find source container (port 5432)
# ─────────────────────────────────────────────────
log "Finding source PostgreSQL container (port 5432)..."

SOURCE_CONTAINER=$(docker ps --format '{{.Names}}\t{{.Ports}}' \
  | grep '0.0.0.0:5432->' \
  | awk -F'\t' '{print $1}' \
  | head -1)

if [[ -z "$SOURCE_CONTAINER" ]]; then
  fail "No Docker container found on port 5432. Start your existing pgvector PostgreSQL first."
fi
log "  Source container: $SOURCE_CONTAINER"

# Verify source is accessible
if ! docker exec "$SOURCE_CONTAINER" pg_isready -U "$SOURCE_USER" -d "$SOURCE_DB" >/dev/null 2>&1; then
  fail "Source PostgreSQL not ready (user=$SOURCE_USER, db=$SOURCE_DB)"
fi
log "  Source database accessible"

# ─────────────────────────────────────────────────
# Step 2: Check target RuVector container
# ─────────────────────────────────────────────────
log "Checking target RuVector container..."

if ! docker ps --format '{{.Names}}' | grep -q "^${TARGET_CONTAINER}$"; then
  fail "Target container $TARGET_CONTAINER not running. Run install.sh first."
fi

if ! docker exec "$TARGET_CONTAINER" pg_isready -U "$TARGET_USER" -d "$TARGET_DB" >/dev/null 2>&1; then
  fail "Target PostgreSQL not ready"
fi
log "  Target database accessible"

# ─────────────────────────────────────────────────
# Step 3: Migrate each table
# ─────────────────────────────────────────────────
INS_COUNT=0; NC_COUNT=0; OBS_COUNT=0

# --- insights ---
log "Migrating insights (from $SOURCE_INSIGHTS_TABLE)..."

# Common columns. Source date column is parameterised so it can map to target `occurred_on`.
INS_EXPORT="id,insight_type,project,model_name,title,content,embedding,tags,source,${SOURCE_INSIGHTS_DATE_COL},importance,reference_count,success,metadata,created_at,updated_at"
INS_IMPORT="id,insight_type,project,model_name,title,content,embedding,tags,source,occurred_on,importance,reference_count,success,metadata,created_at,updated_at"

docker exec "$SOURCE_CONTAINER" psql -U "$SOURCE_USER" -d "$SOURCE_DB" -c \
  "\\COPY (SELECT $INS_EXPORT FROM public.${SOURCE_INSIGHTS_TABLE}) TO '/tmp/insights.csv' CSV HEADER" \
  >/dev/null 2>&1

docker cp "$SOURCE_CONTAINER:/tmp/insights.csv" /tmp/insights.csv
# Rewrite header to match target column name
sed -i '' "1s/${SOURCE_INSIGHTS_DATE_COL}/occurred_on/" /tmp/insights.csv
docker cp /tmp/insights.csv "$TARGET_CONTAINER:/tmp/insights.csv"

docker exec "$TARGET_CONTAINER" psql -U "$TARGET_USER" -d "$TARGET_DB" -c \
  "\\COPY claude_flow.insights($INS_IMPORT) FROM '/tmp/insights.csv' CSV HEADER" \
  >/dev/null 2>&1

INS_COUNT=$(docker exec "$TARGET_CONTAINER" psql -U "$TARGET_USER" -d "$TARGET_DB" -tAc \
  "SELECT count(*) FROM claude_flow.insights")
log "  insights: $INS_COUNT rows imported"

# --- note_chunks ---
log "Migrating note_chunks (from $SOURCE_NOTES_TABLE)..."

NC_EXPORT="id,file_path,chunk_index,content,embedding,metadata,${SOURCE_NOTES_TS_COL}"
NC_IMPORT="id,file_path,chunk_index,content,embedding,metadata,created_at"

docker exec "$SOURCE_CONTAINER" psql -U "$SOURCE_USER" -d "$SOURCE_DB" -c \
  "\\COPY (SELECT $NC_EXPORT FROM public.${SOURCE_NOTES_TABLE}) TO '/tmp/note_chunks.csv' CSV HEADER" \
  >/dev/null 2>&1

docker cp "$SOURCE_CONTAINER:/tmp/note_chunks.csv" /tmp/note_chunks.csv
sed -i '' "1s/${SOURCE_NOTES_TS_COL}/created_at/" /tmp/note_chunks.csv
docker cp /tmp/note_chunks.csv "$TARGET_CONTAINER:/tmp/note_chunks.csv"

docker exec "$TARGET_CONTAINER" psql -U "$TARGET_USER" -d "$TARGET_DB" -c \
  "\\COPY claude_flow.note_chunks($NC_IMPORT) FROM '/tmp/note_chunks.csv' CSV HEADER" \
  >/dev/null 2>&1

NC_COUNT=$(docker exec "$TARGET_CONTAINER" psql -U "$TARGET_USER" -d "$TARGET_DB" -tAc \
  "SELECT count(*) FROM claude_flow.note_chunks")
log "  note_chunks: $NC_COUNT rows imported"

# --- observations ---
log "Migrating observations (from $SOURCE_OBS_TABLE)..."

OBS_COLS="id,session_id,tool_name,summary,category,embedding,importance,success,metadata,created_at"

docker exec "$SOURCE_CONTAINER" psql -U "$SOURCE_USER" -d "$SOURCE_DB" -c \
  "\\COPY (SELECT $OBS_COLS FROM public.${SOURCE_OBS_TABLE}) TO '/tmp/observations.csv' CSV HEADER" \
  >/dev/null 2>&1

docker cp "$SOURCE_CONTAINER:/tmp/observations.csv" /tmp/observations.csv
docker cp /tmp/observations.csv "$TARGET_CONTAINER:/tmp/observations.csv"

docker exec "$TARGET_CONTAINER" psql -U "$TARGET_USER" -d "$TARGET_DB" -c \
  "\\COPY claude_flow.observations($OBS_COLS) FROM '/tmp/observations.csv' CSV HEADER" \
  >/dev/null 2>&1

OBS_COUNT=$(docker exec "$TARGET_CONTAINER" psql -U "$TARGET_USER" -d "$TARGET_DB" -tAc \
  "SELECT count(*) FROM claude_flow.observations")
log "  observations: $OBS_COUNT rows imported"

# ─────────────────────────────────────────────────
# Step 4: Summary
# ─────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Migration Summary"
echo "───────────────────────────────────────────────────────"
echo "  insights:       ${INS_COUNT} rows"
echo "  note_chunks:    ${NC_COUNT} rows"
echo "  observations:   ${OBS_COUNT} rows"
echo "═══════════════════════════════════════════════════════"
echo ""

# ─────────────────────────────────────────────────
# Step 5: Clean up temp files
# ─────────────────────────────────────────────────
log "Cleaning up temp files..."
for table in "${TARGET_TABLES[@]}"; do
  rm -f "/tmp/${table}.csv"
  docker exec "$SOURCE_CONTAINER" rm -f "/tmp/${table}.csv" 2>/dev/null || true
  docker exec "$TARGET_CONTAINER" rm -f "/tmp/${table}.csv" 2>/dev/null || true
done
log "Done."
