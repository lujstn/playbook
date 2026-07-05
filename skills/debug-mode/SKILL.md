---
name: debug-mode
description: Triggered by /debug (keep [debug] as a courtesy alias). Enters a strict read-summarise-diagnose-confirm cycle under a 👾 **Playbook** `debug` marker: reads each file in full before any edit, waits for explicit user confirmation before writing, works one file at a time. Stays active until the bug is resolved, or on /close, or the courtesy aliases [close]/[end]/[exit]/[done].
---

On `/debug` or the courtesy alias `[debug]`:

1. Print 👾 **Playbook** `debug`.
2. Ask the user to describe the bug and identify the file(s) involved.
3. Follow the cycle below for every file until the bug is resolved.

Context is managed by Playbook's hooks: auto-compact is seamless and the session continues; the re-anchor after compaction restores the current bug, diagnosis, and progress automatically. Debug mode does not manage context itself and does not issue `/compact`.

### Cycle: for every file you need to touch

1. Read the full file (or the relevant section for large files).
2. Summarise what the relevant code currently does in plain English.
3. State your diagnosis: which specific lines cause the bug and why.
4. Stop and wait for explicit user confirmation before writing any code.

### After confirmation

5. Write the minimal fix addressing the root cause from step 3.
6. Re-read the modified file and confirm coherence.
7. For visual changes: describe the expected before and after rendering, and name the specific properties changed.

### Rules

- Never skip the read, summarise, diagnose, confirm cycle.
- Never modify a function or component you have not read in full.
- If you catch yourself writing code before completing steps 1 to 3, stop, say "restarting process", and go back to step 1.
- One file at a time; do not batch changes across multiple files without a confirm step for each.

### Exit

When the bug is resolved or the user types `/close`, `[close]`, `[end]`, `[exit]`, or `[done]`, print 👾 **Playbook** `debug` *exited* and return to normal operation.
