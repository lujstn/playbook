# Playbook: Design Specification

Package: `@lujstn/playbook`
Plugin: `playbook`

## 1. Purpose

Playbook is a personal Claude Code workflow harness. It does two things and only two things:

1. A **decision engine** that, at the start of any non-trivial work, restates the one thing that matters, asks its questions once, and makes a single visible staffing call: which of five team modes will run the work and why.
2. An **execution overlay** of nine tenets that rides on top of whichever mode was chosen and improves adherence to disciplined behaviour throughout execution and across compaction.

Playbook does not replace Claude Code's native behaviour, nor Superpowers, nor GSD. It hops on top of them. Native Claude Code already attempts most of the nine tenets; in practice it does not apply them reliably enough. The shortfalls are in enforcement and triggering, not in concept. Playbook closes those specific gaps with the minimum mechanism, and routes execution to the right existing engine rather than building a third one.

Two principles govern every decision in this design. Less is more: the common path must be zero-dependency, the skill count minimal, the prose short. Speed is not rushing: when work is separable, fan it across more agents to finish faster at the same completeness bar; never ship partial work to save time.

A third principle governs the harness's own state. Playbook carries its working state in the conversation and never writes a file into the user's project. A person does not write down their goal, their unease, or how full their head is. They carry these things and let them colour the next decision. Playbook makes a language model behave that way; it is a light overlay, not a note-taking system bolted onto the user's tree. This principle is realised in full in sections 6 and 7 and restated without ambiguity in section 14.

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

The user describes the work in a normal sentence. `playbook:playbook` responds with the North Star (one line of what matters), a short batched set of routing questions answered once, then one staffing sentence naming the chosen mode and the reason. The sentence is always visible and vetoable in plain language. There is no wizard and no setup screen. For trivial work the North Star is one line and there are zero questions.

## 3. The nine tenets and the mechanism that enforces each

The tenets are doctrine written inside `playbook:playbook`. Their always-on guarantee does not come from skill text being re-read (a skill fires once and its text does not follow GSD or Superpowers subagents into fresh contexts). It comes from the hooks plus the in-session anchor carried in the conversation (sections 6 and 7). This is why the overlay is not a separate skill and must never be promoted back to one.

Each tenet exists because native Claude Code falls short of it in practice. The "Native shortfall it closes" column states the verified gap; the "Enforcing mechanism" column states the minimal harness that improves adherence. This is the lens the framing note in Appendix A requires.

| # | Tenet | Native shortfall it closes | Enforcing mechanism |
|---|---|---|---|
| 1 | Remember what's important | Compaction reconstructs intent from a flat, unweighted message list, so the original request can be outranked by orchestration scaffolding | The in-session anchor (section 6): original request verbatim plus current one-line North Star, carried in the conversation, restated at every checkpoint, and re-injected with primacy after every compaction, the request recovered from the transcript rather than stored |
| 2 | Ask stupid questions | AskUserQuestion fires only on felt blockage; there is no upfront batched-clarification discipline outside plan mode | `playbook:playbook` batches only the routing questions upfront, once, before the staffing call: enough to judge separability, durability and rough size. There are no stupid questions; ask as many as the routing decision needs. Requirements and design clarification is deferred to the routed substrate, not done at the door. Per tenet 4, may still stop and ask later. Not drip-fed by default |
| 3 | Team alignment | "Trust but verify" is an unquantified judgement call; there is no peer or external manager (CTO) alignment step and no equals-and-pushback doctrine | Overlay doctrine for every multi-agent mode: treat the team as equals; a lead, conductor or orchestrator holds coordination authority only, not intellectual authority; subagents push back with technical reasoning and the coordinator must not override correct judgement by fiat, its job is to route, unblock and rally. Use your own intellect before escalating to the user's. Peer sanity-check by subagent is the routine cheap path; external-manager escalation is gated by the in-session unease sense so it never becomes ceremony. The one technically-forced exception is `hackathon-team` (section 5.2) |
| 4 | Unease | The model asks only when it feels blocked; there is no calibrated confidence signal and no rule tying a mandatory stop to the goal | The in-session unease sense (section 7), not a numeric score and not a file. The agent maintains one current unease level and last movement, restated against the North Star only when something changes, and escalates up the ladder (section 9) on its own judgement when its unease has risen. Standing override, independent of the unease level: if an unease or decision could degrade the North Star such that the work would no longer meet it, stop and ask the user before proceeding, regardless of the unease level or the mode |
| 5 | Offline mode | Native has no offline path, no emergency channel, and no wait-then-escalate behaviour | `playbook:offline-mode`. Explicit per-run picker for the wait window (default pre-filled at 10 minutes) or to disable waiting. ntfy notification replaces SMS. If still unreachable, escalate to an external manager (CTO): an external-model LLM with control powers over this running instance. Absent-decisions logged to an HTML doc |
| 6 | Ready for production | YAGNI guidance exists but there is no explicit rule against shipping plan/wave/mission scaffolding and no comment-minimalism tenet | A shipping reflex in the engine doctrine: no scaffolding vocabulary (plan, wave, mission) in shipped code, minimal comments, no plan references. A final sweep before handing work back |
| 7 | Take a beat | Compaction is fixed-schema, fires only at the hard limit, has no lessons-learned slot, and re-anchors weakly | The `take-a-beat` hook fires at about sixty-five percent of context used (section 6). It announces, re-establishes the in-session anchor and the carried lessons, carries lessons-learned forward rather than discarding them as historical, and re-anchors on the original request and upcoming work with primacy over orchestration scaffolding |
| 8 | Less is more | Plan mode and tooling bias toward thoroughness; nothing pushes toward the cheapest sufficient approach or shorter output | Longer thinking and shorter output is the goal, and is what true intelligence looks like; resist the model tendency to overproduce prose between the thinking and output stages. Encoded as engine defaults: pick the cheapest sufficient mode; short questions, plans and comments; give subagents freedom rather than over-controlling them; keep the common path zero-dependency |
| 9 | Speed via more hands, not rushing | Native guidance discourages parallel fan-out ("should not be used excessively") and has no doctrine separating speed from rushing | When work is separable the engine fans it across agents for speed at the same completeness bar. Partial work to save time is forbidden. "Rushing" is permitted only if the user explicitly says to rush |

