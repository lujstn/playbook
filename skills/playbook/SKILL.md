---
name: playbook
description: Use at the start of any non-trivial work, before planning or coding, to restate what matters, ask questions once, and make one visible staffing call across five team modes.
---

# Playbook

## Overview

Playbook is the front door for non-trivial work. It restates the one thing that matters, asks its questions once, and makes a single visible staffing call: which of five team modes runs the work and why. It then keeps a nine-tenet overlay live on top of whichever mode was chosen. It does not replace native Claude Code, Superpowers, or GSD; it hops on top of them.

**Core principle:** Less is more, and speed is not rushing. Pick the cheapest sufficient mode, ask questions once, keep the North Star load-bearing at every decision, and fan work across agents only when it is separable.

**Announce at start:** "I'm using the playbook skill to set the North Star and make the staffing call."

This skill rides on top of native Claude Code, Superpowers and GSD. It does not re-explain native plan mode, subagents, TodoWrite, AskUserQuestion or compaction. It closes the specific adherence gaps named per tenet below, and routes execution into an engine that already works rather than building a third one.

## The engine flow

Rendered faithfully from `plan-a-design.md` section 5.1, steps 1 to 7.

1. **Restate the North Star.** One line of what matters, derived verbatim from the user's request and kept load-bearing in the conversation. It is never written to a file. For trivial work this is one line and there are zero questions.
2. **Batch the routing questions.** Ask only the questions the staffing call needs: enough to judge separability, durability and rough size. Ask them in one batched set. There are no stupid questions; ask as many as the routing decision needs, but do not gather requirements or design here. Deep clarification of what to build is deferred to the routed substrate (`superpowers:brainstorming`, `/gsd-new-project`, or the chosen custom mode), which owns it. Per tenet 4, you may still stop and ask later.
3. **Assess separability and durability.** Decide whether the work is too big and must be decomposed (decompose-as-judgement). If so, propose the cut and recurse into the engine per piece.
4. **Make the staffing call.** One visible, vetoable sentence naming the mode and the reason. Never silently auto-pick.
5. **Route to the chosen substrate.** Keep the North Star, the unease sense and the tenets doctrine live in the conversation throughout.
6. **On the `superpowers-team` route, apply the `writing-plans` override** (see Integration). The chain is `brainstorming` then `writing-plans` then `playbook:modifying-plans` then `playbook:synchronised-subagent-development`. Do not follow the built-in `subagent-driven-development` pointer that `writing-plans` ends on; the engine drives the chain at orchestration level and ignores that pointer (Superpowers is a declared prerequisite we do not fork or edit).
7. **Production-ready sweep.** Before handing work back, run the tenet 6 sweep.

Standing rule across every step (paste verbatim, `plan-a-design.md` 5.1 and 8, tenet 4):

> if a decision could degrade the North Star such that the work would no longer meet it, stop and ask the user before proceeding, regardless of the unease level or the mode.

```dot
digraph engine {
    rankdir=TB;
    "Restate North Star" [shape=box];
    "Batch questions" [shape=box];
    "Assess separability+durability" [shape=box];
    "Decompose?" [shape=diamond];
    "Propose cut, recurse per piece" [shape=box];
    "Staffing call" [shape=box];
    "Route" [shape=box];
    "superpowers-team: writing-plans override" [shape=box];
    "Overlay live" [shape=box];
    "Production sweep" [shape=box];
    "Could this degrade the North Star below meeting it?" [shape=diamond];
    "Stop and ask user" [shape=box style=filled fillcolor=lightyellow];

    "Restate North Star" -> "Batch questions";
    "Batch questions" -> "Assess separability+durability";
    "Assess separability+durability" -> "Decompose?";
    "Decompose?" -> "Propose cut, recurse per piece" [label="yes"];
    "Propose cut, recurse per piece" -> "Restate North Star";
    "Decompose?" -> "Staffing call" [label="no"];
    "Staffing call" -> "Route";
    "Route" -> "superpowers-team: writing-plans override" [label="superpowers-team"];
    "superpowers-team: writing-plans override" -> "Overlay live";
    "Route" -> "Overlay live" [label="other modes"];
    "Overlay live" -> "Production sweep";

    "Restate North Star" -> "Could this degrade the North Star below meeting it?";
    "Batch questions" -> "Could this degrade the North Star below meeting it?";
    "Assess separability+durability" -> "Could this degrade the North Star below meeting it?";
    "Decompose?" -> "Could this degrade the North Star below meeting it?";
    "Staffing call" -> "Could this degrade the North Star below meeting it?";
    "Route" -> "Could this degrade the North Star below meeting it?";
    "superpowers-team: writing-plans override" -> "Could this degrade the North Star below meeting it?";
    "Overlay live" -> "Could this degrade the North Star below meeting it?";
    "Production sweep" -> "Could this degrade the North Star below meeting it?";
    "Could this degrade the North Star below meeting it?" -> "Stop and ask user" [label="yes (standing override, any step)"];
}
```

