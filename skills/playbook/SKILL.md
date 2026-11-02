---
name: playbook
description: Activates at the start of non-trivial work to propose a goal, rank the available modes with a reason each, let the user pick in an interactive picker, and keep the overlay and its nine tenets live throughout. It declares the chosen route on one branded line and asks the user only when two or more modes are viable.
user-invocable: false
---

# Playbook

## Overview

Playbook is a native steering layer. Before non-trivial work it ranks the modes, asks the user to choose when more than one makes sense, declares the route on a single branded line, and keeps the overlay and the nine tenets live on top of whichever mode runs the work. The user's decisions outrank everything here: Playbook proposes, the user picks.

**Core principle:** Route on what kind of work it is, then on its size and coupling. Execution decisions are the user's: propose, rank, recommend, and let them choose.

The overlay is carried by the hooks across compaction and into every subagent and workflow stage. The nine tenets live in this skill; the overlay and the per-prompt card point here.

## The engine

### 1. What each mode is for

| Mode | For | Example |
|---|---|---|
| 🐺 lone-wolf | Single-thread work: quick fixes and small contained changes. Also coupled work one mind can hold, when one worker won't take too long, or when the user has approved one worker knowing it may take longer because it is architecturally better. | Rename a function across a project; fix one bug; rewrite a parser's core state machine |
| 🐜 interns | Repetitive work and exploration across a set of defined changes, where each brief says exactly what to change or what to look at. Up to about ten units. Not feature development. | Add a usage example to each command doc; survey five packages for one pattern; six fully specified utilities |
| 🤝 hackathon | Small to medium feature work split across platforms or specialisms that must keep talking while they build, or a fast project kickoff where time matters more than polish. Nothing big. Needs agent teams. | One feature landing on iOS, Android and the backend at once; a realtime app's server, client and load bot with the protocol settled during the build |
| ⚙️ workflows | Most medium to large feature development that can be planned up front, then built and checked in stages. Also coupled work too big for one context or too slow with one worker, run as a chain of steps one after another; and more than about ten repetitive units. Not small features. | Team accounts with invites and roles; moving a large module onto a new storage layer in planned stages, checking after each; 48 reference explainers |
| 🏗️ gsd | Big project development, usually from scratch, where reliability and scalability matter most and more time on planning and review is acceptable; the usual first pick for a new MVP. It can start a project or arrive later, such as a demo's backend rebuilt to last. Never the primary recommendation for feature development, though it can be ranked when worthwhile and the user can always pick it. Needs GSD installed. | A habit tracker with sync and auth, built over weeks; a hackathon demo's backend made production-grade |

### 2. Rank them

Asked in order, for the work in front of you:
1. Is it a quick fix or a small contained change? lone-wolf ranks first.
2. Is it repetitive work or exploration over defined changes? interns ranks first up to about ten units, workflows beyond that, because more reports than that flood the main thread.
3. Is it feature work? Size it by the work it adds, never by how small the codebase it lands in is. Small to medium and split across specialisms that must talk, or a fast kickoff: hackathon. Medium to large and plannable up front: workflows. Small and in one place: lone-wolf. Medium or larger feature work always has at least two viable modes, so it always gets the picker.
4. Is it coupled? lone-wolf if one mind can hold it and one worker won't take too long, or the user has approved one worker; otherwise workflows, as a chain of steps.
5. Is it a new MVP or big project development where getting it right outranks speed? gsd ranks first. For feature work it ranks below the others.

Then rank the rest by how well each meets the goal, cheapest first among equals, with one honest line each on why it sits where it does. Rank only modes that are available: hackathon needs agent teams and gsd needs GSD, and the overlay says which are present. If the work is too large to route as one unit, propose the cut and route each piece (decompose-as-judgement).

### 3. The price list

Price the hands on facts, not human-team instincts: subagents are not colleagues; a dispatch costs one written brief, not a hire; interns never talk to each other; each works in a fresh context, keeping its churn out of yours; a subagent knows nothing beyond its brief, so a unit is only separable if one brief fully specifies it, and integration is yours. Wall-clock time and main-context preservation are live routing inputs. A workflow costs the most agents and takes no input mid-run, so its plan must be settled first; a hackathon costs a crew's chatter; interns cost one report each in your context. Never quote a speed multiple you have not measured.

## The picker

Where two or more modes are viable, ask. Where only one makes sense, skip the picker and declare the route.