## 4. Component inventory

### Skills (5)

1. **`playbook:playbook`**: the engine. North Star restatement, batched questions, the staffing call, five-mode routing, the nine tenets doctrine, decompose-as-judgement, and the `writing-plans` override. This is the front door and shares the plugin name by explicit choice.
2. **`playbook:hackathon-team`**: thin choreography over native agent-teams.
3. **`playbook:offline-mode`**: explicit offline enablement, per-run wait picker, decision-log accumulation, HTML export.
4. **`playbook:modifying-plans`**: reshapes a Superpowers plan into wave-grouped form. Moved into this package and owned here.
5. **`playbook:synchronised-subagent-development`**: federated worktree execution with conductor merge and wave-integration review. Moved into this package and owned here.

### Hooks (plugin extensions, not skills)

- **`unease`**: tenet 4. Fires on every agent action and asks the agent one thing: restate the unease level and last movement, with a reason, only if something changed. The default and expected answer is silence: nothing changed, so nothing is emitted. It performs no computation and maintains no state; the judgement lives in the doctrine (section 7). It is registered on `PostToolUse` and `Stop`. Inside a subagent the platform converts `Stop` to `SubagentStop`, which carries no additional context, so the reply-only-turn pulse does not fire there; the per-tool-use pulse on `PostToolUse` still does, and the conductor or lead holds the project-level unease (section 7.10). This bounded absence is silent degradation, never a wrong unease value.
- **`take-a-beat`**: tenets 1 and 7. Recovers the original request from the transcript and re-injects it with primacy on the post-compaction events; emits the pre-compaction steer; computes the context percent from the transcript usage sum and the agent-declared window and beats at about sixty-five percent of context used (section 6). When no window is declared but usage exists, it emits one self-healing notice per session instead of staying silent (section 6.4). It is `agent_id` aware: inside a subagent the recovered first message is the dispatch prompt, so it is labelled as the assigned task and the dispatcher-provided project North Star, if present, is given primacy (section 6.1).
- **`session-start`**: emits the overlay. It is registered on `SessionStart` for the main thread and on `SubagentStart` for every spawned subagent (a `Task()` subagent fires `SubagentStart`, a distinct event from `SessionStart`, whose stdout is shown to the subagent). This is how the overlay reaches helpers in every multi-agent mode, including substrates Playbook does not own. The overlay states the in-session model; it never claims a file is the persistence mechanism. It emits the actual hook event name so the platform routes it.

### Helpers

A small shared library backs the hooks: a transcript reader keyed on the `transcript_path` every hook is given, an original-request recovery helper, a project-North-Star recovery helper (the `playbook-northstar:` dispatch line, section 6.1), a subagent-aware anchor-block builder, a transcript usage-sum helper, an agent-declared-window parse helper, and a cross-platform context-injection emitter. None of these reads, writes or persists any file in the user's working tree; the only file any of them touches is Claude Code's own transcript.

### Described inside `playbook:playbook`, not separate skills

The five routes (`lone-wolf`, `intern-team`, `hackathon-team`, `superpowers-team`, `gsd-team`), the nine tenets, the in-session anchor protocol, the unease doctrine, the escalation ladder including the ntfy step, the `writing-plans` override, and decompose-as-judgement.

### External prerequisites

- `obra/superpowers` provides `brainstorming` and `writing-plans` for the `superpowers-team` route.
- `gsd-build/get-shit-done` provides the roadmapper and the full `gsd-team` route.

## 5. Skill specifications

