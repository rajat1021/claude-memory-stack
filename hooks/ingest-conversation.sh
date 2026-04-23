#!/usr/bin/env bash
# Stop hook — ingest conversation turns into L3. Reads stdin JSON from Claude Code.
# Fires in background, never blocks.

INPUT="$(cat)"  # JSON with session_id, transcript_path, cwd, hook_event_name
echo "$INPUT" | nohup python3 ~/.claude/scripts/ingest-conversation.py \
  >> ~/.claude/logs/conversation-ingest.log 2>&1 &

exit 0