## The five-mode routing call

Work is routed on **separability and durability, not size**. Size only answers whether to decompose at all. Separability decides the coordination topology. Durability decides whether the work needs state that outlives the session. Rendered faithfully from `plan-a-design.md` section 2.

> | Mode | When it is chosen | Substrate |
> |---|---|---|
> | `lone-wolf` | Small, single coherent unit; no benefit from extra hands | Native main thread, no subagents |
> | `intern-team` | Several independent sub-tasks; you stay steering; helpers do not need to talk to each other | Native parallel `Agent` dispatch, up to ~10 ephemeral helpers, star topology |
> | `hackathon-team` | Coupled work in one shared codebase; peers must talk to each other; lightweight coordination | `playbook:hackathon-team` over native agent-teams |
> | `superpowers-team` | One session-scoped milestone, separable into waves, no need for durable cross-session state | Superpowers `brainstorming`/`writing-plans` plus `playbook:modifying-plans` plus `playbook:synchronised-subagent-development` |
> | `gsd-team` | Multi-milestone product; state must survive `/clear`; durable project memory required | GSD (`gsd-build/get-shit-done`) |

The staffing call is one visible, vetoable sentence in plain language: the North Star, a short batched set of questions answered once, then one sentence naming the chosen mode and the reason. No wizard, no setup screen.

### Adjacent-mode tiebreaker

Paste verbatim, `plan-a-design.md` section 5.1:

> Adjacent-mode tiebreaker, applied in this order whenever more than one route seems to fit:
> 1. If the work is separable into sub-tasks that do not need to communicate with each other, choose `intern-team`.
> 2. Else if the work is coupled and needs live peer-to-peer communication because it cannot be cleanly partitioned by file ownership, choose `hackathon-team`.
> 3. Else if the work can be made file-disjoint into waves, choose `superpowers-team` for a session-scoped milestone, or `gsd-team` when durable cross-session state is required.
> 4. Else, if none of the above adds value over a single thread, choose `lone-wolf`.
>
> Separability decides step 1 versus 2 versus 3. Durability decides `superpowers-team` versus `gsd-team` within step 3. Size only decides whether to decompose first (decompose-as-judgement), never which mode runs the work.

### The synchronised-swimmer model (mode 4)

`superpowers-team` is the synchronised-swimmer model. Synchronised swimmers do not talk underwater; they execute a shared choreography in their own lane while a coach keeps them in sync. Mode 4 parallelises a workflow that already works serially: reshape the plan with `playbook:modifying-plans`, then execute file-disjoint waves in isolated worktrees with a conductor that owns integration. The cross-team communication of the original model is realised through the shared plan contract and the conductor (plus the conductor whistle in `playbook:synchronised-subagent-development`), not through direct agent-to-agent messaging. A peer mesh is `hackathon-team`'s job; forcing one into worktree-isolated mode 4 would reintroduce exactly the conflict and cost that isolation removes.

### Decompose-as-judgement

There is no sixth mode and no decompose skill. Decompose is three things:

- **Decompose-as-judgement** (recognise the work is too big, propose the cut, recurse per piece) is a decision and lives here in `playbook:playbook`. Splitting the decision engine in two would be wrong.
- **Decompose-a-plan-into-waves** is exactly `playbook:modifying-plans`.
- **Decompose-a-product-into-phases** is GSD's roadmapper, reached via the `gsd-team` route.

### gsd-team route