### 5.1 `playbook:playbook` (engine)

Triggers at the start of any non-trivial work. Flow:

1. Restate the North Star: one line of what matters, taken verbatim from the user's request and carried in the conversation as part of the in-session anchor (section 6).
2. Ask only the questions the staffing call needs (separability, durability, rough size) in one batched set. Defer requirements and design clarification to the routed substrate; do not gather it here.
3. Assess separability and durability. Decide whether the work is too big and must be decomposed (decompose-as-judgement); if so, propose the cut and recurse into the engine per piece.
4. Make the staffing call: one visible, vetoable sentence naming the mode and the reason.
5. Route to the chosen substrate. Keep the tenets doctrine and the in-session anchor live throughout.
6. On the `superpowers-team` route, apply the `writing-plans` override (section 8).
7. Before handing work back, run the production-ready sweep (tenet 6).

Standing rule across every step: if an unease or decision could degrade the North Star such that the work would no longer meet it, stop and ask the user before proceeding, regardless of the unease level or the mode (tenet 4).

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

If a route's prerequisite is not installed, prompt the user to install it at that fork rather than failing (section 10).

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
- **Decision log.** While offline mode is active, accumulate a running ledger of events that occur specifically because the user was absent: forced-without-you decisions made after the wait window elapsed, external manager (CTO) consultations, waits, and ntfy sends. Online runs produce no log, because when online the user's absence means blocked and we wait rather than proceed.
- **HTML export.** Render the ledger to a clean, simple-to-read HTML document, saved to a folder the user chooses at runtime: the project root, or a dedicated logs folder outside the root. The intent is a document the user can read in the morning.

The external-manager step that keeps escalation never routine is gated by the in-session unease sense (section 7), not by any stored ledger. The standing North-Star override applies here exactly as everywhere else: if a decision could degrade the North Star such that the work would no longer meet it, stop and ask the user before proceeding, regardless of the unease level or the mode.

### 5.4 `playbook:modifying-plans`

Owned and distributed by this package. Inherited behaviour, as-is: it reshapes a Superpowers plan (after `writing-plans`) into wave-grouped form, grouping tasks into file-disjoint waves that can run in parallel, hands off to `playbook:synchronised-subagent-development` on success, and falls back to serial execution if the plan cannot be wave-grouped. The internal mechanics of how it does this are the skill's own and are not re-specified here. Any extension we want beyond inherited behaviour is deferred and will only be specified here with explicit agreement.

### 5.5 `playbook:synchronised-subagent-development`

Owned and distributed by this package. It executes a wave-grouped plan as a synchronised team of implementer subagents, each in its own isolated git worktree, with a conductor that owns integration and a per-wave integration review on the merged result. This is the faithful realisation of the synchronised-swimmer model (section 2): isolated lanes, plus a shared choreography (the wave-grouped plan), plus a conductor keeping them in sync. It is not a peer mesh.

Agreed extension beyond inherited behaviour, the conductor whistle: an implementer that discovers a wave-breaking problem mid-wave (a wrong contract, a broken shared assumption) raises a flag to the conductor. The conductor may halt the wave, re-plan, or broadcast a corrected constraint to the still-running siblings before merge. There is no peer-to-peer messaging; the conductor is the only hub. This recovers the "call each other out" and "the lead should intervene or rally the team" parts of the original mode-4 definition, and closes the blind spot where a wave-breaking discovery would otherwise surface only at post-wave merge, after parallel work was already wasted. All other internal mechanics are the skill's own and are not re-specified here.

## 6. The in-session model: anchor, compaction seam, and context signal

Nothing in this section is written to disk. There is no file, no `.playbook/` directory, no anchor file and no ledger. The conversation is the store. The hooks steer the compaction seam and prompt the working pulse; they never persist anything into the user's working tree. Three facts make this no-file design correct rather than merely desirable:

- The original request is the first user message in the transcript. Every hook receives `transcript_path` on stdin, so a hook can recover the verbatim original request deterministically and re-assert it with primacy after compaction. This is more robust than the file it replaces.
- Unease is a judgement, not a transcript fact. It cannot be recovered by a hook and must not be. It lives only as the agent's most recently stated level and movement, riding the conversation. If compaction loses it, the agent notices the absence quickly and re-derives a fresh reading from the work in front of it (section 7).
- Context used is computed by Claude Code itself, with the exact formula `input_tokens + cache_creation_input_tokens + cache_read_input_tokens`, and every assistant turn records those fields in the transcript. A hook reads the transcript and divides by the window the agent declares from its own environment.

Tenets 1, 4 and 7 stay three separate mechanisms. They share one plumbing idea, in-session carriage with the conversation as the store and hooks that steer and prompt but never persist. They are not merged into a single combined mechanism. This section owns tenets 1 and 7; section 7 owns tenet 4 end to end.

### 6.1 What is carried

The anchor is the working state the engine keeps live throughout, carried in the conversation rather than saved:

