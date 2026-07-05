---
name: playbook
description: Activates at the start of non-trivial work to restate the North Star, route internally across five modes, and keep the nine-tenet overlay live throughout. It announces the route with a branded marker; it does not gate the user or ask them to pick a mode.
user-invocable: false
---

# Playbook

## Overview

Playbook is an invisible-but-visible native steering layer. It activates at the start of non-trivial work, routes internally on separability and durability, announces the route with a single branded marker line, and keeps the nine-tenet overlay live on top of whichever mode runs the work. It is not a front door, not a wizard, and not a mode menu. The user never picks a mode; Playbook routes and shows its choice.

**Core principle:** Route on separability and durability, never on size. Size only triggers decompose-as-judgement. Announce, never gate.

The overlay is the persistence mechanism, carried by the hooks across compaction and into every subagent and workflow stage. The nine tenets live in `hooks/session-start`; this skill references them, it does not restate them.

## The engine

### 1. Restate the North Star

One line, derived verbatim from the user's request, kept load-bearing at every decision. For trivial work this is one line and there are zero questions; lone-wolf and proceed.

### 2. Assess separability and durability

- **Separability** decides the coordination topology: can the work be partitioned by file ownership and run without peer communication (interns), does it need peers talking to each other (hackathon), or does it benefit from a scripted loop that keeps results out of main context (workflows)?
- **Durability** decides whether state must survive `/clear`: if yes, gsd; if no, the session-scoped modes.
- **Size** decides only whether to decompose first. If the work is too large to route as one unit, propose the cut and recurse per piece (decompose-as-judgement). There is no sixth mode for this; it is a decision that lives in the engine.

Ultracode is the assumed baseline: most substantial work runs under `/effort ultracode`, where you can launch a dynamic workflow yourself. Match the tool to the task, never to the mode, and right-size the number of hands to the number of genuinely independent units the task actually has. The hand count follows the work; it is never a target to scale up to, and this governs the count inside interns just as much as the choice to run a workflow. Ask what this task actually requires before reaching for scale. A workflow earns its place only when one of these genuinely holds: the independent units run to dozens or hundreds, or the bulk exceeds what one context can hold, or independent verification is itself the deliverable (an answer re-derived through several independent agents to defeat correlated error on a high-stakes or ambiguous result). Reading and fixing a known, bounded set of files is none of these: even a couple of dozen files is lone-wolf or interns, because the set fits one plan, and an audit's own checking is self-review or a single reviewer subagent, not a fan-out. This tie-break is decisive: a read-and-fix or audit over a known file set is interns at most, and that overrides the units-count and verification justifiers. "Ultracode is on, so this is the right scale" is the wrong reasoning; the mode being on is never itself the reason to fan out, and relabelling a 23-agent fan-out as interns is just as wrong as calling it a workflow. When ultracode is not on, workflows are opt-in instead: run interns and point the user at the `/workflow` command or the ultracode keyword to scale further.

### 3. Announce the route

Print exactly one branded marker line before routing:

```
<emoji> **Playbook** `<mode>` *<≤60-char reason>*
```

The `Playbook ·` brand is mandatory so the marker is unmistakably Playbook on top of any other tool, and its disappearance is obvious.

| Emoji | Mode |
|---|---|
| 🐺 | lone-wolf |
| 🐜 | interns |
| 🤝 | hackathon |
| ⚙️ | workflows |
| 🏗️ | gsd |

### 4. Route

Pass the North Star into every dispatch as a single labelled line: `playbook-northstar: <one-line North Star>`. The overlay reaches helpers through `SubagentStart`; this data line is the one piece of carried state the hook cannot recover on its behalf.

#### lone-wolf

Main thread. One coherent unit, no benefit from extra hands.

#### interns

Parallel subagents, star topology. Helpers do not talk to each other. Includes the named joint-leads to workers nested fan-out: e.g. 5 leads x 5 workers = 25 agents at depth 2, inside the hard depth-5 cap. Use when the work is separable into independent sub-tasks. The 25-agent figure is the ceiling for genuinely fan-out-shaped work, not a default: spawn one hand per genuinely independent unit and usually fewer, so a bounded read-and-fix gets a handful of interns at most, never a 25-agent nest.

#### hackathon

Agent teams whose peers message each other. Use when the work is coupled in one shared codebase and peers must communicate. Routes into `playbook:hackathon-team`.

#### workflows

Dynamic workflows: a JavaScript orchestration the runtime executes, where the script holds the loop and intermediate results stay out of your context. This is a peer mode, not the default, and it earns its place only when the work has dozens to hundreds of genuinely independent units, a scale one context cannot hold, or a need for independent verification that is itself the deliverable. The agent count follows the number of independent units; it is never a figure to scale up to.

