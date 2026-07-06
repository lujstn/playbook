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

- **Separability** decides the coordination topology: can the work be partitioned by file ownership and run without peer communication (interns), is it a living build whose specialist pieces must talk to converge (hackathon), or is it a frozen plan a script can execute wide while keeping results out of main context (workflows)?
- **Durability** decides whether state must survive `/clear`: if yes, gsd; if no, the session-scoped modes.
- **Size** decides only whether to decompose first. If the work is too large to route as one unit, propose the cut and recurse per piece (decompose-as-judgement). There is no sixth mode for this; it is a decision that lives in the engine.

Ultracode is the assumed baseline: most substantial work runs under `/effort ultracode`, where you can launch a dynamic workflow yourself. Match the tool to the task, never to the mode, and right-size the number of hands to the number of genuinely independent units the task actually has. The hand count follows the work; it is never a target to scale up to, and this governs the count inside interns just as much as the choice to run a workflow. Ask what this task actually requires before reaching for scale, and cost the hands correctly when you ask it: subagents are not colleagues. A dispatch costs one written brief, not a hire; interns never talk to each other, so coordination does not grow with their number; and each works in its own fresh context, keeping its churn out of yours. The true costs sit elsewhere: a subagent knows nothing beyond its brief, so a unit is only separable if one crisp brief fully specifies it, and integrating the results is yours. Price staffing on these facts, not on human-team instincts. Wall-clock speed and main-context preservation are live routing inputs on genuinely independent units: when parallel hands would finish separable work sooner, or fanning the bulk out would keep the main thread sharp, weigh that gain against the briefs it costs and say so in the marker reason. A workflow earns its place only when one of these genuinely holds: the plan is frozen before launch and runs at parallel scale, medium or larger, or the bulk exceeds what one context can hold, or independent verification is itself the deliverable (an answer re-derived through several independent agents to defeat correlated error on a high-stakes or ambiguous result). The tie-break against hackathon is one question, asked before reaching for the script: will the plan survive contact unchanged? Frozen and known up front is a workflow; alive and negotiated as it lands belongs to a crew of experts, not a script. Reading and fixing a known, bounded set of files is none of these: even a couple of dozen files is lone-wolf or interns, because the set fits one plan, and an audit's own checking is self-review or a single reviewer subagent, not a fan-out. This tie-break is decisive: a read-and-fix or audit over a known file set is interns at most unless that bulk exceeds what one context can hold, and it overrides the units-count and verification justifiers. "Ultracode is on, so this is the right scale" is the wrong reasoning; the mode being on is never itself the reason to fan out, and relabelling a 23-agent fan-out as interns is just as wrong as calling it a workflow. When ultracode is not on, workflows are opt-in instead: run interns and point the user at the `/workflow` command or the ultracode keyword to scale further.

### 3. Announce the route

Print exactly one branded marker line before routing:

```
<emoji> **Playbook** `<mode>` *<≤60-char reason>*
```

The **Playbook** brand is mandatory so the marker is unmistakably Playbook on top of any other tool, and its disappearance is obvious. One marker line announces one route: if the route changes mid-task (a fall-back when a flag is absent, a denied dispatch, an escalation), print a fresh, complete marker line for the new route, never a hybrid or arrow line carrying two modes.

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

Parallel subagents, star topology. Helpers do not talk to each other. Includes the named joint-leads to workers nested fan-out: e.g. 5 leads x 5 workers = 25 agents at depth 2, inside the hard depth-5 cap. Use when the work is a list of separable chores: chains of action that need following, not debating, such as research sweeps, code crawls, repetitive edits and bulk data changes. Interns are parallel Sonnet lone-wolves by default under the model rule, each handed one crisp brief. Interns is also how separable work finishes sooner and how its bulk stays out of the main context; when either gain is real, weigh it against the briefs it costs and name it in the marker reason. The 25-agent figure is the ceiling for genuinely fan-out-shaped work, not a default: spawn one hand per genuinely independent unit and usually fewer, so a bounded read-and-fix gets a handful of interns at most, never a 25-agent nest.

#### hackathon

