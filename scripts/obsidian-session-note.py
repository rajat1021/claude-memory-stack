#!/usr/bin/env python3
"""SessionEnd hook: append session summary to Obsidian vault.

Reads hook JSON from stdin (contains transcript_path, cwd).
Appends dated note to: <VAULT>/projects/<project>/YYYY-MM-DD.md
"""
import json
import os
import sys
from datetime import datetime
from pathlib import Path

VAULT = Path(os.environ.get(
    "OBSIDIAN_VAULT",
    Path.home() / "Documents" / "Obsidian" / "vault",
))
if not VAULT.exists():
    # Opt-in: only run if the user has set OBSIDIAN_VAULT or created the default dir
    sys.exit(0)


def main():
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return 0

    transcript_path = payload.get("transcript_path")
    cwd = payload.get("cwd") or os.getcwd()
    project = Path(cwd).name

    if not transcript_path or not Path(transcript_path).exists():
        return 0

    user_msgs = []
    last_assistant = ""
    with open(transcript_path) as f:
        for line in f:
            try:
                entry = json.loads(line)
            except Exception:
                continue
            msg = entry.get("message") or {}
            role = msg.get("role") or entry.get("type")
            content = msg.get("content")
            text = ""
            if isinstance(content, str):
                text = content
            elif isinstance(content, list):
                text = "\n".join(
                    b.get("text", "") for b in content if b.get("type") == "text"
                )
            if not text.strip():
                continue
            if role == "user" and not text.startswith("<"):
                user_msgs.append(text.strip())
            elif role == "assistant":
                last_assistant = text.strip()

    if not user_msgs:
        return 0

    date = datetime.now().strftime("%Y-%m-%d")
    time = datetime.now().strftime("%H:%M")
    out_dir = VAULT / "projects" / project
    out_dir.mkdir(parents=True, exist_ok=True)
    out_file = out_dir / f"{date}.md"

    new_file = not out_file.exists()
    with open(out_file, "a") as f:
        if new_file:
            f.write(f"---\ndate: {date}\nproject: {project}\ntags: [session-log]\n---\n\n")
            f.write(f"# {project} — {date}\n\n")
        f.write(f"## Session {time}\n\n")
        f.write("### Asks\n")
        for m in user_msgs:
            snippet = m.splitlines()[0][:200]
            f.write(f"- {snippet}\n")
        if last_assistant:
            f.write(f"\n### Last response\n{last_assistant[:800]}\n")
        f.write("\n---\n\n")
    return 0


if __name__ == "__main__":
    sys.exit(main() or 0)
