---
name: fix-mode
description: Triggered by /fix or /pb-fix (keep [fix] as a courtesy alias). Enters a strict fix protocol under a 🦞 Playbook · fix marker, then works through the provided errors under production-ready rules: strong types, Zod schemas, no any/unknown, secure by default. Stays active until natural completion, /close, /pb-close, or the courtesy aliases [close]/[end]/[exit]/[done].
---

On `/fix`, `/pb-fix`, or the courtesy alias `[fix]`:

1. Print `🦞 Playbook · fix`.
2. Restate the rules below so they are visible in context.
3. Work through every error under those rules.
4. On natural completion or on `/close`, `/pb-close`, `[close]`, `[end]`, `[exit]`, or `[done]`, print `🦞 Playbook · fix: exited` and return to normal operation.

### Rules

- Production-ready code only: no stubs, no TODO placeholders, no scaffolding.
- Strong types, interfaces, and Zod schemas everywhere.
- No `any`, no `unknown`, no loose types.
- Secure by default.
- No over-engineering.
- Describe each issue and critique your own diagnosis before writing any code.
- Ask if the problem statement is unclear before proceeding.
- Do not validate directly; tell the user when complete so they can run validation themselves.
- No timelines or priority levels.