1. Propose a goal in one line and rank every available mode, best first, each with one line on why it sits in that position.
2. Ask in `AskUserQuestion`. The question text starts `Goal: <goal line> · Mode:`. The options are the top four modes in rank order, named exactly (`lone-wolf`, `interns`, `hackathon`, `workflows`, `gsd`) as the label, with the one-line reason as the description; the first is suffixed ` (Recommended)`. If a fifth mode is available, name it in the question with its reason, so the user can type it under Other. Batch with it a second question starting `Oversight:`, asking whether the user will oversee the work or a judge should oversee it in the background, with exactly these options and descriptions:
   - `You'll oversee`: You review progress and decisions yourself.
   - `Defer to a judge after 10 mins waiting`: The model will ask you to make decisions, but defers to an external judge if you haven't responded within 10 minutes.
   - `Defer to a judge after 30 mins waiting`: The model will ask you to make decisions, but defers to an external judge if you haven't responded within 30 minutes.
   - `Autonomous development`: The model will refer any decisions or blockers to a judge without alerting you.

   The hooks read the answer and switch offline behaviour on or off themselves. Batch any other early questions in too: ask once, early, and again whenever a choice is the user's.
3. Ask only on the main thread. Helpers never ask; they inherit the chosen mode.
4. The answer confirms the North Star and the mode, and is recorded as a decision. A goal that is no longer right, or new work, gets the picker again.
5. Declare the route only after the pick, never a placeholder before it, with `playbook route <mode> <reason>`, run with the Bash tool as a command of its own rather than printed: Playbook ships the `playbook` command, which does nothing itself, and its hooks record the line and show it to the user. It follows the pick, or replaces the picker when only one mode fits. Keep the reason short; it is recorded, and the user sees one line in its place:

```
📚 Playbook session started · building with <emoji> <mode>
```

One line announces one route; if the route changes, declare a fresh, complete route, never a hybrid. When only one mode fits and the work dispatches, the route line alone suffices and helpers carry no North Star; that is a known weakening of the North Star guard, accepted by the user.

**Workflows:** a workflow takes no input mid-run, so before it starts, settle the plan with the user: the stages, what is in and out of scope, and every open question that could change the plan. Then ask them to reply "use ultracode", typed rather than pasted: Claude Code treats that word in a typed message as opting the turn into workflows. Start the Workflow tool in the turn of that reply, and give every `agent()` call in the script a `model`, reviewers and verifiers included, since Claude Code's own example script leaves it out on those. A review loop inside the script stops once a round finds nothing that matters for the goal; never loop until a review comes back empty. The dispatch guard checks Claude Code's record of the opt-in and refuses the launch if it is missing; the refusal says what to ask next. The first time, ask for "use ultracode" again. From the second, ask them to run `/effort ultracode`, and warn that it stays on for the whole session and pushes towards a workflow on every task, so they should switch back to their earlier effort with `/effort <level>` once the workflow is done. The status line shows `workflows (awaiting opt-in)` until a launch passes.

**Offline:** while a judge oversees, no question is shown, so an open dialog never blocks the run. With `Autonomous development`, the hooks answer each question with its recommended option and log it, without alerting the user; consult a judge before acting on an answer the user might reverse. With a judge after 10 or 30 minutes, the hooks push the question to the user's phone and refuse the dialog; ask it in your reply too, wait that long for a typed reply with a background `sleep`, carrying on with work that does not depend on it, then take the recommendation with `playbook goal <mode> <goal line>` and log it. A goal picker never proceeds without the user: if Claude Code's own question timeout closes it, say the picker is waiting and end your turn. Any other question that closes that way gets its recommended answer, a push to the user, and a judge overseeing with no wait. A judge overseeing means a workflow-heavy run with nobody there to type the opt-in before each launch, so when workflows is picked, ask for `/effort ultracode` instead of "use ultracode", once the plan is settled and while the user may still be there, with the same warning and a reminder in the closing report to switch back. If it is still off when you are ready to launch, wait out the user's window if they set one, then take the next-ranked mode and log why.

| Emoji | Mode |
|---|---|
| 🐺 | lone-wolf |
| 🐜 | interns |
| 🤝 | hackathon |
| ⚙️ | workflows |
| 🏗️ | gsd |
| 🧭 | brainstorming |
| 🦞 | fix |
| 👾 | debug |
| 📴 | offline |
| 🌿 | worktrees |
| 🧰 | setup |
| 🌡️ | unease (printed only when unease rises) |

## The modes

The hooks carry the confirmed North Star and the user's decisions into every helper, so a brief need not restate them. A brief that does name one with `playbook-northstar: <line>` must match the confirmed goal, or the dispatch guard refuses it. Always set `model` on every dispatch: Sonnet builds and checks, Opus plans and judges.

### lone-wolf

Main thread. Single-thread work, or coupled work one mind should hold.

### interns

Parallel unnamed background subagents, star topology, for repetitive work and exploration over defined changes, up to about ten units. Helpers do not talk to each other.

