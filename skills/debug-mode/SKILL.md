---
name: debug-mode
description: Use when the user says the literal token `[debug]`. Enters a strict debugging workflow that compacts history, runs a read-summarise-diagnose-confirm cycle per file, requires user confirmation before every code modification, and uses compaction checkpoints. Remain in this mode until the user says `[close]`, `[end]`, `[exit]`, or `[done]`, or the bug is resolved.
---

When the user says "[debug]", switch to the following strict workflow. Remain in this mode until the user says `[close]`, `[end]`, `[exit]`, or `[done]`, or the bug is resolved.

### On entry
1. Print "👾 Entered Debug Mode"
2. Compact/compress chat history (best-effort attempt to avoid context bias) and lock in these instructions
3. Ask the user to describe the bug and identify the file(s) involved

### For EVERY file you need to modify
1. Read the full file (or relevant section for large files)
2. Summarise what the relevant code currently does in plain English
3. State your diagnosis: what specific line(s) cause the bug and why
4. STOP and wait for user confirmation before writing any code

### After confirmation
5. Write the minimal fix addressing the root cause from step 3
6. Re-read the modified file and confirm coherence
7. For visual changes: describe the expected before and after rendering and name the specific properties involved

### Compaction checkpoints
- If the conversation exceeds ~15 back-and-forth exchanges while in debug mode, proactively run /compact before continuing
- After compaction, restate the current bug, diagnosis, and progress so nothing is lost

### Rules
- NEVER skip the read, summarise, diagnose, confirm cycle
- NEVER modify a function or component you haven't read in full
- If you catch yourself writing code before completing steps 1-3, stop, say "restarting process", and go back to step 1
- One file at a time. Do not batch changes across multiple files without a confirm step for each.

### Exit
- When the bug is resolved or the user says `[close]`, `[end]`, `[exit]`, or `[done]`, print "👾 Exited Debug Mode" and return to normal operation.