- The original user request, verbatim. This alone is recoverable deterministically: it is the first human user message in the transcript, and every hook is given `transcript_path`, so it is recovered and re-asserted rather than stored.
- The current one-line North Star.
- The running lessons and wrong turns, including silent wrong turns, not only errors that produced a stack trace.
- The current unease level and last movement (section 7 owns its content).
- The declared context window (section 6.5 owns its content).
- The next work.

Only the original request is recoverable by a hook. The North Star, the lessons and wrong turns, the current unease, and the declared context window are restated working state that rides the conversation and is re-derived if a compaction loses it.

Inside a subagent the recovered "first human user message" is not the user's request: it is the dispatch prompt the orchestrator wrote. A hook cannot recover the project North Star for a subagent, because it is not in the subagent's transcript. The engine therefore passes the project North Star into every helper dispatch, in every mode, as a single labelled line of the form `playbook-northstar: <one-line North Star>`. This is the data analogue of the declared-window line: a value of restated working state, not pasted doctrine, recovered from the subagent's own transcript by the same mechanism that recovers the original request. Inside a subagent `take-a-beat` and `session-start` therefore label the recovered dispatch prompt as the assigned task and give the `playbook-northstar:` value primacy as the anchor; if no such line was provided they label the task honestly and instruct the subagent to request the project North Star or raise unease, never fabricating one. On the main thread no such line exists and behaviour is unchanged.

### 6.2 The compaction seam

At the compaction seam the pre-compaction steer instructs the summary to preserve, verbatim and ahead of orchestration scaffolding: the original request, the current North Star, the lessons and wrong turns, the current unease level and movement, and the declared context window. This is emitted on `PreCompact` with matcher `manual|auto`.

The post-compaction path re-injects the original request, recovered from the transcript's first human user message, with primacy, and prompts the agent to re-establish the North Star and the unease from that recovered request and the live work, so the original intent outranks orchestration scaffolding. Both `PostCompact` (matcher `manual|auto`) and `SessionStart` with `source` equal to `compact` carry this re-injection. Both paths are retained. They emit identical text, so if both fire for one compaction the agent sees the same anchor once per firing, which is idempotent and harmless. Retaining both makes the behaviour correct whichever event a real auto-compaction emits on the running build.

### 6.3 Recovery detail and silent degradation

The original request is the first transcript record that is the human's own user message, not a hook-injected or system-generated record that can precede it. The recovery helper reads `transcript_path`, identifies that first human message, and returns its text verbatim and nothing else.

Silent degradation is mandatory throughout this design: a wrong value or a false action is always worse than no action. If the transcript is unreadable or no user message is found, the hook emits nothing rather than a wrong anchor. The same rule governs the context signal in section 6.4.

### 6.4 The context signal

Tenet 7 needs to know how full the head is, and it derives this without owning or reading any file Playbook writes. The signal is the transcript usage sum over the window the agent itself declares:

- **Used** is read from the transcript. The latest assistant record carries `message.usage`; used equals `input_tokens + cache_creation_input_tokens + cache_read_input_tokens`. This is Claude Code's own formula, reproduced exactly rather than estimated.
- **Window** is the nominal model window the agent declares once into the session (section 6.5). It is 1,000,000 for the one-million variant and 200,000 for the standard window.
- **Percent used** is `used / window`, and `take-a-beat` fires at about sixty-five percent of context used.

This is aligned to Claude Code's own `/context`, which divides by the raw nominal window with no reserve applied. The one-million variant divides by exactly 1,000,000, not 1,048,576. The small gap between the transcript-derived percent and `/context`'s own by-category estimate is immaterial for a soft sixty-five percent threshold.

The signal deliberately does not target the user's status bar. That figure is a separate statusline applying an auto-compact-buffer rescale Playbook does not own; tracking it would re-couple Playbook to a third-party convention it does not own, which is exactly what this design forbids. There is no bridge file, no reserve constant and no statusline slot. If the latest usage record is briefly absent immediately after a compaction, the hook emits no beat rather than a false one. If no declared window can be found but usage records exist, the hook still emits no beat, never a guessed one, but it does emit one self-healing notice for the session: a single visible line stating that the context meter is off and instructing the agent to declare its window so the beat re-enables. The notice is gated on the transcript not already carrying it, so a compliant agent that then declares its window clears the condition and never sees it again. This converts a silent failure into a visible, self-correcting one without ever substituting a wrong value; there is still no floor and no reserve constant.

### 6.5 The agent-declared window

The running model is told its own context window by its environment. A hook is given only the bare model id, which does not encode the window variant, so the agent is the reliable source.