Agent teams: a cross-communicating crew of experts, each a specialist owning their own piece, talking simply and often to converge on one shared MVP. Use when a real build is still taking shape and spans different specialisms that must land together; the pieces need judgement and mutual adjustment, not just instruction-following. Check availability mechanically before routing here: the CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS environment variable is one shell echo away, and when it is absent fall back and say so in the marker reason. This is the mode where the most control is handed over, which is exactly why the default never picks it unprompted; licensing that trust when the build deserves it is the point. Do not argue against hackathon with interns logic: teammates are not isolated agents. They share one working tree, read each other's code, and negotiate through direct messages, so an interface or protocol that must be settled during the build is an argument for a crew, not against one. The hackathon-or-lone-wolf boundary on a coupled build is decided by spine density, not by a coherence preference: ask how much of the build is the shared interface. A thin spine over deep pieces, a protocol file or schema or API surface that is a sliver of the total work, is crew-shaped: the spine gets one owner and one shared artefact, changes to it are broadcast in a message, and the deep pieces proceed in parallel, which is how every real team builds coupled systems; a backend platform, a web UI and a native app landing together is this shape exactly. Serialising the bulk to protect the sliver pays a pound to insure a penny, and the user waits several times as long for the same MVP; wall-clock is a live routing input here exactly as it is for interns. Only a dense spine, where the interface effectively is the build and the pieces have no independent depth, justifies one mind holding the whole, and the marker reason must then say so in terms of the spine, not coherence in general. Routes into `playbook:hackathon-team`.

#### workflows

Dynamic workflows: a JavaScript orchestration the runtime executes, where the script holds the loop and intermediate results stay out of your context. This is a peer mode, not the default, and it earns its place only when the work has dozens to hundreds of genuinely independent units, a scale one context cannot hold, or a need for independent verification that is itself the deliverable. The agent count follows the number of independent units; it is never a figure to scale up to.

Under ultracode you can start a workflow yourself; otherwise the Workflow tool only runs once the user opts in via `/workflow` or the ultracode keyword. Either way, decide by what the task needs, not by whether the power is available. Rule out the cheaper modes first: quick or coherent work is lone-wolf; a list of separable chores is interns; a living build whose specialist pieces must talk to converge is hackathon, when agent teams are available; reach for a workflow only when the plan is frozen before launch at medium scale or larger, the bulk exceeds one context, or independent verification is itself the deliverable. Sizing the tool to the task is the discipline: ultracode being on is never the reason to fan out, and a small read-and-fix never warrants a multi-agent adversarial swarm. Without ultracode, surface one line offering `/workflow` rather than running it. Announce the ⚙️ workflows marker only once a workflow is actually running, never before.

When you do run a workflow, a workflow subagent does receive Playbook's SubagentStart overlay, so the doctrine reaches it; but it does not receive CLAUDE.md, this session's North Star, or anything else from this conversation, and it cannot spawn agents or message the user. So carry the session-specific context explicitly in the script:

- Put the one-line North Star verbatim at the top of every `agent()` prompt, and apply the model rule per stage by setting `model` on each `agent()` call (Sonnet to execute, Opus to plan, judge, and review), naming the rule in the prompt too.
- Extract shared contracts and types in a serial first stage; keep parallel stages file-disjoint and prove disjointness before running them; verify the merged state before advancing. Scale comes from the script's own parallelism, not from subagents spawning subagents.
- A workflow takes no mid-run user input and its subagents cannot pull the user back, so the standing override and the escalation ladder degrade to fail-and-surface inside a workflow: stop and return the blocker rather than guessing, and split any human sign-off into a separate workflow.
- Validate the workflow's own result before trusting it. A structured return that comes back empty or zero-findings is more often an aggregation bug in your own script than a genuinely clean task; reconcile the returned shape against the per-stage progress, and never report success on a degenerate result you have not sanity-checked.

The `/workflow` command carries this guidance; this section is why the engine routes there. It distils the wave-based parallel-execution model into workflow authorship guidance rather than a separate skill.

#### gsd

A full MVP in an unknown area, a day's work or more, spanning multiple sessions. Durable cross-session state required. Routes into `playbook:gsd-mode`, which front-loads user involvement and forces parallel execution. Detect GSD availability before routing (see `playbook:gsd-mode`); if absent, prompt to install with `npx get-shit-done-cc@latest` and let the user re-run or pick a different mode.

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