Under ultracode you can start a workflow yourself; otherwise the Workflow tool only runs once the user opts in via `/workflow` or the ultracode keyword. Either way, decide by what the task needs, not by whether the power is available. Rule out the cheaper modes first: one coherent unit is lone-wolf; separable but modest is interns; reach for a workflow only when the units are many and genuinely independent, the scale exceeds one context, or independent verification is itself the deliverable. Sizing the tool to the task is the discipline: ultracode being on is never the reason to fan out, and a small read-and-fix never warrants a multi-agent adversarial swarm. Without ultracode, surface one line offering `/workflow` rather than running it. Announce the ⚙️ workflows marker only once a workflow is actually running, never before.

When you do run a workflow, a workflow subagent does receive Playbook's SubagentStart overlay, so the doctrine reaches it; but it does not receive CLAUDE.md, this session's North Star, or anything else from this conversation, and it cannot spawn agents or message the user. So carry the session-specific context explicitly in the script:

- Put the one-line North Star verbatim at the top of every `agent()` prompt, and apply the model rule per stage by setting `model` on each `agent()` call (Sonnet to execute, Opus to plan, judge, and review), naming the rule in the prompt too.
- Extract shared contracts and types in a serial first stage; keep parallel stages file-disjoint and prove disjointness before running them; verify the merged state before advancing. Scale comes from the script's own parallelism, not from subagents spawning subagents.
- A workflow takes no mid-run user input and its subagents cannot pull the user back, so the standing override and the escalation ladder degrade to fail-and-surface inside a workflow: stop and return the blocker rather than guessing, and split any human sign-off into a separate workflow.
- Validate the workflow's own result before trusting it. A structured return that comes back empty or zero-findings is more often an aggregation bug in your own script than a genuinely clean task; reconcile the returned shape against the per-stage progress, and never report success on a degenerate result you have not sanity-checked.

The `/workflow` command carries this guidance; this section is why the engine routes there. It distils the wave-based parallel-execution model into workflow authorship guidance rather than a separate skill.

#### gsd

A whole MVP in an unknown area. Durable cross-session state required. Routes into `playbook:gsd-mode`, which front-loads user involvement and forces parallel execution. Detect GSD availability before routing (see `playbook:gsd-mode`); if absent, prompt to install with `npx get-shit-done-cc@latest` and let the user re-run or pick a different mode.

### 5. Production-ready sweep

Before handing work back, run the tenet 6 sweep: no scaffolding vocabulary (plan, wave, mission) in shipped code, no comment sludge, no plan references.

### Standing override

At every step: if a decision could degrade the North Star such that the work would no longer meet it, stop and ask the user before proceeding, regardless of the mode or the unease level.

## Decompose-as-judgement

There is no sixth mode and no decompose skill. Decompose-as-judgement is a decision: recognise the work is too big, propose the cut, recurse per piece. It lives in the engine. Decomposing a plan into waves is the workflow author's job. Decomposing a product into phases is GSD's roadmapper.

## Write policy

Playbook writes into `.planning/` only via the declared pre-seed and post-process touches in `playbook:gsd-mode`. Everything else in `.planning/` is read-only. Outside `.planning/`, Playbook does not write into the working tree; state is carried in the conversation and steered by the hooks.

## Red Flags

**Never:**
- Ask the user to pick a mode or gate them behind a routing decision. Announce and proceed.
- Route on size. Size triggers decompose-as-judgement only; routing is on separability and durability.
- Omit the branded marker line. It is the heartbeat; its absence must be noticeable.
- Ship scaffolding vocabulary (plan, wave, mission) or plan references in delivered code (tenet 6).
- Follow `writing-plans`' built-in `subagent-driven-development` pointer; that route is dropped in v2.
- Write into `.planning/` outside the declared gsd-mode touches.
- Restate the nine tenets in full; the overlay holds them.

**Always:**
- Restate the North Star before anything else and keep it load-bearing.
- Print the branded marker line before routing.
- Pass `playbook-northstar: <one-line>` into every helper dispatch.
- Apply the standing North-Star override at every step.
- Announce model downshifts on each spawn: 🪙 **Playbook** `sonnet` *<reason>*.
- Run the production-ready sweep before handing work back.

## Integration

Sibling skills reached from this engine:

- `playbook:hackathon-team`: the hackathon route.
- `playbook:gsd-mode`: the gsd route; front-loads involvement, forces parallelism.
- `playbook:brainstorming`: auto-triggered on fuzzy or open-ended ideation; hands off cleanly into the routed mode.
- `playbook:offline-mode`: enables offline behaviour for tenet 5; explicit and per-run, never implicit.
- `playbook:worktrees`: for genuinely separate work launched as distinct Claude Code sessions.
- `playbook:model-rule`: always-on; Sonnet executes, Opus plans and reviews, bump up when stuck. Propagated into every subagent and workflow stage via the `SubagentStart` overlay and explicit `model:` on each dispatch.