Engine doctrine instructs the agent, once at the start of work, to state its context window into the conversation as a single line with a fixed prefix the hook can match, of the form `playbook-window: <integer>`, for example `playbook-window: 1000000`. `take-a-beat` reads `transcript_path` for two things: the latest usage sum, and the agent's own declaration of the window. The declaration parse is role-anchored exactly as the original-request recovery is: only an assistant-authored record counts, and the whole trimmed text element must be the declaration, so a tool-result echo of a spec file that contains the token as an example, a user-channel paste, or a mid-prose quotation cannot be mistaken for it. The most recent such declaration wins. This closes a defect where an unanchored scan let a read of this very document silently disable the beat on a standard-window session.

The declared window is restated working state, exactly like the North Star. It is carried in the conversation, preserved by the pre-compaction steer, and re-declared if a compaction loses it. Each session declares its own, so a subagent or teammate holds its own window just as it holds its own unease; the `SubagentStart` overlay carries the same declaration instruction so a helper declares its own window and the beat works inside it. If no declared window can be found, the hook emits no beat, plus the one-per-session self-healing notice described in section 6.4.

The standing North-Star override sits above all of this and is independent of the unease level: if an unease or decision could degrade the North Star such that the work would no longer meet it, stop and ask the user before proceeding, regardless of the unease level or the mode.

## 7. Unease

`unease` is an in-session signal the agent maintains and surfaces to track how uneasy it feels about delivering the work, so it can judge when to seek help. It is tenet 4. This section is the authoritative specification of its behaviour.

### 7.1 Naming

The concept is `unease` everywhere, including Appendix A. Never `uncertainty` or `anxiety`.

- `uncertainty` is rejected because it sounds epistemic ("How likely am I to be wrong?").
- `anxiety` is rejected in the interface because it may over-emotionalise the agent.

There are no references to `uncertainty` or `anxiety` anywhere in the shipped harness or its doctrine.

### 7.2 What unease is

Escalation is pure agent judgement: the agent observes the North Star, the options available, and makes the call. It decides for itself; nothing mechanical forces it. Alongside that sits a separate idea: how uneasy am I feeling right now?

The thing being replicated is the sense that, as a person works, they start feeling a little uneasy about multiple things, and that can build to the point where they stop and ask, even if looking at any one event alone would mean they do nothing. It is hard to quantify, and a zero-to-one-hundred number is not the way to do it.

Unease is another variable the agent maintains and can observe, but it is not a deterministic value. It may influence an escalation decision, but the two are entirely different things; the only purpose of exposing it is to help the agent's own judgement. Building on that pure-judgement approach, what the agent has available is:

- The agent decides for itself.
- The agent always sees the one-sentence North Star, and reflects on it.
- The agent can see the ladder of help options available to it (section 9).
- Set apart as a separate need: the agent can also see how uneasy it has been recently.

The state the agent sees and answers each time is only the three parts in section 7.3. The escalation ladder is not part of that state; it appears only when unease increases (section 7.7).

### 7.3 The per-action state and answer

After performing any action, for example replying to the user, editing a file, or running a tool, the agent sees the state and answers it. "Every tool call" is one example of an action, not the governing category. The state is three parts:

- **§1 North Star sentence**, 280 characters maximum. This is what unease is measured against.
- **§2 unease level**: exactly one of the eleven fixed words in section 7.4, meanings exactly as fixed there.
- **§3 last movement**: exactly one of the eight fixed words in section 7.5, then a colon and a brief reason, 50 characters maximum.

The agent must return a new §2 level plus a new §3 movement plus a concise reason, or state that there is no update. This determines the `last movement` state. The update happens after every agent action; it can happen a lot and be updated a lot, and that is acceptable because it does almost nothing on the common path.

The agent sees only the values it most recently stated: the single current §2 level and §3 last movement. There is no history, no trail, no timestamp and no accumulator.

### 7.4 The unease level enum (§2)

Eleven fixed words, meanings fixed exactly as written here:

| Level | Meaning of level |
| --- | --- |
| `clear` | No meaningful unease. The path feels straightforward. |
| `settled` | Some normal unease exists, but nothing is pulling attention. |
| `attentive` | The agent is aware of possible risk, but it feels ordinary and contained. |
| `watchful` | There are live concerns worth monitoring, though not yet troubling. |
| `faintly_uneasy` | A small unresolved discomfort is present. It may accumulate. |
| `uneasy` | The agent feels real concern about delivering the north star cleanly. |
| `concerned` | Multiple or significant concerns are now affecting judgement. |
| `strained` | The agent can proceed, but the work feels cognitively or directionally fragile. |
| `troubled` | The agent suspects it may be drifting from the north star or missing something material. |
| `alarmed` | The agent feels a serious risk to the north star, even if it may still continue. |
| `near_breaking` | The agent is close to needing a stop, escalation, or major reset. |

### 7.5 The unease movement enum (§3)

Eight fixed words, each followed by a colon and a brief explanation under the 50-character limit:

