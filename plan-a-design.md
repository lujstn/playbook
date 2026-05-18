# Playbook: Design Specification

Package: `@lujstn/playbook`
Plugin: `playbook`
Date: 2026-05-15
Status: Locked.

## 1. Purpose

Playbook is a personal Claude Code workflow harness. It does two things and only two things:

1. A **decision engine** that, at the start of any non-trivial work, restates the one thing that matters, asks its questions once, and makes a single visible staffing call: which of five team modes will run the work and why.
2. An **execution overlay** of nine tenets that rides on top of whichever mode was chosen and improves adherence to disciplined behaviour throughout execution and across compaction.

Playbook does not replace Claude Code's native behaviour, nor Superpowers, nor GSD. It hops on top of them. Native Claude Code already attempts most of the nine tenets; in practice it does not apply them reliably enough. The shortfalls are in enforcement and triggering, not in concept. Playbook closes those specific gaps with the minimum mechanism, and routes execution to the right existing engine rather than building a third one.

Two principles govern every decision in this design. Less is more: the common path must be zero-dependency, the skill count minimal, the prose short. Speed is not rushing: when work is separable, fan it across more agents to finish faster at the same completeness bar; never ship partial work to save time.

## 2. The decision engine: five modes

Work is routed on **separability and durability, not size**. Size only answers whether to decompose at all. Separability decides the coordination topology. Durability decides whether the work needs state that outlives the session.

| Mode | When it is chosen | Substrate |
|---|---|---|
| `lone-wolf` | Small, single coherent unit; no benefit from extra hands | Native main thread, no subagents |
| `intern-team` | Several independent sub-tasks; you stay steering; helpers do not need to talk to each other | Native parallel `Agent` dispatch, up to ~10 ephemeral helpers, star topology |
| `hackathon-team` | Coupled work in one shared codebase; peers must talk to each other; lightweight coordination | `playbook:hackathon-team` over native agent-teams |
| `superpowers-team` | One session-scoped milestone, separable into waves, no need for durable cross-session state | Superpowers `brainstorming`/`writing-plans` plus `playbook:modifying-plans` plus `playbook:synchronised-subagent-development` |
| `gsd-team` | Multi-milestone product; state must survive `/clear`; durable project memory required | GSD (`gsd-build/get-shit-done`) |

### The synchronised-swimmer model (mode 4)

