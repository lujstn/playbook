---
name: model-rule
description: Always-on model selection doctrine; never entered or exited, never inferred off. Sonnet builds and checks; Opus plans and judges; bump up a tier when stuck. Propagates across every nesting level via the session overlay and explicit model params on each dispatch. This skill is the detailed reference; the rule itself is stated in the overlay for every agent and subagent.
user-invocable: false
---

This is always-live doctrine, not a mode. It is carried in the session overlay and the SubagentStart overlay so every agent, subagent, and workflow stage operates under it automatically. Nothing here is turned on or off.

### The rule

Sonnet builds and checks. Opus plans and judges. Bump up a tier when stuck.

### Risk-profile classification

Classify by the task's risk profile, not the agent's role name or the orchestration framework's vocabulary.

1. **Mechanical, bounded, and cheaply verifiable.** Lookups, retrieval, deterministic transforms, file scans, formatting passes, fetching a known artefact. Errors are loud and locally recoverable. Use the lightweight tier at low reasoning effort.

2. **Bulk implementation under a locked specification.** The design is settled and the contract is written elsewhere; the agent translates spec to code, and checks its own build against the spec. Use Sonnet, with reasoning effort matched to the density of the work.

3. **Judgement, validation, design, audit, contract authorship, or any task whose errors propagate silently into other agents' work.** This covers anyone signing off work and anyone authoring an interface or contract that downstream agents depend on. Use Opus.

No agent exists only to watch another. Checking is part of building (Sonnet) or part of a judgement the work needed anyway (Opus); a reviewer added purely to supervise a builder is cost without a purpose.

When a task could be read two ways, classify by what happens when the agent is wrong: a loud, locally fixable error can run on a lighter tier; a quiet error that propagates into other agents keeps the flagship.

### Propagation

The real levers, in resolution order: per-spawn `model` param on an `Agent` dispatch > `model:` field in subagent or skill frontmatter > `model` on each `agent()` call inside a workflow stage > main model.

These hold for plain Agent subagents, workflow stages and agent-team teammates alike: a model passed when the agent is spawned wins.

`CLAUDE_CODE_SUBAGENT_MODEL` is only a default, for agents spawned without a model: a model passed at spawn, or a `model` field in the agent's definition, takes precedence over it (Claude Code 2.1.251 and later). Only `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` puts every subagent, teammate and workflow agent on one model, which flattens the Sonnet/Opus split; this rule assumes it is unset.

Enforce the rule at every level by setting `model:` explicitly on every `Agent` dispatch, in subagent/skill frontmatter, and on each `agent()` workflow stage you author. For GSD, use `model_overrides` in the project config: `model_overrides.gsd-executor: sonnet`, `model_overrides.gsd-planner: opus`, `model_overrides.gsd-verifier: opus`.

Explicit params are the source of truth; inheritance is the fallback of last resort.

### Visibility

Print no model marker of your own. The dispatch guard shows the user one line per dispatch, with its description and model, for example `📚 Playbook dispatch: build the export lane · sonnet`.