GSD is **not** a Claude Code plugin: it is a global npm package installed by `npx get-shit-done-cc@latest`, and it owns `.planning/`. A global Claude install converts its commands into `~/.claude/skills/gsd-*/SKILL.md`; a local install exposes them as `/gsd-*` slash commands. Either way the user-facing entry points are the `/gsd-*` commands. Playbook only detects and hands off; it never builds or owns this route.

**Detect availability** using reliable signals, checked in this order: `get-shit-done-cc` or `gsd-sdk` resolvable on `PATH`; or `~/.claude/get-shit-done/` exists; or `~/.claude/commands/gsd/` or `gsd-*` skills are present. Do not rely on "`gsd-*` skills present" alone, because that signal is absent on local installs.

**Detect a GSD project** by `.planning/` at the project root. Optionally read `.planning/STATE.md` YAML frontmatter (`milestone`, `active_phase`, `next_action`) to report position. This read is for routing only.

**Route** by invoking the `/gsd-*` entry point. Claude Code resolves it whether GSD is installed as skills or as slash commands, so do not assert it resolves through the Skill tool exactly as the `ns-*` routers do (that holds only for global skill installs):

- No `.planning/` and a spec or PRD exists: `/gsd-new-project --auto @<spec>`.
- No `.planning/` and no spec: `/gsd-new-project` (brownfield: run `/gsd-map-codebase` first).
- `.planning/` exists: `/gsd-progress --next` (self-routing, safe to call blindly, degrades gracefully to the bootstrap path).

**If GSD is absent**, do not fail. Emit the gsd-team prerequisite fork prompt, the single canonical one in the `### Prerequisites and graceful degradation` subsection of `## The escalation ladder`, then let the user re-run or pick a different mode.

**Hard rule:** Playbook never writes into `.planning/`. It is GSD-owned durable state, read-only for routing.

### superpowers-team route

This route runs the chain `superpowers:brainstorming` then `superpowers:writing-plans` then `playbook:modifying-plans` then `playbook:synchronised-subagent-development`. It enriches, and must not contradict, engine-flow step 6 and the `writing-plans` override stated under Integration.

The engine explicitly does **not** follow `writing-plans`' built-in next-step pointer to `superpowers:subagent-driven-development`. That pointer lives in two literal strings in the upstream `writing-plans` skill, and the engine ignores both:

1. The plan-document header: `> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development ...`.
2. The `## Execution Handoff` section's "Subagent-Driven (recommended)" option.

The override is orchestration-level: we do not fork or edit Superpowers. The engine drives the chain itself, and the SessionStart overlay asserts that this precedence holds. After `writing-plans` completes, continue into `playbook:modifying-plans` then `playbook:synchronised-subagent-development` regardless of either upstream pointer.

**If Superpowers is absent**, do not fail. Emit the superpowers-team prerequisite fork prompt, the single canonical one in the `### Prerequisites and graceful degradation` subsection of `## The escalation ladder`, then let the user re-run or pick a different mode.

## The nine-tenet overlay

Doctrine that rides on top of whichever mode was chosen. Its always-on guarantee comes from the two hooks carrying state in-session, not from this skill text being re-read; this is why the overlay is not a separate skill and must never be promoted back to one. Each tenet states the native shortfall it closes and the mechanism that improves adherence (`plan-a-design.md` section 3).