| Movement | Example reason string |
| --- | --- |
| `maintained` | risks unchanged after type review |
| `slightly_increased` | API surface still ambiguous |
| `increased` | north-star fit now less clear |
| `sharply_increased` | found conflicting design assumptions |
| `barely_reduced` | narrowed one open question |
| `slightly_reduced` | TSEnum path looks workable |
| `reduced` | user clarified escalation boundary |
| `sharply_reduced` | failing approach replaced cleanly |

Both enums and their meanings are fixed exactly as stated in sections 7.4 and 7.5.

### 7.6 The unease pulse

The pulse is one hook, not two. The per-action update and the second-order escalation offer are a single prompt. The hook computes nothing and holds no state.

- It is registered on `PostToolUse` (matcher `*`) and `Stop` (matcher `*`), so on the main thread it fires on every agent action: every tool use, and the end of a reply-only turn. Inside a subagent the platform converts `Stop` to `SubagentStop`, and `SubagentStop` carries no additional context, so the reply-only-turn pulse cannot fire there. This is a platform constraint, not a defect, and it is bounded: the per-tool-use pulse on `PostToolUse` still fires inside subagents (its input carries `agent_id`), and the conductor or lead, whose own turns are real `Stop` events, holds the project-level unease per section 7.10. The absent reply-only pulse inside a subagent is silent degradation, never a wrong unease value (sections 6.3 and 14).
- The prompt is a single short constant. It asks the agent to restate the unease level and the last movement with a reason only if something changed, and it carries the standing North-Star hard stop and the conditional escalation clause.
- The no-update path is silence. When nothing changed the agent emits no unease line at all; absence means the level is maintained and there is no movement. This is the minimum possible token cost on the overwhelmingly common path, and it inherently biases towards taking no escalation action.
- The hook emits its prompt as a non-blocking context injection with no `decision`, no `continue` and no `stopReason`, so the turn always terminates normally and the prompt is seen on the next turn. It never forces continuation.

There is no ledger, no band slug, no callout-shape detection, no one-hour window and no timestamp.

### 7.7 The second-order escalation offer

If the action is an increase in unease, the prompt then offers the escalation options available via the escalation ladder (section 9). The escalation offer is a conditional clause inside the one pulse prompt that the agent acts on only if its own restatement was an increase.

This is a second-order option. It is offered even when the unease increase is only small; the agent will probably decline, and that is the likely and expected path. There is effectively no way to reduce unease and trigger escalation, so the two can be tied together neatly: an increase opens the offer, a non-increase does not.

### 7.8 Decoupling of level and escalation

Unease level and the escalation decision are two different things. A high unease level does not mean escalation must follow; like a human's, unease can be high while the agent still decides not to escalate, and the agent can escalate at a low level that peaks slightly because it is unsure about something. Unease is measured against the entire project's North Star, not just the current task. It may influence an escalation decision, but the decision is the agent's own.

### 7.9 Token minimisation and the balance requirement

The two common exchange paths must be optimised for the minimum possible token usage: (a) "no change" or "keep last reason", and (b) a slight enum increase that opens the escalation ladder and the agent returns no escalation needed.

The design must encourage not taking escalation action by default while, by its very nature, being there to encourage escalation when it is warranted. These default and inherent qualities must balance each other so the model is not biased either way. Silence as the no-update path (section 7.6) and the offer-only-on-increase rule (section 7.7) together provide that balance.

### 7.10 Lifecycle and scope across sessions

Unease always exists. It is carried through compaction, never expired, and never persisted. If it does not exist it must be set, and if it is set it might be outdated; the agent should be able to tell that quickly and re-derive a fresh reading. It does not need to survive a full session restart.

Each LLM session (agent, session, or team member) holds its own unease. Unease against the North Star is for the whole project, not the local task, which is why the project North Star must reach a subagent: it arrives through the `SubagentStart` overlay (the doctrine) plus the engine-passed `playbook-northstar:` dispatch line (the value), so a helper can measure unease against the whole project rather than only its slice. A team lead is unlikely to do much beyond coordination, but will effectively end up holding overall unease for the work being done as an inherent result of its role, and it holds the reply-only-turn pulse that a subagent's `SubagentStop` cannot carry (section 7.6).

A fresh session begins without carried state: unease at its lowest level with no movement, the North Star re-established from the recovered original request, the window re-declared from the environment. A subagent begins the same way, seeded by `SubagentStart`: the overlay and, when the dispatcher provided it, the project North Star with primacy over the dispatch prompt.

### 7.11 The one hard rule above unease

This rule overrides everything else in this section. If a decision could degrade the North Star such that the work would no longer meet it, stop and ask the user before proceeding, regardless of the unease level or the mode. It is a standing override, independent of the unease level and above the escalation ladder.

### 7.12 Separate tenet, no pestering

Unease is one tenet among several and must not be merged with the others into a single combined mechanism. The tenets are different concerns and stay separate.

Pestering or repetitive-prompting behaviour is an implementation failure, not a design option. The pulse asks once per action, accepts silence as the answer, and never repeats itself for effect.