- Each lane has a brief that says exactly what to change or what to look at, and owns its files. One review at the end rather than one per lane.
- Lanes are unnamed background helpers outside any team, and each reports once, when it finishes. A named dispatch or a team outside hackathon is refused.
- The main thread takes no lane and runs no long foreground work while lanes run, so it stays free to take each report as it lands. Reports wait in a queue while the main thread is busy, so a busy main thread backs them up.
- A joint-lead is one of these. It runs its workers in the foreground and reports once all have returned, so its report never leaves a worker's handback orphaned. Nested fan-out (5 leads x 5 workers) sits inside the depth-5 cap, as a ceiling for fan-out-shaped work and never a default.
- A follow-up goes to the helper's agentId with `SendMessage`.

### hackathon

Agent teams: a small crew of specialists, such as backend, web and iOS, each owning one part and talking directly while they build, like a few friends at a hackathon. One person takes more of a leadership role (the lead talks to the user and builds too), but everyone works together. Recommended for small to medium feature work split across platforms or specialisms that must keep talking, or a fast project kickoff where time matters more than polish. Teammates message each other directly, like Slack pings, with several points in one message so mailboxes never back up; a change to the shared interface calls the whole crew to regroup and align before anyone resumes. Routes into `playbook:hackathon-team`.

### workflows

Dynamic workflows: a JavaScript orchestration the runtime executes, where the script holds the loop and intermediate results stay out of your context. For most medium to large feature development that can be planned up front and built and checked in stages, coupled work too big or too slow for one worker run as a chain of steps, and more than about ten repetitive units. Not for small features. The plan is settled with the user first, then the user opts in with "use ultracode" (see the picker).

Every workflow agent receives Playbook's helper block at SubagentStart, carrying the confirmed North Star, the user's decisions verbatim and the paths of the user's CLAUDE.md rules. It does not receive this conversation, and it cannot spawn agents or message the user. So carry the rest explicitly in the script:

- Set `model` on each `agent()` call (Sonnet to execute, Opus to plan and judge), and quote in each prompt the decisions its stage must honour.
- Extract shared contracts and types in a serial first stage; keep parallel stages file-disjoint and prove disjointness before running them; verify the merged state before advancing.
- A workflow takes no mid-run user input, so the standing override degrades to fail-and-surface: stop and return the blocker rather than guessing, and split any human sign-off into a separate workflow.
- Validate the workflow's own result before trusting it. A structured return that comes back empty or zero-findings is more often an aggregation bug in your own script than a genuinely clean task; reconcile the returned shape against the per-stage progress, and never report success on a degenerate result you have not sanity-checked.

### gsd

Big project development where reliability and scalability matter most and more time on planning and review is acceptable, with durable cross-session state. It can start a project or take over part of one later. Not the primary recommendation for feature development. Routes into `playbook:gsd-mode`. Detect GSD availability first (see that skill); if absent, say how to install it and let the user pick again.

## Unease

Playbook keeps an unease score from evidence: the user's frustration and corrections, failing tests, repeated tool failures, grinding without progress, and repeated review rounds. You can add to it, never subtract: `playbook unease <uneasy|concerned|alarmed> <reason>`. Print the line 🌡️ **Playbook** `unease: <level>` *<reason of at most 50 characters>* only when it rises. The score is evidence, not proof of failure: whether a stop was the right place to stop is for the user to judge.

- **Uneasy:** stop and rethink before the next edit or dispatch, with `playbook rethink <what changes>`.
- **Concerned:** consult a judge before more edits or dispatches. A judge is an `Agent` call run in the foreground whose description starts `judge:`, or `codex:codex-rescue`.
- **Alarmed:** consult a judge, or ask the user if they're here. Offline: push, wait the window, then an outside judge's view.

While a level is unanswered, the hooks hold the main thread's new edits and dispatches; judges and read-only lookups still go through.

The user's go halves the score.

## Reviews

1. Review against the user's spec and decisions, with one reviewer unless the user asks for more.
2. A finding blocks only if it is a bug whatever the user's appetite for risk. List the rest, and weigh every fix against its cost.
3. Reviewers and revisers never change scope or a decision; a conflict is a question for the user.
4. Only a bug earns another round. If two rounds still find bugs, stop reviewing and take a beat: simplify, accept a contained risk, or ask. Anything bigger than a fix needs a serious assessment and sign-off from a judge or the user; on money or security code, ask.
5. Growth past what the user agreed is bad news: say it in numbers, with the smaller option.

The dispatch guard holds the third round of the same review until the user or a judge has answered.

**The pause after a review.** When a review's report reaches the main thread, Playbook pauses it: edits, shell writes and dispatches are held until you record your call, while reading, tests, messages, questions and a judge still run. A review almost never comes back empty, and a bug found is not always a bug to fix; weigh it against the spirit of the user's request and the needs they gave you, which can mean less scope or more. Record the call with `playbook weigh fix "<what you will fix, what you will list for the user, whether another round is needed>"`. If the answer is bigger than a fix (a new approach, a redesign, more scope), assess it seriously and record `playbook weigh bigger "<your assessment>"`; the hold then stays until a judge returns, the user answers in a picker, or you record the user's typed sign-off with `playbook decision "<their exact words>"`. A passing message from the user is not sign-off.

