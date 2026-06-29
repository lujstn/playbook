---
name: playbook
description: Activates at the start of non-trivial work to restate the North Star, route internally across five modes, and keep the nine-tenet overlay live throughout. It announces the route with a branded marker; it does not gate the user or ask them to pick a mode.
---

# Playbook

## Overview

Playbook is an invisible-but-visible native steering layer. It activates at the start of non-trivial work, routes internally on separability and durability, announces the route with a single branded marker line, and keeps the nine-tenet overlay live on top of whichever mode runs the work. It is not a front door, not a wizard, and not a mode menu. The user never picks a mode; Playbook routes and shows its choice.

**Core principle:** Route on separability and durability, never on size. Size only triggers decompose-as-judgement. Announce, never gate.

The overlay is the persistence mechanism, carried by the hooks across compaction and into every subagent and workflow stage. The nine tenets live in `hooks/session-start`; this skill references them, it does not restate them.

## The engine

### 1. Restate the North Star

One line, derived verbatim from the user's request, kept load-bearing at every decision. For trivial work this is one line and there are zero questions; lone-wolf and proceed.

State your context window once as a single line of the form `playbook-window: <integer>` so the hooks can read it.

### 2. Assess separability and durability

- **Separability** decides the coordination topology: can the work be partitioned by file ownership and run without peer communication (interns), does it need peers talking to each other (hackathon), or does it benefit from a scripted loop that keeps results out of main context (workflows)?
- **Durability** decides whether state must survive `/clear`: if yes, gsd; if no, the session-scoped modes.
- **Size** decides only whether to decompose first. If the work is too large to route as one unit, propose the cut and recurse per piece (decompose-as-judgement). There is no sixth mode for this; it is a decision that lives in the engine.

### 3. The ultracode nudge

If substantive separable work is starting and `/effort ultracode` is not set, surface one short non-blocking line: "not in ultracode mode; want me to set it before planning?" Do not repeat it. Never gate on the answer; proceed either way.

### 4. Announce the route

Print exactly one branded marker line before routing:

```
<emoji> Playbook · <mode>: <≤60-char reason>
```

The `Playbook ·` brand is mandatory so the marker is unmistakably Playbook on top of any other tool, and its disappearance is obvious.

| Emoji | Mode |
|---|---|
| 🐺 | lone-wolf |
| 🐜 | interns |
| 🤝 | hackathon |
| ⚙️ | workflows |
| 🏗️ | gsd |

### 5. Route

Pass the North Star into every dispatch as a single labelled line: `playbook-northstar: <one-line North Star>`. The overlay reaches helpers through `SubagentStart`; this data line is the one piece of carried state the hook cannot recover on its behalf.

#### lone-wolf

Main thread. One coherent unit, no benefit from extra hands.

#### interns

Parallel subagents, star topology. Helpers do not talk to each other. Includes the named joint-leads to workers nested fan-out: e.g. 5 leads x 5 workers = 25 agents at depth 2, inside the hard depth-5 cap. Use when the work is separable into independent sub-tasks.

#### hackathon

Agent teams whose peers message each other. Use when the work is coupled in one shared codebase and peers must communicate. Routes into `playbook:hackathon-team`.

#### workflows

Ultracode dynamic workflows. The default for substantive separable work. The script holds the loop; results stay out of main context. When routing here, carry the wave wisdom as guidance for the workflow author:

- Extract shared contracts and types first, as a serial stage before any parallel work begins.
- Keep parallel stages file-disjoint; prove disjointness before running them in parallel, and never reduce parallelism on a hunch once it is proven.
- Verify the merged state per stage before advancing.

This is the distillation of the synchronised-development wave model, expressed as workflow authorship guidance rather than a separate skill.

#### gsd

A whole MVP in an unknown area. Durable cross-session state required. Routes into `playbook:gsd-mode`, which front-loads user involvement and forces parallel execution. Detect GSD availability before routing (see `playbook:gsd-mode`); if absent, prompt to install with `npx get-shit-done-cc@latest` and let the user re-run or pick a different mode.

### 6. Production-ready sweep

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
- Announce model downshifts on each spawn: `🪙 executing on Sonnet: <reason>`.
- Run the production-ready sweep before handing work back.

## Integration

Sibling skills reached from this engine:

- `playbook:hackathon-team`: the hackathon route.
- `playbook:gsd-mode`: the gsd route; front-loads involvement, forces parallelism.
- `playbook:brainstorming`: auto-triggered on fuzzy or open-ended ideation; hands off cleanly into the routed mode.
- `playbook:offline-mode`: enables offline behaviour for tenet 5; explicit and per-run, never implicit.
- `playbook:worktrees`: for genuinely separate work launched as distinct Claude Code sessions.
- `playbook:model-rule`: always-on; Sonnet executes, Opus plans and reviews, bump up when stuck. Propagated into every subagent and workflow stage via the `SubagentStart` overlay and explicit `model:` on each dispatch.