1. **Remember what's important.** Native compaction reconstructs intent from a flat, unweighted message list, so orchestration scaffolding can outrank the original request. The original request is the first human message in the transcript; the `take-a-beat` hook recovers it verbatim from `transcript_path` and re-injects it with primacy after every compaction. Keep the one-line North Star load-bearing at every decision and restate it at checkpoints. State your context window once as a single line of the form `playbook-window: <integer>` so `take-a-beat` can compute the context percent. Nothing is written into the user's working tree: the conversation is the store and the hooks steer it.
2. **Ask stupid questions.** `AskUserQuestion` fires only on felt blockage; there is no upfront batched-clarification discipline outside plan mode. At the front door, batch only the questions the staffing call needs, once, before it: enough to judge separability, durability and rough size. There are no stupid questions; ask as many as the routing decision needs. Requirements and design clarification is not done here; it is deferred to the routed substrate (`superpowers:brainstorming`, `/gsd-new-project`, or the chosen custom mode), which asks as many questions as it needs there. Per tenet 4, you may still stop and ask later. Not drip-fed by default.
3. **Team alignment.** "Trust but verify" is unquantified and there is no peer or external-manager alignment step. In every multi-agent mode, treat the team as equals: a lead, conductor or orchestrator holds coordination authority only, not intellectual authority. Subagents push back with technical reasoning and the coordinator must not override correct judgement by fiat; its job is to route, unblock and rally. Use your own intellect before escalating to the user's. Peer sanity-check by subagent is the routine cheap path; external-manager escalation is gated by your in-session unease so it never becomes ceremony. The one technically-forced exception is `hackathon-team`.
4. **Unease.** The model asks only when it feels blocked; there is no calibrated confidence signal and no rule tying a mandatory stop to the goal. Unease is an in-session sense, not a file and not a score. After every agent action, restate your unease only if it changed: a level (one of `clear`, `settled`, `attentive`, `watchful`, `faintly_uneasy`, `uneasy`, `concerned`, `strained`, `troubled`, `alarmed`, `near_breaking`) and a last movement (one of `maintained`, `slightly_increased`, `increased`, `sharply_increased`, `barely_reduced`, `slightly_reduced`, `reduced`, `sharply_reduced`) then a colon and a reason of at most 50 characters. Silence means maintained with no movement. Unease is the whole project's, measured against the North Star, not just the current task; it can be high while you still choose not to escalate. Only when a restatement is an increase is the escalation ladder offered, as a second-order option you will usually decline. The `unease` hook is a stateless constant prompt that fires every action and computes nothing. Standing override, above all of this: if a decision could degrade the North Star such that the work would no longer meet it, stop and ask the user before proceeding, regardless of the unease level or the mode.
5. **Offline mode.** Native has no offline path, no emergency channel and no wait-then-escalate behaviour. Offline behaviour is enabled explicitly via `playbook:offline-mode`, never implicitly: a per-run wait-window picker (default pre-filled at 10 minutes) or disable waiting. Notification is via ntfy (it replaces SMS because it is free). If still unreachable, escalate to an external manager, and log absent-decisions to an HTML document.
6. **Ready for production.** YAGNI guidance exists but there is no explicit rule against shipping plan, wave or mission scaffolding and no comment-minimalism tenet. Ship no scaffolding vocabulary (plan, wave, mission) in shipped code, keep comments minimal, leave no plan references. Run a final sweep before handing work back.
7. **Take a beat.** Native compaction is fixed-schema, fires only at the hard limit, has no lessons-learned slot and re-anchors weakly. The `take-a-beat` hook fires at about 65 percent context used, computed from the transcript usage sum over your declared window. It announces the beat, recovers the original request from the transcript, carries the lessons and wrong turns forward rather than discarding them as historical, and re-anchors on the original request and upcoming work with primacy over orchestration scaffolding. Nothing is read from or written to a file.
8. **Less is more.** Plan mode and tooling bias toward thoroughness; nothing pushes toward the cheapest sufficient approach or shorter output. Longer thinking and shorter output is the goal and is what true intelligence looks like; resist the tendency to overproduce prose between thinking and output. Pick the cheapest sufficient mode; keep questions, plans and comments short; give subagents freedom rather than over-controlling them; keep the common path zero-dependency.
9. **Speed via more hands, not rushing.** Native guidance discourages parallel fan-out and has no doctrine separating speed from rushing. When work is separable, fan it across agents for speed at the same completeness bar. Partial work to save time is forbidden. Rushing is permitted only if the user explicitly says to rush.

## The escalation ladder

Standing override, independent of the unease sense and above the ladder (paste verbatim):

> if a decision could degrade the North Star such that the work would no longer meet it, stop and ask the user before proceeding, regardless of the unease level or the mode.

The ladder, ascending, used by tenets 3, 4 and 5 (`plan-a-design.md` section 8):

