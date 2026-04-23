#!/usr/bin/env bash
# SessionEnd hook — nudge to run /reflect if learnings queue has items.

QUEUE_READER="${QUEUE_READER:-$HOME/.claude/plugins/claude-reflect/scripts/read_queue.py}"
[ -f "$QUEUE_READER" ] || exit 0

COUNT=$(python3 "$QUEUE_READER" 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d) if isinstance(d,list) else 0)" 2>/dev/null || echo 0)

[ "$COUNT" -gt 0 ] && echo "⚠️  $COUNT learning(s) queued — run /reflect next session to process"
exit 0
