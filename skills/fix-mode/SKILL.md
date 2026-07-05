---
name: fix-mode
description: Triggered by /fix (keep [fix] as a courtesy alias). Enters a strict fix protocol under a 🦞 **Playbook** `fix` marker, then works through the provided errors under production-ready rules: strongly typed for the language in use, validated at every boundary, secure by default. Stays active until natural completion, /close, or the courtesy aliases [close]/[end]/[exit]/[done].
---

On `/fix` or the courtesy alias `[fix]`:

1. Print 🦞 **Playbook** `fix`.
2. Restate the rules below so they are visible in context.
3. Work through every error under those rules.
4. On natural completion or on `/close`, `[close]`, `[end]`, `[exit]`, or `[done]`, print 🦞 **Playbook** `fix` *exited* and return to normal operation.

### Rules

- Production-ready code only: no stubs, no TODO placeholders, no scaffolding.
- Strongly typed for the language in use; validated at every boundary; no loose or weakly typed escapes.
- Secure by default.
- No over-engineering.
- Describe each issue and critique your own diagnosis before writing any code.
- Ask if the problem statement is unclear before proceeding.
- Do not validate directly; tell the user when complete so they can run validation themselves.
- No timelines or priority levels.
