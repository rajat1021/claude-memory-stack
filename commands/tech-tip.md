<!-- claude-memory-stack v1.0.0 | Rajat Tanwar (@rajat1021) -->
---
name: tech-tip
description: Capture a technology-specific tip or gotcha to the shared tech-tips library
arguments:
  - name: technology
    description: Technology name (e.g., python, docker-infra, react-typescript)
    required: true
---

# Tech Tip: $ARGUMENTS.technology

## Steps

1. **Ask for the tip content**
   - Ask the user: "What's the tip or gotcha you want to capture?"
   - Wait for their response

2. **Format the tip**
   - Format as a markdown bullet point
   - Include date: `(discovered: YYYY-MM-DD)`
   - Keep it concise — one line if possible

3. **Append to tech-tips file**
   - Target file: `~/.claude/memory-bank/tech-tips/$ARGUMENTS.technology.md`
   - If file doesn't exist, create it with header:
     ```
     # Tech Tips: $ARGUMENTS.technology
     ```
   - Append the formatted tip as a bullet point

4. **Confirm**
   - Print: "Tip saved to ~/.claude/memory-bank/tech-tips/$ARGUMENTS.technology.md"
   - Show the tip that was added