## 8. The `writing-plans` override

Superpowers' `writing-plans` skill terminates by pointing at `subagent-driven-development`. On the `superpowers-team` route, `playbook:playbook` must explicitly not follow that pointer. After `writing-plans` completes, the engine invokes `playbook:modifying-plans`, then `playbook:synchronised-subagent-development`. Because Superpowers is a declared prerequisite that we do not fork or edit, the override is orchestration-level: the engine drives the chain and ignores the built-in next-step pointer. The resulting chain is `brainstorming` then `writing-plans` then `playbook:modifying-plans` then `playbook:synchronised-subagent-development`.

## 9. The escalation ladder and ntfy

Standing override, independent of the unease level and above the ladder: if an unease or decision could degrade the North Star such that the work would no longer meet it, stop and ask the user before proceeding, regardless of the unease level or mode.

The ladder, ascending, used by tenets 3, 4 and 5:

1. Self: take a breath, re-establish the in-session anchor.
2. `take-a-beat`: deliberate pause and re-anchor.
3. Research.
4. Fresh subagent for a second pair of eyes (the routine, cheap alignment path).
5. Notify the user via ntfy to come and steer, and wait. Online: the work is blocked and waits for the user. Offline (`playbook:offline-mode`): wait the per-run-declared window, default pre-filled at 10 minutes, unless disabled at that run.
6. External manager: an external-model LLM with control powers over this running instance, not a same-model peer. Reached only after the notify-and-wait step, and gated by the unease sense so it is never routine.
7. Offline only: if still no response after the window, proceed with the best call and log it to the offline HTML, having consulted the external manager first where the in-session unease warrants.

The external manager never precedes the notify-and-wait step.

ntfy replaces SMS because it is free. Setup flow: the user creates a topic via the ntfy URL, downloads the ntfy app, hands the topic to Claude, Claude saves it under `.claude`, and the skill sends notifications to that topic. The purpose of the notification is to pull the user back to their computer or the Claude app to steer. The ntfy implementation detail is deferred (section 13).

## 10. Prerequisites and graceful degradation

`lone-wolf`, `intern-team`, `hackathon-team` and all nine tenets require only native Claude Code. With neither prerequisite installed, those three modes and the full overlay work completely. Only `superpowers-team` and `gsd-team` require a prerequisite, and the engine prompts to install the right one at exactly that fork rather than failing. The common path is therefore zero-dependency, which is the tenet 8 win.

## 11. End-to-end user flow

1. The user describes the work. `playbook:playbook` triggers.
2. The engine restates the North Star (tenet 1), batches the routing questions (tenet 2), assesses separability and durability, and decides whether to decompose.
3. The engine shows one staffing sentence and routes:
   - `lone-wolf`: native, overlay live.
   - `intern-team`: native parallel `Agent` dispatch, overlay live.
   - `hackathon-team`: `playbook:hackathon-team`, thin-coordinator lead, overlay live.
   - `superpowers-team`: `brainstorming` then `writing-plans` then `playbook:modifying-plans` then `playbook:synchronised-subagent-development`, overlay live.
   - `gsd-team`: GSD, overlay live (lighter, GSD owns its own state).
4. Throughout, the tenets doctrine plus the `unease` and `take-a-beat` hooks keep all nine tenets live regardless of mode. Tenet 2 is applied at the front by the engine; the rest persist through execution and compaction. The staffing sentence stays visible and vetoable.
5. The engine runs the production-ready sweep (tenet 6) and ships clean.

## 12. Design rationale: rejected options

- A third heavyweight workflow competing with GSD and Superpowers. Rejected: it is the bloat tenet 8 forbids and reinvents engines that already work.
- The nine tenets as prose in `CLAUDE.md`. Rejected: paid every turn, cannot trigger at sixty-five percent context, cannot steer the compaction seam to keep the carried anchor and unease sense alive across it, and prose-in-context gets skipped versus behaviour invoked at the right moment.
- Forking or wrapping GSD or Superpowers. Rejected: no upstream fork, and it inherits their ceremony.
- A config wizard for mode selection. Rejected: a form is ceremony; the staffing call is one vetoable sentence.
- Always routing into a framework. Rejected: `lone-wolf` and `intern-team` must be native with the overlay only.
- Silently auto-picking the mode. Rejected: violates tenets 1 and 3; the staffing sentence must be visible.
- Routing on size. Rejected: separability and durability are the correct primitives; size only triggers decompose.
- A separate decompose skill. Rejected: decompose-as-judgement is a decision the engine already makes; the mechanics already live in `modifying-plans` and the `gsd-team` route.
- `rules` as a separate skill. Rejected: always-on adherence comes from the hooks plus the in-session anchor carried in the conversation, not from skill text being re-read.
- A persisted state file: an on-disk anchor, an on-disk unease ledger, or a context-usage bridge file owned by another tool. Rejected: it bloats the user's tree, is not how a person works, and is replaced by in-session carriage with the transcript as the only file ever read (sections 6, 7 and 14).
- A unease score from zero to one hundred, or an append-only ledger with severity bands. Rejected: unease is a judgement, not a number, and the eleven-level and eight-movement enums with silence as the no-update path replace both.

