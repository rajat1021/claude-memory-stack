#!/usr/bin/env bash
# ─────────────────────────────────────────────────
# claude-memory-stack v1.0.0 | MIT License
# Author: Rajat Tanwar (@rajat1021)
# https://github.com/rajat1021/claude-memory-stack
# ─────────────────────────────────────────────────
# Export memorygraph nodes → RuVector patterns table
set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[migrate]${NC} $1"; }
warn() { echo -e "${YELLOW}[migrate]${NC} $1"; }
fail() { echo -e "${RED}[migrate]${NC} $1"; exit 1; }

TARGET_CONTAINER="claude-memory-stack-db"
TARGET_USER="claude"
TARGET_DB="claude_flow"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  memorygraph → RuVector patterns Migration"
echo "═══════════════════════════════════════════════════════"
echo ""

# ─────────────────────────────────────────────────
# Step 1: Find memorygraph SQLite databases
# ─────────────────────────────────────────────────
log "Searching for memorygraph databases..."

DB_FILES=()

# Global location
if [[ -f "$HOME/.claude/memory-graph.db" ]]; then
  DB_FILES+=("$HOME/.claude/memory-graph.db")
  log "  Found: ~/.claude/memory-graph.db"
fi

# Project-level locations
while IFS= read -r -d '' dbfile; do
  DB_FILES+=("$dbfile")
  log "  Found: $dbfile"
done < <(find "$HOME" -maxdepth 5 -name "memory-graph.db" -not -path "$HOME/.claude/memory-graph.db" -print0 2>/dev/null || true)

if [[ ${#DB_FILES[@]} -eq 0 ]]; then
  warn "No memorygraph databases found. Nothing to migrate."
  exit 0
fi

log "  ${#DB_FILES[@]} database(s) found"

# ─────────────────────────────────────────────────
# Step 2: Check target container
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
# Step 3: Extract and import entities + relations
# ─────────────────────────────────────────────────
TOTAL_ENTITIES=0
TOTAL_RELATIONS=0

for db in "${DB_FILES[@]}"; do
  log "Processing: $db"

  # Check sqlite3 is available
  command -v sqlite3 >/dev/null 2>&1 || fail "sqlite3 not found. Install: brew install sqlite3"

  # Extract entities as JSON
  entities_json=$(sqlite3 "$db" "SELECT json_group_array(json_object('name', name, 'type', entityType, 'observations', observations)) FROM entities;" 2>/dev/null || echo "[]")

  if [[ "$entities_json" == "[]" || -z "$entities_json" ]]; then
    warn "  No entities found in $db"
    continue
  fi

  # Extract relations as JSON
  relations_json=$(sqlite3 "$db" "SELECT json_group_array(json_object('from', \"from\", 'to', \"to\", 'type', relationType)) FROM relations;" 2>/dev/null || echo "[]")

  # Count entities
  entity_count=$(echo "$entities_json" | python3 -c "import sys,json; print(len(json.loads(sys.stdin.read())))" 2>/dev/null || echo "0")
  log "  Entities: $entity_count"

  # Process each entity
  echo "$entities_json" | python3 -c "
import sys, json, subprocess

entities = json.loads(sys.stdin.read())
relations_raw = '''$relations_json'''
relations = json.loads(relations_raw) if relations_raw and relations_raw != '[]' else []

for entity in entities:
    name = entity.get('name', '').replace(\"'\", \"''\")
    etype = entity.get('type', 'unknown').replace(\"'\", \"''\")

    # Parse observations — stored as JSON array string in SQLite
    obs_raw = entity.get('observations', '[]')
    if isinstance(obs_raw, str):
        try:
            obs_list = json.loads(obs_raw)
        except json.JSONDecodeError:
            obs_list = [obs_raw]
    else:
        obs_list = obs_raw if isinstance(obs_raw, list) else [str(obs_raw)]

    description = '; '.join(str(o) for o in obs_list).replace(\"'\", \"''\")

    # Find related relations for this entity
    entity_relations = [r for r in relations if r.get('from') == entity.get('name') or r.get('to') == entity.get('name')]

    metadata = json.dumps({
        'source': 'memorygraph',
        'source_db': '$db',
        'observations': obs_list,
        'relations': entity_relations
    }).replace(\"'\", \"''\")

    sql = f\"\"\"INSERT INTO claude_flow.patterns (name, description, pattern_type, confidence, metadata)
VALUES ('{name}', '{description}', '{etype}', 0.5, '{metadata}'::jsonb)
ON CONFLICT DO NOTHING;\"\"\"

    print(sql)
" | docker exec -i "$TARGET_CONTAINER" psql -U "$TARGET_USER" -d "$TARGET_DB" >/dev/null 2>&1

  # Count relations
  relation_count=$(echo "$relations_json" | python3 -c "import sys,json; print(len(json.loads(sys.stdin.read())))" 2>/dev/null || echo "0")

  TOTAL_ENTITIES=$((TOTAL_ENTITIES + entity_count))
  TOTAL_RELATIONS=$((TOTAL_RELATIONS + relation_count))
  log "  Relations preserved: $relation_count"
done

# ─────────────────────────────────────────────────
# Step 4: Summary
# ─────────────────────────────────────────────────
PATTERN_COUNT=$(docker exec "$TARGET_CONTAINER" psql -U "$TARGET_USER" -d "$TARGET_DB" -tAc \
  "SELECT count(*) FROM claude_flow.patterns WHERE metadata->>'source' = 'memorygraph'" 2>/dev/null || echo "0")

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  memorygraph Migration Summary"
echo "───────────────────────────────────────────────────────"
echo "  Databases processed:  ${#DB_FILES[@]}"
echo "  Entities imported:    $PATTERN_COUNT (in patterns table)"
echo "  Relations preserved:  $TOTAL_RELATIONS (in pattern metadata)"
echo "═══════════════════════════════════════════════════════"
echo ""
log "Done."
