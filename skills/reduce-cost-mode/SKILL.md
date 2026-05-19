---
name: reduce-cost-mode
description: "Use ONLY when the user types the literal token `[budget]`. Applies session-scoped cost-saving model selection rules: lighter tiers and lower reasoning effort for low-risk work, parent model preserved for judgment work. Do NOT activate from memory, prior conversations, or keyword inference elsewhere. Exits on `[close]`, `[end]`, `[exit]`, or `[done]`."
---

Cost-saving model selection is OPT-IN and SESSION-SCOPED. It is never inferred from memory, from a project's past patterns, from the wording of an agent's role, or from any other signal. Outside this mode, every spawned agent or subagent must inherit the parent session's model and reasoning effort by omitting those parameters on the spawn call.

The failure this mode corrects: treating heuristics like "smaller model for implementers, flagship for reviewers" as a settled project-wide rule. They are not. They are a cost trade-off applied only while this mode is explicitly active.

### Vocabulary

This skill uses provider-neutral terms so it works whether spawns are routed through Claude, Codex, or any other provider. The active provider configuration maps each term to a concrete model or setting.

- **Lightweight tier.** The cheapest, fastest capable model in the provider's lineup. Examples: Claude Haiku, Codex gpt-5-mini.
- **Mid tier.** The default workhorse. Examples: Claude Sonnet, Codex GPT-5.5.
- **Flagship tier.** The most capable model. Examples: Claude Opus, Codex GPT-5.5 at high reasoning effort.
- **Reasoning effort.** An orthogonal lever exposed by most providers (Claude thinking budget, Codex `reasoning_effort`, and equivalents). It can be lowered for mechanical work and raised for judgment work independently of the tier choice.

"Parent model" means the model and reasoning effort currently running this session. Default behaviour, both outside and inside budget mode, is to inherit it by omitting the parameter on spawn.

### Entry

The user enters the mode by typing `[budget]`. On entry:

1. Print "🪙 Entered Reduce Cost Mode".
2. Restate the rules below verbatim.
3. Wait for the user to confirm before spawning the next agent or team.

### Rules while active

Decide tier and effort from the **task's risk profile**, never from the agent's role name or the orchestration framework's vocabulary. Three profiles cover almost everything.

1. **Mechanical, bounded, and cheaply verifiable.** Lookups, retrieval, deterministic transforms, file scans, formatting passes, fetching a known artefact. Errors are loud and locally recoverable. Spawn at the lightweight tier with low reasoning effort.

2. **Bulk implementation under a locked specification, with a reviewer above.** The design is settled, the contract is written elsewhere, and the agent is translating spec to code. A reviewer or coordinator running on the parent model sits above and will catch slippage. Spawn at the mid tier and choose reasoning effort to match the density of the work. If there is no reviewer above, the task does not qualify for this profile; treat it as profile three.

3. **Judgment, validation, design, audit, contract authorship, or any task whose errors propagate silently into other agents' work.** This includes anyone signing off work, anyone authoring an interface or contract that downstream agents depend on, and anyone the orchestrator nominates as a check of last resort. Inherit the parent's tier and effort by omitting both parameters. Never downgrade.

If a task could be read two ways, classify by what happens when the agent is wrong. A wrong answer that is loud and locally fixable is safe to downgrade. A wrong answer that is quiet and propagates keeps parent.

Announce the chosen tier, the chosen reasoning effort, and a one-phrase reason on every spawn while the mode is active.

### Exit

The user exits by typing `[close]`, `[end]`, `[exit]`, or `[done]`. On exit, print "🪙 Exited Reduce Cost Mode" and return to default parent inheritance for any subsequent spawns.

### Anti-patterns

- Auto-entering the mode because a project's memory store or a prior conversation mentions cost reduction. Entry is user-initiated only.
- Reading a memory hook like "smaller model for implementers, flagship for reviewers" as an always-on rule. That phrase only binds while this mode is active; otherwise it is archival context, not guidance.
- Downgrading because an agent's title sounds "implementation-y" or "junior". Classification is by the risk profile of the task itself, not the agent's name in the orchestration framework.
- Conflating tier and effort. They are independent levers. A lightweight tier at high effort is a legitimate combination for a careful but cheap pass. A flagship tier at low effort is sometimes the right call when you want breadth of judgment without long deliberation.