1. **Self.** Take a breath, re-read the original request and the North Star.
2. **`take-a-beat`.** Deliberate pause and re-anchor.
3. **Research.**
4. **Fresh subagent** for a second pair of eyes (the routine, cheap alignment path).
5. **Notify the user via ntfy** to come and steer, and wait. Online: the work is blocked and waits for the user. Offline (`playbook:offline-mode`): wait the per-run-declared window, default pre-filled at 10 minutes, unless disabled at that run.
6. **External manager.** An external-model LLM with control powers over this running instance, not a same-model peer. Reached only after the notify-and-wait step, and gated by your in-session unease so it is never routine. It never precedes the notify-and-wait step.
7. **Offline only.** If still no response after the window, proceed with the best call and log it to the offline HTML, having consulted the external manager first where your unease warrants.

ntfy replaces SMS because it is free. The purpose of the notification is to pull the user back to their computer or the Claude app to steer.

### Prerequisites and graceful degradation

`lone-wolf`, `intern-team`, `hackathon-team` and all nine tenets require only native Claude Code, so the common path is zero-dependency (the tenet 8 win). Only `superpowers-team` and `gsd-team` require a prerequisite. Never fail: if a route's prerequisite is not installed, prompt the user to install it at exactly that fork.

If `gsd-team` is chosen and GSD is not installed:

> gsd-team needs GSD, which is a separate tool. Install it with: npx get-shit-done-cc@latest. Then re-run, or pick a different mode.

If `superpowers-team` is chosen and Superpowers is not installed:

> superpowers-team needs the Superpowers plugin. Install it: /plugin marketplace add obra/superpowers then /plugin install superpowers. Then re-run, or pick a different mode.

## Red Flags

**Never:**
- Silently auto-pick the mode. The staffing sentence must be visible and vetoable in plain language (`plan-a-design.md` section 11).
- Route on size. Routing is on separability and durability; size only triggers decompose-as-judgement.
- Promote the overlay back into a separate skill. Persistence comes from the `take-a-beat` and `unease` hooks carrying state in-session, not from a file and not from skill text being re-read (`plan-a-design.md` sections 3 and 11).
- Ship scaffolding vocabulary (plan, wave, mission) or plan references in delivered code (tenet 6).
- Add a sixth mode, a config wizard, or a third heavyweight workflow (`plan-a-design.md` section 11; tenet 8).
- Follow `writing-plans`' built-in `subagent-driven-development` pointer on the `superpowers-team` route; drive the chain into `playbook:modifying-plans` then `playbook:synchronised-subagent-development` instead.
- Expect a `decision:block` from the `unease` hook; it is a stateless constant prompt and only nudges.

**Always:**
- Restate the North Star before anything else, and keep it load-bearing at every decision.
- Batch only the routing questions once, upfront, before the staffing call; defer requirements and design clarification to the routed substrate.
- Make exactly one visible, vetoable staffing sentence and keep it vetoable throughout.
- Apply the standing North-Star override at every step, independent of the unease sense and the mode.
- Run the production-ready sweep before handing work back.
- Fan separable work across agents for speed at the same completeness bar; never ship partial work to save time.

## Integration

**This skill is the front door. It routes into:**
- `playbook:hackathon-team` for the `hackathon-team` route (thin choreography over native agent-teams).
- `playbook:offline-mode` to enable offline behaviour for tenet 5 (explicit, never implicit).

**Moved-in skills owned by this package, used on the `superpowers-team` route:**
- `playbook:modifying-plans` reshapes a Superpowers plan into wave-grouped form.
- `playbook:synchronised-subagent-development` executes the wave-grouped plan as a synchronised team with a conductor.

**External prerequisites (the engine prompts to install at the fork, never fails):**
- `superpowers:brainstorming` and `superpowers:writing-plans` for the `superpowers-team` route. The chain is `brainstorming` then `writing-plans` then `playbook:modifying-plans` then `playbook:synchronised-subagent-development`; the engine ignores `writing-plans`' built-in next-step pointer (the `writing-plans` override).
- GSD (`gsd-build/get-shit-done`) provides the roadmapper and the full `gsd-team` route.

**Hooks that keep the overlay live (plugin extensions, not skills):**
- `take-a-beat` (tenet 7) fires at ~65% context used.
- `unease` (tenet 4) fires after every agent action and prompts the unease restatement; it is stateless and writes nothing.
