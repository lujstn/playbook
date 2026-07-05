---
name: model-rule
description: Always-on model selection doctrine; never entered or exited, never inferred off. Sonnet executes; Opus plans, reviews, and thinks hard; bump up a tier when stuck. Propagates across every nesting level via the session overlay and explicit model params on each dispatch. This skill is the detailed reference; the rule itself is stated in the overlay for every agent and subagent.
---

This is always-live doctrine, not a mode. It is carried in the session overlay and the SubagentStart overlay so every agent, subagent, and workflow stage operates under it automatically. Nothing here is turned on or off.

### The rule

Execute on Sonnet. Plan, review, and think hard on Opus. Bump up a tier when stuck.

### Risk-profile classification

Classify by the task's risk profile, not the agent's role name or the orchestration framework's vocabulary.

1. **Mechanical, bounded, and cheaply verifiable.** Lookups, retrieval, deterministic transforms, file scans, formatting passes, fetching a known artefact. Errors are loud and locally recoverable. Use the lightweight tier at low reasoning effort.

2. **Bulk implementation under a locked specification, with a reviewer above.** The design is settled and the contract is written elsewhere; the agent translates spec to code. A reviewer running on the parent model sits above and will catch slippage. Use Sonnet, with reasoning effort matched to the density of the work. If there is no reviewer above, the task does not qualify for this profile; treat it as profile 3.

3. **Judgement, validation, design, audit, contract authorship, or any task whose errors propagate silently into other agents' work.** This covers anyone signing off work, anyone authoring an interface or contract that downstream agents depend on, and anyone nominated as a check of last resort. Use Opus; never downgrade.

When a task could be read two ways, classify by what happens when the agent is wrong: a loud, locally fixable error can run on a lighter tier; a quiet error that propagates into other agents keeps the flagship.

### Propagation

The real levers, in resolution order: per-spawn `model` param on an `Agent` dispatch > `model:` field in subagent or skill frontmatter > `model` on each `agent()` call inside a workflow stage > main model.

These are reliable on plain Agent subagents and workflow stages. For agent-team peers (hackathon mode), per-peer model selection is limited: `CLAUDE_CODE_SUBAGENT_MODEL` governs all team members globally, so the Sonnet/Opus split is weakest there and should not be relied upon.

`CLAUDE_CODE_SUBAGENT_MODEL`, if set in the environment, overrides all of the above for every subagent and agent-team peer simultaneously. Because it is one model for everything, it cannot express a Sonnet-for-execution / Opus-for-review split; it flattens the distinction. This rule assumes it is unset (or set to `inherit`); if a user has it set, Playbook's per-dispatch model choices are silently overridden.

Enforce the rule at every level by setting `model:` explicitly on every `Agent` dispatch, in subagent/skill frontmatter, and on each `agent()` workflow stage you author. For GSD, use `model_overrides` in the project config: `model_overrides.gsd-executor: sonnet`, `model_overrides.gsd-planner: opus`, `model_overrides.gsd-verifier: opus`.

Explicit params are the source of truth; inheritance is the fallback of last resort.

### Visibility

Announce every downshift on the spawn itself, before the agent runs. Example: 🪙 **Playbook** `sonnet` *bulk implementation under locked spec*.

Only downshifts get a marker; do not announce when a spawn stays at the same tier as the parent.