`superpowers-team` is the synchronised-swimmer model (the user's own term for mode 4). Synchronised swimmers do not talk underwater; they execute a shared choreography in their own lane while a coach keeps them in sync. Mode 4 realises this faithfully by parallelising a workflow that already works serially: reshape the plan with `playbook:modifying-plans`, then execute file-disjoint waves in isolated worktrees with a conductor that owns integration. The cross-team communication in the original mode-4 definition is realised through the shared plan contract and the conductor, plus the conductor whistle (section 5.5), not through direct agent-to-agent messaging. This is the faithful realisation of the model, not a narrowing of it: a peer mesh is `hackathon-team`'s job (native agent-teams), and forcing one into worktree-isolated mode 4 would reintroduce exactly the conflict and cost that isolation removes.

### Decompose-as-judgement

There is no sixth mode and no decompose skill. Decompose is three things:

- **Decompose-as-judgement** (recognise the work is too big, propose the cut, recurse per piece) is a decision and lives inside `playbook:playbook`. Splitting the decision engine in two would be wrong.
- **Decompose-a-plan-into-waves** is exactly `playbook:modifying-plans`. It already exists and does this.
- **Decompose-a-product-into-phases** is GSD's roadmapper, reached via the `gsd-team` route. We do not own it.

### The staffing call (UX)

The user describes the work in a normal sentence. `playbook:playbook` responds with the North Star (one line of what matters), a short batched set of clarifying questions answered once, then one staffing sentence naming the chosen mode and the reason. The sentence is always visible and vetoable in plain language. There is no wizard and no setup screen. For trivial work the North Star is one line and there are zero questions.

## 3. The nine tenets and the mechanism that enforces each

The tenets are doctrine written inside `playbook:playbook`. Their always-on guarantee does not come from skill text being re-read (a skill fires once and its text does not follow GSD or Superpowers subagents into fresh contexts). It comes from the hooks plus the pinned anchor file. This is why the overlay is not a separate skill and must never be promoted back to one.

Each tenet exists because native Claude Code falls short of it in practice. The "Native shortfall it closes" column states the verified gap; the "Enforcing mechanism" column states the minimal harness that improves adherence. This is the lens the framing note in Appendix A requires.

| # | Tenet | Native shortfall it closes | Enforcing mechanism |
|---|---|---|---|
| 1 | Remember what's important | Compaction reconstructs intent from a flat, unweighted message list, so the original request can be outranked by orchestration scaffolding | The pinned anchor file: original request verbatim plus current one-line what-matters, restated at every checkpoint and re-injected with primacy after every compaction |
| 2 | Ask stupid questions | AskUserQuestion fires only on felt blockage; there is no upfront batched-clarification discipline outside plan mode | `playbook:playbook` batches all clarifying questions upfront, once, before the staffing call. There are no stupid questions; ask as many as needed until confident. Prioritise upfront questions, but per tenet 4 do not be afraid to stop and ask later. Not drip-fed by default |
| 3 | Team alignment | "Trust but verify" is an unquantified judgement call; there is no peer or external-manager alignment step and no equals-and-pushback doctrine | Overlay doctrine for every multi-agent mode: treat the team as equals; a lead, conductor or orchestrator holds coordination authority only, not intellectual authority; subagents push back with technical reasoning and the coordinator must not override correct judgment by fiat, its job is to route, unblock and rally. Use your own intellect before escalating to the user's. Peer sanity-check by subagent is the routine cheap path; external-manager escalation is gated by the uncertainty ledger so it never becomes ceremony. The one technically-forced exception is `hackathon-team` (section 5.2) |
| 4 | Uncertainty | The model asks only when it feels blocked; there is no calibrated confidence signal and no rule tying a mandatory stop to the goal | An append-only unease ledger (section 6), not a numeric score. The agent logs an entry only when it would flag the thing to a colleague in passing (the confidant gate), tagging it with one of five bands and phrasing it as drift from the North Star. It escalates up the ladder (section 8) when the ledger forms one of three callout shapes: a single top-band entry, a rising staircase, or a cluster of small entries on one theme within the window. Standing override, independent of the ledger: if an uncertainty or decision could degrade the North Star such that the work would no longer meet it, stop and ask the user before proceeding, regardless of the ledger or the mode |
| 5 | Offline mode | Native has no offline path, no emergency channel, and no wait-then-escalate behaviour | `playbook:offline-mode`. Explicit per-run picker for the wait window (default pre-filled at 10 minutes) or to disable waiting. ntfy notification replaces SMS. If still unreachable, escalate to an external manager: an external-model LLM with control powers over this running instance. Absent-decisions logged to an HTML doc |
| 6 | Ready for production | YAGNI guidance exists but there is no explicit rule against shipping plan/wave/mission scaffolding and no comment-minimalism tenet | A shipping reflex in the engine doctrine: no scaffolding vocabulary (plan, wave, mission) in shipped code, minimal comments, no plan references. A final sweep before handing work back |
| 7 | Take a beat | Compaction is fixed-schema, fires only at the hard limit, has no lessons-learned slot, and re-anchors weakly | The `take-a-beat` hook fires at ~65% context used. It announces, re-reads the anchor and lessons ledger, carries lessons-learned forward rather than discarding them as historical, and re-anchors on the original request and upcoming work with primacy over orchestration scaffolding |
| 8 | Less is more | Plan mode and tooling bias toward thoroughness; nothing pushes toward the cheapest sufficient approach or shorter output | Longer thinking and shorter output is the goal, and is what true intelligence looks like; resist the model tendency to overproduce prose between the thinking and output stages. Encoded as engine defaults: pick the cheapest sufficient mode; short questions, plans and comments; give subagents freedom rather than over-controlling them; keep the common path zero-dependency |
| 9 | Speed via more hands, not rushing | Native guidance discourages parallel fan-out ("should not be used excessively") and has no doctrine separating speed from rushing | When work is separable the engine fans it across agents for speed at the same completeness bar. Partial work to save time is forbidden. "Rushing" is permitted only if the user explicitly says to rush |

## 4. Component inventory

### Skills (5)

1. **`playbook:playbook`**: the engine. North Star restatement, batched questions, the staffing call, five-mode routing, the nine tenets doctrine, decompose-as-judgement, and the `writing-plans` override. This is the front door and shares the plugin name by explicit choice.
2. **`playbook:hackathon-team`**: thin choreography over native agent-teams.
3. **`playbook:offline-mode`**: explicit offline enablement, per-run wait picker, decision-log accumulation, HTML export.
4. **`playbook:modifying-plans`**: reshapes a Superpowers plan into wave-grouped form. Moved into this package and owned here.
5. **`playbook:synchronised-subagent-development`**: federated worktree execution with conductor merge and wave-integration review. Moved into this package and owned here.

### Hooks (2, plugin extensions, not skills)

- **`take-a-beat`**: tenet 7. Context-monitor and pre-compaction hook, fires at ~65% context used.
- **`uncertainty`**: tenet 4. Fires at the end of every turn and asks the agent one thing: does anything want to go in the unease ledger? The default and expected answer is almost always no; logging is the rare exception, gated by the confidant test (section 6). It writes a wall-clock timestamp on any entry that is added. It performs no computation and maintains no score; the judgement lives in the doctrine (section 6).

### Described inside `playbook:playbook`, not separate skills

The five routes (`lone-wolf`, `intern-team`, `hackathon-team`, `superpowers-team`, `gsd-team`), the nine tenets, the pinned anchor file protocol, the escalation ladder including the ntfy step, the `writing-plans` override, and decompose-as-judgement.

### External prerequisites

- `obra/superpowers` provides `brainstorming` and `writing-plans` for the `superpowers-team` route.
- `gsd-build/get-shit-done` provides the roadmapper and the full `gsd-team` route.

## 5. Skill specifications

### 5.1 `playbook:playbook` (engine)

Triggers at the start of any non-trivial work. Flow:

1. Restate the North Star: one line of what matters, written verbatim from the user's request into the anchor file.
2. Ask all clarifying questions in one batched set. Do not proceed until confident or until the user declines to answer more.
3. Assess separability and durability. Decide whether the work is too big and must be decomposed (decompose-as-judgement); if so, propose the cut and recurse into the engine per piece.
4. Make the staffing call: one visible, vetoable sentence naming the mode and the reason.
5. Route to the chosen substrate. Keep the tenets doctrine and the anchor file live throughout.
6. On the `superpowers-team` route, apply the `writing-plans` override (section 7).
7. Before handing work back, run the production-ready sweep (tenet 6).

Standing rule across every step: if an uncertainty or decision could degrade the North Star such that the work would no longer meet it, stop and ask the user before proceeding, regardless of the uncertainty ledger or the mode (tenet 4).

Routing rules:

- `lone-wolf`: not separable, small, no benefit from parallel hands.
- `intern-team`: separable into independent sub-tasks that do not need to communicate; the user stays steering. Native parallel `Agent` dispatch, up to ~10.
- `hackathon-team`: coupled work in one shared codebase where peers must talk. Invoke `playbook:hackathon-team`.
- `superpowers-team`: one session-scoped milestone, wave-separable, no durable-state need. Invoke the Superpowers chain with the override.
- `gsd-team`: multi-milestone product, durable state required. Route to GSD.

Adjacent-mode tiebreaker, applied in this order whenever more than one route seems to fit:

1. If the work is separable into sub-tasks that do not need to communicate with each other, choose `intern-team`.
2. Else if the work is coupled and needs live peer-to-peer communication because it cannot be cleanly partitioned by file ownership, choose `hackathon-team`.
3. Else if the work can be made file-disjoint into waves, choose `superpowers-team` for a session-scoped milestone, or `gsd-team` when durable cross-session state is required.
4. Else, if none of the above adds value over a single thread, choose `lone-wolf`.

Separability decides step 1 versus 2 versus 3. Durability decides `superpowers-team` versus `gsd-team` within step 3. Size only decides whether to decompose first (decompose-as-judgement), never which mode runs the work.

If a route's prerequisite is not installed, prompt the user to install it at that fork rather than failing (section 8).

### 5.2 `playbook:hackathon-team`

A thin choreography over Claude Code's native agent-teams primitive (`TeamCreate`, `SendMessage`, `Agent(team_name=...)`).

- **Topology**: co-located peers in one shared working directory. Peers message each other directly by name. The lead is a thin coordinator: it partitions work by file ownership, assigns once, then steps back. Peers self-organise and are expected to call each other out.
- **Lead authority constraint**: native agent-teams requires a mandatory, non-delegable lead with task-assignment authority. The choreography casts the lead as thin (partition then step back) to honour tenet 3 as closely as the primitive allows. It cannot be a pure comms-only lead, and the spec states this limitation openly.
- **Conflict avoidance**: native agent-teams does not isolate teammates in worktrees, so file conflicts are avoided by strict file-ownership partitioning decided up front by the lead. Two teammates must never own the same file.
- **State**: no shared memory between teammates. Coordination is the shared task list plus direct inter-peer messages.
- **Lifecycle**: teammates persist until shut down, run in the background, and notify the lead on idle. The choreography accounts for the native limitation that `/resume` and `/rewind` do not restore in-process teammates.
- **Sizing**: default to a small team. Native guidance recommends 3 to 5; the choreography may go modestly higher when file partitioning is clean, but defaults conservative per tenet 8.

### 5.3 `playbook:offline-mode`

Run explicitly to enable offline behaviour for tenet 5. It is never enabled implicitly.

- **Per-run declaration, never remembered.** On every invocation it presents an interactive picker for the wait behaviour: a custom wait window (default pre-filled at 10 minutes) during which the user is notified via ntfy and the work waits for a response before proceeding, or disable waiting entirely. The choice is not persisted and not inferred from a previous run. The user must declare it fresh every time. Refreshed on every invocation.
- **Decision log.** While offline mode is active, accumulate a running ledger of events that occur specifically because the user was absent: forced-without-you decisions made after the wait window elapsed, CTO-subagent consultations, waits, and ntfy sends. Online runs produce no log, because when online the user's absence means blocked and we wait rather than proceed.
- **HTML export.** Render the ledger to a clean, simple-to-read HTML document, saved to a folder the user chooses at runtime: the project root, or a dedicated logs folder outside the root. The intent is a document the user can read in the morning.

### 5.4 `playbook:modifying-plans`

Owned and distributed by this package. Inherited behaviour, as-is: it reshapes a Superpowers plan (after `writing-plans`) into wave-grouped form, grouping tasks into file-disjoint waves that can run in parallel, hands off to `playbook:synchronised-subagent-development` on success, and falls back to serial execution if the plan cannot be wave-grouped. The internal mechanics of how it does this are the skill's own and are not re-specified here. Any extension we want beyond inherited behaviour is deferred and will only be specified here with explicit agreement.

### 5.5 `playbook:synchronised-subagent-development`

Owned and distributed by this package. It executes a wave-grouped plan as a synchronised team of implementer subagents, each in its own isolated git worktree, with a conductor that owns integration and a per-wave integration review on the merged result. This is the faithful realisation of the synchronised-swimmer model (section 2): isolated lanes, plus a shared choreography (the wave-grouped plan), plus a conductor keeping them in sync. It is not a peer mesh.

Agreed extension beyond inherited behaviour, the conductor whistle: an implementer that discovers a wave-breaking problem mid-wave (a wrong contract, a broken shared assumption) raises a flag to the conductor. The conductor may halt the wave, re-plan, or broadcast a corrected constraint to the still-running siblings before merge. There is no peer-to-peer messaging; the conductor is the only hub. This recovers the "call each other out" and "the lead should intervene or rally the team" parts of the original mode-4 definition, and closes the blind spot where a wave-breaking discovery would otherwise surface only at post-wave merge, after parallel work was already wasted. All other internal mechanics are the skill's own and are not re-specified here.

## 6. The pinned anchor file and the uncertainty ledger

A single file maintained by the engine and the hooks, holding:

- The original user request, verbatim.
- The current one-line statement of what matters.
- A running lessons-and-wrong-turns ledger (including silent wrong turns, not only errors that produced a stack trace).
- The next work.

The `take-a-beat` hook feeds the lessons ledger into the compaction prompt and re-injects the anchor first after compaction so the original intent outranks orchestration scaffolding. Proposed location is a `.playbook/` directory in the working project; the exact path is an implementation detail to be settled during build.

### The uncertainty ledger

A second engine-maintained plain-text file, sibling to the anchor. It is how tenet 4 is realised: not a numeric score, but a human-style record of accumulating unease measured against the North Star.

- **What it is.** An append-only log. Each entry is one line: a wall-clock timestamp (written by the `uncertainty` hook), one of five severity bands, and a single clause phrased as drift from the North Star ("less sure I am still delivering X, because Y"). Nothing else. There is no score and nothing is summed.
- **When to log (the confidant gate).** Before adding an entry, one test: would a competent colleague bother flagging this to the lead if they walked past? If no, log nothing. On almost every turn this means zero entries. The `uncertainty` hook asks at the end of every turn whether anything should be logged; the default and expected answer is almost always no, and on the large majority of turns nothing is logged. The hook is only a prompt to apply the confidant test; it never logs anything by itself.
- **The five bands and what each one means to do.**
  - Minorly unsure: note it, carry on.
  - Starting to become unsure: note it; glance at the ledger next time you pause.
  - Medium unsure: glance now; if an earlier entry shares the theme, research or ask a subagent.
  - Really unsure: stop, re-read the North Star, take a beat or get a second pair of eyes before continuing.
  - Dangerously unsure: stop now, escalate to the user or a CTO subagent. A single entry at this band trips escalation on its own.
- **When to escalate (the three callout shapes).** When the agent glances, it reads the ledger as a human would and moves up the escalation ladder (section 8) if it sees any one of: a single top-band entry; a rising staircase, where each new entry is a higher band than the last; or a cluster of small entries on the same theme close together. It is quantity plus severity plus trajectory, judged, never calculated.
- **The window: about one hour of active development time.** The hook's timestamps give elapsed wall-clock. The agent discounts from that only the stretches that were plainly not active development (idle, or waiting on the user), so the window tracks effort rather than the clock. Within that hour every entry still counts, even if it feels stale. An entry is deliberately not dropped early on the judgement that its concern is no longer relevant: that judgement is itself unreliable, a model can decide something no longer matters when it still does, and a still-live worry would then be lost. One hour of active development is the deliberately safe and simple measure. Compaction and take-a-beat are explicitly not the boundary. There is no timer and no accumulator; the window is a reading-time judgement applied to timestamped lines.
- **Proposed location.** Alongside the anchor in the `.playbook/` directory; the exact path is an implementation detail to be settled during build.

The standing North-Star override sits above all of this and is independent of the ledger: if an uncertainty or decision could degrade the North Star such that the work would no longer meet it, stop and ask the user before proceeding, regardless of the ledger or the mode.

## 7. The `writing-plans` override

Superpowers' `writing-plans` skill terminates by pointing at `subagent-driven-development`. On the `superpowers-team` route, `playbook:playbook` must explicitly not follow that pointer. After `writing-plans` completes, the engine invokes `playbook:modifying-plans`, then `playbook:synchronised-subagent-development`. Because Superpowers is a declared prerequisite that we do not fork or edit, the override is orchestration-level: the engine drives the chain and ignores the built-in next-step pointer. The resulting chain is `brainstorming` then `writing-plans` then `playbook:modifying-plans` then `playbook:synchronised-subagent-development`.

## 8. The escalation ladder and ntfy

Standing override, independent of the uncertainty ledger and above the ladder: if an uncertainty or decision could degrade the North Star such that the work would no longer meet it, stop and ask the user before proceeding, regardless of the ledger or mode.

The ladder, ascending, used by tenets 3, 4 and 5:

1. Self: take a breath, re-read the anchor.
2. `take-a-beat`: deliberate pause and re-anchor.
3. Research.
4. Fresh subagent for a second pair of eyes (the routine, cheap alignment path).
5. Notify the user via ntfy to come and steer, and wait. Online: the work is blocked and waits for the user. Offline (`playbook:offline-mode`): wait the per-run-declared window, default pre-filled at 10 minutes, unless disabled at that run.
6. External manager: an external-model LLM with control powers over this running instance, not a same-model peer. Reached only after the notify-and-wait step, and gated by the uncertainty ledger so it is never routine.
7. Offline only: if still no response after the window, proceed with the best call and log it to the offline HTML, having consulted the external manager first where the ledger warrants.

The external manager never precedes the notify-and-wait step.

ntfy replaces SMS because it is free. Setup flow: the user creates a topic via the ntfy URL, downloads the ntfy app, hands the topic to Claude, Claude saves it under `.claude`, and the skill sends notifications to that topic. The purpose of the notification is to pull the user back to their computer or the Claude app to steer. The user will provide an example implementation script later; ntfy implementation detail is deferred.

## 9. Prerequisites and graceful degradation

`lone-wolf`, `intern-team`, `hackathon-team` and all nine tenets require only native Claude Code. With neither prerequisite installed, those three modes and the full overlay work completely. Only `superpowers-team` and `gsd-team` require a prerequisite, and the engine prompts to install the right one at exactly that fork rather than failing. The common path is therefore zero-dependency, which is the tenet 8 win.

## 10. End-to-end user flow

1. The user describes the work. `playbook:playbook` triggers.
2. The engine restates the North Star (tenet 1), batches the stupid questions (tenet 2), assesses separability and durability, and decides whether to decompose.
3. The engine shows one staffing sentence and routes:
   - `lone-wolf`: native, overlay live.
   - `intern-team`: native parallel `Agent` dispatch, overlay live.
   - `hackathon-team`: `playbook:hackathon-team`, thin-coordinator lead, overlay live.
   - `superpowers-team`: `brainstorming` then `writing-plans` then `playbook:modifying-plans` then `playbook:synchronised-subagent-development`, overlay live.
   - `gsd-team`: GSD, overlay live (lighter, GSD owns its own state).
4. Throughout, the tenets doctrine plus the `take-a-beat` and `uncertainty` hooks keep all nine tenets live regardless of mode. Tenet 2 is applied at the front by the engine; the rest persist through execution and compaction. The staffing sentence stays visible and vetoable.
5. The engine runs the production-ready sweep (tenet 6) and ships clean.

## 11. Rejected options (for the record)

- A third heavyweight workflow competing with GSD and Superpowers. Rejected: it is the bloat tenet 8 forbids and reinvents engines that already work.
- The nine tenets as prose in `CLAUDE.md`. Rejected: paid every turn, cannot trigger at 65% context, cannot hold persistent state such as the anchor or the unease ledger, and prose-in-context gets skipped versus behaviour invoked at the right moment.
- Forking or wrapping GSD or Superpowers. Rejected: no upstream fork, and it inherits their ceremony.
- A config wizard for mode selection. Rejected: a form is ceremony; the staffing call is one vetoable sentence.
- Always routing into a framework. Rejected: `lone-wolf` and `intern-team` must be native with the overlay only.
- Silently auto-picking the mode. Rejected: violates tenets 1 and 3; the staffing sentence must be visible.
- Routing on size. Rejected: separability and durability are the correct primitives; size only triggers decompose.
- A separate decompose skill. Rejected: decompose-as-judgement is a decision the engine already makes; the mechanics already live in `modifying-plans` and the `gsd-team` route.
- `rules` as a separate skill. Rejected: persistence comes from the hooks plus the anchor file, not from skill text being re-read.

## 12. Build constraints and open items

Build constraints (binding):

- Appendix A (the user's original five states, nine tenets and framing note) is canonical and verbatim. This spec adapts on top of it and must never replace or contradict its intent or the lens it sets. Canonicity governs intent and lens, not literal mechanism: where this spec deliberately adapts a tenet's mechanism by explicit agreement in the design conversation, the adaptation governs implementation. There are exactly three such adaptations: tenet 3's external-manager check-in is gated by the uncertainty ledger rather than routine; tenet 5's SMS emergency channel becomes ntfy; tenet 7's "65% of the day" becomes a context-only threshold at ~65% context used. Any conflict that is not one of these three deliberate adaptations is resolved in favour of Appendix A. This carve-out works the same way as the British-English carve-out stated in Appendix A.
- The harness must improve adherence to the tenets where native Claude Code falls short (the section 3 lens). It must not re-explain native planning, todos, subagents, compaction or code hygiene from scratch.
- Generated skill and hook text must follow British English and must not use long dashes.

Open items:

- The ntfy example implementation script will be provided by the user during build.
- Exact on-disk paths for the anchor file and the uncertainty ledger, to be settled during build.
- Native agent-teams size cap tuning for all teams to be decided by user during build.

## Appendix A. The user's original mental model (verbatim, canonical)

This appendix reproduces the user's original five states, nine tenets and framing note exactly as written. It is canonical: the rest of this spec adapts on top of it and must not contradict it. The punctuation, including the user's own long dashes, is preserved verbatim and is not subject to the British-English and no-long-dash build constraint, which governs only generated skill and hook text.

### A.1 Mental model: the five states

> My mental model when it comes to planning work is this:
> 1. Do it alone: This is a small-enough task. It will be best if I get this done now, alone.
> 2. Help from the interns: There are multiple small tasks. I should try to do this now, but with help from a few interns/friends to make the workload faster with minimal process. It would not make sense to spend larger amounts of time on orchestration, in that case, I'd be faster alone.
> 3. Hackathon team development: There are multiple small-medium tasks. I should try to do this now with some structure and co-ordination of responsibilities, but still keeping things lightweight, like a Hackathon team. The small time I spend orchestrating things will probably pay off.
> 4. Proper team development: There are multiple medium/m-l tasks here AND/OR distinct groups of tasks in this plan that can be clearly seperated into distinct workloads. I should think about what the ideal team to deliver this work would look like if I had unlimited resources: how many people would be in the team, what would their roles be, who would work in the same folder in parallel (Hackathon style) and who would work on entirely separated workloads in their own worktrees that then merge together: this is the ultimate "synchronised swimmer" style of development, with cross-team communication. We must trust everyone on the team to work well together, call each other out, and be clear when the team lead should intervene or rally the team in one direction. Peak teamwork. Slightly more time should be given to upfront work. This will produce execution that is both fast and complete, with incredibly smooth hand-offs.
> 5. ADHD-driven development: There are multiple large-xl tasks. Whilst my intent was good, it will likely be time-consuming and difficult to deliver such big tasks, and introduce room for mistakes in development. I should try to break up this plan into the four earlier forms of development.
>
> I use Superpowers a lot. However, I feel that superpowers's Subagent-driven development approach doesn't neatly fit into any of these. It's almost like "doing it alone" meets "break down the tasks" meets "proper team development". In order to determine what our skill here should truly look like, I'd like us to talk more about what exists today and how this compares to my mental model. I am happy for my mental model to be changed.

### A.2 The nine tenets

> 1. Remembering what's important: Repeating the core of the user's request/plan, and carrying that through with every single decision point and question.
> 2. Ask stupid questions: Ask as many questions upfront as you need to, until you're confident with your approach. There's no such thing as "stupid questions"! Prioritise upfront questions, but per §4 below ('Uncertainty'), you should not be afraid of stopping to ask for help.
> 3. Team alignment: Check-in with external "manager" LLMs to ensure they agree with you, then sync with your whole team to have group communication to ensure everyone is onboard with the plan. Treat your team as equals - a team lead has authority only for the purposes of communication, not intellect. Pushback is okay - ask the user as many as needed until you are confident and everybody agrees, although you should try to use your own intellect before escalating to user's intellect.
> 4. Uncertainty: If we feel we are increasingly unsure during development, check if we should pause to ask for help. Maybe all we need is to take a breath, then continue. Maybe we need to do some research. Maybe ask a new subagent for help. Or maybe, we should pause to grill user (which they are explicitly okay with). And if the risk of uncertainty/decision point could negatively affect the "what's important" statement to the point that our work would no longer effectively meet this criteria, then we must stop and ask the user before proceeding.
> 5. Offline mode: If we want to ask the user but they have explicitly stated they are offline, we should get pause for 10mins to try and wait for a response via an emergency channel like SMS. If we can't get through, at that point we should seek external help from friendly "managers" (external-model LLMs with control powers over this running instance).
> 6. Ready for production: Always ensuring we leave minimal comments, and never leave references to "plans"/"waves"/"missions" etc.
> 7. Take a beat: After running past 65% of the day (whether that is LLM context space reaching 65% or humans working until 2.30pm without a break), the quality of output degrades. It's essential at this point to breathe out, look at what you've done, take a breather, then restart with a fresh head. For humans this is a lunch break, for LLMs this is compaction. We should proactively trigger this behaviour and be set-up to ride the wave of compaction, seeing this as good headspace as opposed to opportunity for context loss.
> 8. Less is more: It's natural to want to plan for completeness, but this often leads to bloat and confusion. We can easily spend more time planning rather then doing, because we want to ensure things are done correctly, so we over-control others. But this leads to others hitting barriers and failing because we have not given them the mental freedom to figure things out for themselves. I have repeatedly found that the best things are often the simplest: the smallest comments are the most useful, the most effective implementation often takes the simplest form. Simple statements, simple goals, freedom to implement. "If I had more time I would have written a shorter letter" rings true constantly throughout my life, and much as this is true with humans, it is even more prominent with language models who overproduce prose when trying to articulate their desires from "thinking" stages to output, but longer thinking and smaller output should always be our goal. That is true intelligence.
> 9. Speed and completeness are not mutually exclusive with more workers: There is little time in the lives of humans, so we should always push to do things as fast as possible, but that does not mean to do them poorly or partially. That is a different concept: "Rushing". I believe we should always be as fast as possible, and that AI allows us to have 'more hands on deck' by increasing compute (much like increasing the size of your team). Because of that, we should try to do more things faster in parallel, but that does not mean we are rushing, what we want is increased speed to the same end product. Completeness is not the enemy of speed, rushing is. We should never rush, unless the user is explicity telling you to "rush".

### A.3 Framing note

> My nine tenets come from observations as a Claude Code user. I'm aware that Claude Code's native system prompts and tools already attempt many of these behaviours: compaction, plan mode, TodoWrite, AskUserQuestion, risky-action approval, "no planning documents" guidance, Agent isolation, and so on. Please don't treat that as a reframing insight, or use it to argue that most of my tenets are "already native, so there's nothing to build."
>
> The point is the native prompts **don't always work well enough in practice**. The tenets are what I want consistently applied on top of Claude's existing guidance, not as replacements for it. I want this skill/harness to **hop on top of Claude's built-in behaviours and improve adherence**, not re-explain planning, todos, subagents, compaction, or code hygiene from scratch.
>
> So please frame the question as: *"where does native behaviour fall short of these tenets, and what minimal harness gets us better adherence?"*, not *"which tenets are redundant with native behaviour?"*
>
> Concrete example: Tenet 7 ("take a beat"): Native compaction exists, but what I want is something that triggers automatically at ~65% context (e.g. 650k/1m, or 195k/300k tokens), explicitly carries forward lessons learned from what went wrong (native compaction often discards these as "historical"), re-anchors on the original user request and upcoming work rather than letting planning/orchestration scaffolding dominate the summary, and stops Claude losing sight of the actual task amid rules/waves/plans/references. Native compaction is a fixed-schema continuation summary. What I want is a steered, threshold-triggered, lesson-preserving, user-intent-reanchoring variant. Same family, different requirements. The same logic applies across the other tenets.
>
> One additional idea worth considering: an edit-file hook that prompts Claude to continually update an uncertainty score (e.g. 0 to 100). Minimal context cost, just a number, but useful as a signal for when to escalate to a CTO subagent or the user.
>
> Bias: trust my experience here. If your instinct is "the user is probably wrong about this being a problem," you're misunderstanding the request. Push back on specifics where you genuinely disagree, but don't dismiss the tenets wholesale on the grounds that Claude Code "already does this", the whole reason I'm building this is that, in practice, it doesn't do it well enough.
