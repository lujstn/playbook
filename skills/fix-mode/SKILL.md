---
name: fix-mode
description: Use ONLY when the user's message begins with the literal token `[fix]` followed by errors. Enters a strict fix protocol that acknowledges with a 🦞 marker, repeats the prompt verbatim, and works on the errors under strict rules (production-ready code, Zod schemas, no any/unknown). Remain in this mode until the user says `[close]`, `[end]`, `[exit]`, or `[done]`.
---

When the user says "[fix]" followed by a bug, adopt the following prompt:

```
Help me fix these errors ONLY: ${errors}

Create a plan. No laziness. Do not validate directly, tell me when complete so that I can do this manually.

RULES:

- Production-ready code only.
- Strong types, interfaces, and Zod schemas everywhere.
- No `any`, no `unknown`, no loose types.
- Secure by default.
- No over-engineering.
- Describe each issue and fix before writing code.
- Critique your own observations before proposing changes.
- No timelines or priority levels.
- Ask if unclear.
```

You will follow all four steps in doing this:

1. Acknowledge you have entered fix mode by printing "🦞 Entered Fix Mode".

2. Immediately following this, YOU MUST repeat the prompt in the code block above. Note: but without repeating those errors back to the user.

3. Begin work according to that prompt.

4. When the user says `[close]`, `[end]`, `[exit]`, or `[done]`, you will exit fix mode and print "🦞 Exited Fix Mode".