## 13. Build constraints and open items

Build constraints (binding):

- Appendix A (the user's original five states, nine tenets and framing note) is canonical and verbatim. This specification adapts on top of it and must never replace or contradict its intent or the lens it sets. Canonicity governs intent and lens, not literal mechanism: where this specification deliberately adapts a tenet's mechanism, the adaptation governs implementation. There are exactly four such adaptations: tenet 2's upfront questions are scoped to the routing decision, with requirements and design clarification deferred to the routed substrate; tenet 3's external-manager check-in is gated by the unease sense rather than routine; tenet 5's SMS emergency channel becomes ntfy; tenet 7's "65% of the day" becomes a context-only threshold at about sixty-five percent of context used. Any conflict that is not one of these four deliberate adaptations is resolved in favour of Appendix A.
- The harness must improve adherence to the tenets where native Claude Code falls short (the section 3 lens). It must not re-explain native planning, todos, subagents, compaction or code hygiene from scratch.
- British English throughout. Zero long dashes (no U+2014, no U+2013) in every shipped and specification file, with no inherited exemption.
- The unease naming directive applies everywhere, including Appendix A: the concept is `unease`, never `uncertainty` or `anxiety`.
- Pestering or repetitive-prompting behaviour is an implementation failure, not a design option.

Open items:

- The ntfy example implementation script will be provided by the user during build.
- Native agent-teams size cap tuning for all teams to be decided by the user during build.

## 14. For the avoidance of doubt

Playbook writes no file into the user's working tree. There is no `.playbook/` directory, no anchor file, no unease or ledger file, and no bridge file that Playbook owns. Nothing in this specification implies, requires or permits any state file in the user's project. The `.playbook/` files were never asked for; this design states the no-file model explicitly so the point cannot be misread again.

Reading the transcript is not persistence. The transcript is Claude Code's own data under `~/.claude`, authored by Claude Code, not by Playbook and not in the user's working tree. Playbook only reads it through the `transcript_path` every hook is already given.

What matters, the unease sense, the North Star and the declared window are held in-session: carried in the conversation, restated as the work proceeds, steered through compaction in-session, never written to disk. A fresh session begins without them: unease at its lowest level with no movement, the North Star re-established from the recovered original request, the window re-declared from the environment.

The overlay reaches subagents through the `SubagentStart` hook, not by writing anything and not by skill text being re-read; the project North Star reaches them as a value on the dispatch prompt the orchestrator already sends, not as a file. The one behaviour the platform makes impossible, the reply-only-turn unease pulse inside a subagent (`SubagentStop` carries no additional context), is stated plainly in section 7.6 rather than papered over: it degrades to the per-tool-use pulse plus the lead holding project unease, and never emits a wrong value. No part of this closes its gaps with a state file; the no-file model in this section is unaffected.

## Appendix A. The user's original mental model (verbatim, canonical)

This appendix reproduces the user's original five states, nine tenets and framing note exactly as written. It is canonical: the rest of this specification adapts on top of it and must not contradict it. The single sanctioned change applied within it is the unease naming directive (section 7.1).

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
> 2. Ask stupid questions: Ask as many questions upfront as you need to, until you're confident with your approach. There's no such thing as "stupid questions"! Prioritise upfront questions, but per §4 below ('Unease'), you should not be afraid of stopping to ask for help.
> 3. Team alignment: Check-in with external "manager" LLMs to ensure they agree with you, then sync with your whole team to have group communication to ensure everyone is onboard with the plan. Treat your team as equals - a team lead has authority only for the purposes of communication, not intellect. Pushback is okay - ask the user as many as needed until you are confident and everybody agrees, although you should try to use your own intellect before escalating to user's intellect.
> 4. Unease: If we feel we are increasingly unsure during development, check if we should pause to ask for help. Maybe all we need is to take a breath, then continue. Maybe we need to do some research. Maybe ask a new subagent for help. Or maybe, we should pause to grill user (which they are explicitly okay with). And if the risk of unease/decision point could negatively affect the "what's important" statement to the point that our work would no longer effectively meet this criteria, then we must stop and ask the user before proceeding.
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
> One additional idea worth considering: an edit-file hook that prompts Claude to continually update an unease score (e.g. 0 to 100). Minimal context cost, just a number, but useful as a signal for when to escalate to a CTO subagent or the user.
>
> Bias: trust my experience here. If your instinct is "the user is probably wrong about this being a problem," you're misunderstanding the request. Push back on specifics where you genuinely disagree, but don't dismiss the tenets wholesale on the grounds that Claude Code "already does this", the whole reason I'm building this is that, in practice, it doesn't do it well enough.
