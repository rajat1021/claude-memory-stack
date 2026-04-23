#!/usr/bin/env python3
"""Ingest Claude Code session transcript into conversation_turns (L3).

Reads the session jsonl transcript, embeds new turns (user + assistant text),
inserts into Postgres. Idempotent via transcript_uuid UNIQUE constraint.
"""
import os
import sys
import json
import glob
from pathlib import Path

import psycopg2
from psycopg2.extras import execute_values
from sentence_transformers import SentenceTransformer

DB = dict(
    host=os.getenv("DB_HOST", "localhost"),
    port=os.getenv("DB_PORT", "5433"),
    dbname=os.getenv("DB_NAME", "claude_flow"),
    user=os.getenv("DB_USER", "claude"),
    password=os.getenv("DB_PASS", "claude-memory-stack"),
)
MODEL_NAME = "sentence-transformers/all-MiniLM-L6-v2"
MAX_CHARS = 8000  # truncate absurdly long turns


def find_transcript(session_id: str, cwd: str) -> Path | None:
    """Locate transcript jsonl for this session."""
    # Claude Code encodes cwd: /Users/x/y → -Users-x-y
    encoded = cwd.replace("/", "-")
    base = Path.home() / ".claude" / "projects" / encoded
    if not base.exists():
        # fallback: search all project dirs
        for p in (Path.home() / ".claude" / "projects").glob(f"*/{session_id}.jsonl"):
            return p
        return None
    direct = base / f"{session_id}.jsonl"
    return direct if direct.exists() else None


def extract_text(msg: dict) -> tuple[str, str, str] | None:
    """Return (role, text, uuid) or None if not ingestable."""
    t = msg.get("type")
    uuid = msg.get("uuid") or msg.get("id")
    if t == "user":
        m = msg.get("message", {})
        content = m.get("content")
        if isinstance(content, str):
            return ("user", content, uuid)
        if isinstance(content, list):
            parts = [c.get("text", "") for c in content if c.get("type") == "text"]
            text = "\n".join(p for p in parts if p)
            return ("user", text, uuid) if text else None
    elif t == "assistant":
        m = msg.get("message", {})
        content = m.get("content", [])
        if isinstance(content, list):
            parts = [c.get("text", "") for c in content if c.get("type") == "text"]
            text = "\n".join(p for p in parts if p)
            return ("assistant", text, uuid) if text else None
    return None


def main():
    # Claude Code passes JSON on stdin: {session_id, transcript_path, cwd, hook_event_name, ...}
    hook_input = {}
    if not sys.stdin.isatty():
        try:
            raw = sys.stdin.read()
            if raw.strip():
                hook_input = json.loads(raw)
        except json.JSONDecodeError:
            pass

    session_id = hook_input.get("session_id") or os.getenv("CLAUDE_SESSION_ID")
    cwd = hook_input.get("cwd") or os.getenv("CLAUDE_CWD") or os.getenv("CLAUDE_PROJECT_DIR") or os.getcwd()
    transcript_path = hook_input.get("transcript_path")

    if not session_id:
        print("no session_id", file=sys.stderr)
        return 0

    transcript = Path(transcript_path) if transcript_path and Path(transcript_path).exists() else find_transcript(session_id, cwd)
    if not transcript:
        print(f"no transcript for {session_id}", file=sys.stderr)
        return 0

    project = Path(cwd).name

    # parse jsonl, extract ingestable turns
    turns = []
    with open(transcript) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                msg = json.loads(line)
            except json.JSONDecodeError:
                continue
            extracted = extract_text(msg)
            if extracted:
                role, text, uuid = extracted
                if uuid and text:
                    turns.append((role, text[:MAX_CHARS], uuid))

    if not turns:
        return 0

    conn = psycopg2.connect(**DB)
    cur = conn.cursor()

    # filter already-ingested
    uuids = [t[2] for t in turns]
    cur.execute(
        "SELECT transcript_uuid FROM conversation_turns WHERE transcript_uuid = ANY(%s)",
        (uuids,),
    )
    seen = {row[0] for row in cur.fetchall()}
    new_turns = [t for t in turns if t[2] not in seen]

    if not new_turns:
        cur.close()
        conn.close()
        return 0

    # embed
    model = SentenceTransformer(MODEL_NAME)
    texts = [t[1] for t in new_turns]
    embeddings = model.encode(texts, show_progress_bar=False, normalize_embeddings=True)

    rows = [
        (session_id, project, cwd, role, text, emb.tolist(), uuid)
        for (role, text, uuid), emb in zip(new_turns, embeddings)
    ]
    execute_values(
        cur,
        """INSERT INTO conversation_turns
           (session_id, project, cwd, role, content, embedding, transcript_uuid)
           VALUES %s
           ON CONFLICT (transcript_uuid) DO NOTHING""",
        rows,
        template="(%s, %s, %s, %s, %s, %s::vector, %s)",
    )
    conn.commit()
    print(f"ingested {len(new_turns)} turns for {session_id}")
    cur.close()
    conn.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