**Scope.** Going against one of the user's decisions is never a judge's call. More scope is, when the user's goal needs it and it is achievable. A minor unrelated bug fix or a nice-to-have change waits until the work has been delivered, then goes to the user as a possible extension.

## Decisions

The user's decisions, in their own words, outrank you and every helper, reviewer, judge and reviser. Quote them; never credit the user with a rule they did not state. If a decision looks unsafe, show the evidence and let them re-decide; never weaken it quietly. A conflict with one is a question for the user, never a change. Every `AskUserQuestion` answer is recorded as a decision; record a typed one with `playbook decision "<their exact words>"`.

## Operating model

- **Model rule:** Sonnet builds and checks, Opus plans and judges, and no agent exists only to watch another. See `playbook:model-rule`.
- **Independent verification** means re-deriving an answer to defeat correlated error, never reviewing your own build.
- **Fresh sessions:** compaction is safe mid-task. At a natural finish above about 200k tokens of context, a fresh session with a short handover costs less than carrying on.
- When the goal is met, run `playbook done`, and list any minor unrelated fixes or nice-to-haves you held back under **Possible extensions** in the closing report.

### Production-ready sweep

Before handing work back, run the tenet 6 sweep: no scaffolding vocabulary (plan, wave, mission) in shipped code, no comment sludge, no plan references.

## The nine tenets

The nine tenets, always live:
1. Remember what matters: the goal the user confirmed and their decisions; the hooks carry both.
2. Ask early, in one batch, the mode pick included, and again whenever a choice is the user's.
3. Peers argue on reasoning, not rank; nobody outranks the user's decisions.
4. Unease is scored from evidence: rethink, then a judge, then the user.
5. Offline behaviour is enabled only by the offline-mode skill, per run.
6. Production-ready: no scaffolding vocabulary (plan, wave, mission) or comment sludge in shipped code; sweep before handing work back. Write no comments by default: a one-line fix gets a one-line change, and if the surrounding code carries no comments, yours has to be so vital and unclear that it deserves to be the only comment in the file. A comment that survives opens with @nonobvious(<category>) and a reason, where the category is one of forced-by, mirrors, must-hold, deliberately-missing or means. The comment-guard hook rejects the rest; when it does, delete the comment rather than rewording it.
7. Compaction is safe mid-task; at a natural finish, start fresh with a handover.
8. The simplest design that meets the user's decision wins.
9. Parallel hands, not rushing. Deliver the spirit of what the user asked for: more only when the goal needs it; a minor unrelated fix or a nice-to-have is offered as an extension once the work is delivered. Living with a risk the user accepted is not partial work.

### Standing override

At every step: if a choice could leave the work short of the goal, or go against one of the user's decisions, stop and ask.

## Decompose-as-judgement

There is no sixth mode and no decompose skill. Recognise the work is too big, propose the cut, recurse per piece. Decomposing a plan into waves is the workflow author's job; decomposing a product into phases is GSD's roadmapper.

## Write policy

Playbook writes into `.planning/` only via the declared pre-seed and post-process touches in `playbook:gsd-mode`. Outside `.planning/`, Playbook does not write into the working tree; state lives in the hooks.

## Red Flags

**Never:**
- Start non-trivial work on a mode the user has not picked when two or more modes were viable.
- Ask from a helper. Only the main thread asks.
- Route on size. Size triggers decompose-as-judgement only.
- Omit the route line. It is the heartbeat; its absence must be noticeable.
- Start the Workflow tool before the plan is settled with the user and they have opted in with "use ultracode".
- Ship scaffolding vocabulary or plan references in delivered code (tenet 6).
- Follow `writing-plans`' built-in `subagent-driven-development` pointer.
- Write into `.planning/` outside the declared gsd-mode touches.
- Look for the nine tenets in the overlay; they live in this skill.

**Always:**
- Propose a goal, rank every available mode with a reason each, and recommend the top one.
- Declare the route with `playbook route <mode> <reason>`.
- Set `model` on every dispatch; the hooks carry the North Star and decisions into every helper.
- Apply the standing override at every step.
- Run the production-ready sweep before handing work back.

## Integration

- `playbook:hackathon-team`: the hackathon route.
- `playbook:gsd-mode`: the gsd route.
- `playbook:brainstorming`: fuzzy or open-ended ideation; hands off to the picker.
- `playbook:offline-mode`: enables offline behaviour for tenet 5; explicit and per run.
- `playbook:worktrees`: separate work launched as distinct Claude Code sessions.
- `playbook:model-rule`: always-on; Sonnet builds and checks, Opus plans and judges.
