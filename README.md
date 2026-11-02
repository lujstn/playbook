# 📚 Playbook

`@lujstn/playbook` is a small, opinionated steering layer for Claude Code that forces Claude to keep the original goal in sight, **scores its own unease from evidence** as it works, **asks for help** (with a **notification**) when that unease builds, **proposes how to run the work** (workflows, teams or subagents) and lets you pick, and adds proper new commands for **brainstorming** and a dedicated **offline mode** for when it's running without you. In other words, all the stuff I think Claude Code should have.

It stays out of the way, only pops up when needed, and will always tell you what matters in one line. Your decisions, in your own words, outrank everything it does.

## Install

Playbook is a Claude Code plugin, so setup is two lines inside Claude Code:

```
/plugin marketplace add lujstn/playbook
/plugin install playbook
```

You'll know it's live when you see `📚 Playbook skills available in this session` in your chat, and from then on a one-line Playbook card rides along with every message you send, asking Claude whether this is new work and whether the goal is still right. Say `/playbook:hello` any time to have it introduce itself, check its pulse, and (the first time on a machine) look for plugin conflicts.

You don't need to install anything else, but it's worth having `jq`, which the hooks use to read their signals. It's on most machines already, and Playbook will tell you if it isn't.

Playbook prioritises native Claude development flows, with the one exception of large MVPs, where I'd point you at the [GSD](https://github.com/open-gsd/gsd-core) framework, which you install separately from their repo.

## How it works

Playbook is a set of Claude Code hooks and skills. There's no runtime, no daemon, and nothing written into your working tree. When a session starts, after every compaction, and with every message you send, it does six things:

1. **Keeps your goal, and your words.** The North Star is set only when you confirm it in the picker, never inferred, and your own decisions are recorded verbatim and travel into every helper.
2. **Proposes how to run the work,** judged on how separable and durable it is rather than how big it looks, and lets you choose.
3. **Keeps Claude calm near the context limit,** so it doesn't do less or stop early as the window fills.
4. **Scores its own unease from evidence** and makes Claude stop, rethink, consult a judge or ask you when it builds.
5. **Guards the dispatches** that would carry a stale goal, skip a model, or run a review for a third round.
6. **Makes Claude take a beat when a review comes back,** so it weighs the findings against the spirit of what you asked for instead of racing into fixes or a redesign.

None of it happens behind your back. The route is declared on one branded line, part nudge, part heartbeat, so you always know Playbook is alive and would spot it instantly if it vanished:

> 📚 Playbook session started · building with 🤝 hackathon team

A later change of route in the same session reads `📚 Playbook route changed · building with ⚙️ workflows`.

Claude tells Playbook things (the route, its unease, a teammate's part done) by running a `playbook …` line in the shell, such as `playbook route lone-wolf single coherent change`. Playbook's hook reads the line before it runs and shows you the result, including when it shares a command with others, such as `npm test && playbook rethink split the module`. The `playbook` command the plugin puts on the shell's path does nothing itself, so the line stays harmless even if the hooks aren't loaded. `playbook help` prints the usage, and `playbook status` prints what Playbook knows: the mode, any open regroup and who has aligned, and your own declaration.

Everything below is one of those jobs done properly, and they all matter; the detail on each is [further down](#in-more-detail).

## Commands

Start with `/playbook:hello`. It says hi, reports Playbook's pulse (whether it's active, the confirmed goal, the current mode, the unease score, the model split, offline on or off) and, the first time on a machine, offers a read-only check for plugin conflicts. It's also where offline notifications get set up. Run it whenever you like.

The rest are verbs. Each ships as its namespaced `/playbook:*` form, which always works, because Claude Code namespaces every plugin command. The plain name in the left column is an optional convenience: on first run (or any time you run it) `/playbook:setup` offers to install the bare `/brainstorming`, `/debug` and friends as standalone commands that point straight back at the plugin. Where another tool already owns a plain name, setup leaves that one alone and the `/playbook:*` form still covers it.

| Bare alias       | Always available            | What it does                                                 |
| ---------------- | --------------------------- | ------------------------------------------------------------ |
| `/brainstorming` | `/playbook:brainstorming`   | explore options, ask sharp questions, paint the picture, converge (also fires for fuzzy work) |
| `/offline-mode`  | `/playbook:offline-mode`    | turn on offline behaviour and notifications for this run     |
| `/worktrees`     | `/playbook:worktrees`       | isolate a separate Claude Code session in `.worktrees/` with its own branch and instance number |
| `/workflow`      | `/playbook:workflow`        | ⚙️ run this task as a dynamic workflow, carrying the North Star and the model rule into the script |
| `/fix`           | `/playbook:fix`             | 🦞 strict, production-ready fix protocol, typed for the stack and validated at the boundaries |
| `/debug`         | `/playbook:debug`           | 👾 a strict read, summarise, diagnose, confirm debugging cycle |
| `/review-panel`  | `/playbook:review-panel`    | ⚖️ four independent reviewers (🧬 architect, 💰 CTPO, 🌱 junior, ⚔️ devil's advocate) over a plan, design doc, diff or PR |

## The nine tenets

The doctrine underneath everything. They live in the engine skill, and the overlay and the per-prompt card point at them, so they survive compaction and stay one tug away at every decision.

1. **Remember what matters.** The goal you confirmed and your decisions; the hooks carry both.
2. **Ask early.** In one batch, the mode pick included, and again whenever a choice is yours.
3. **Team of equals.** Peers argue on reasoning, not rank; nobody outranks your decisions.
4. **Unease is scored from evidence.** Rethink, then a judge, then you.
5. **Offline mode is opt-in.** Enabled per run, never assumed.
6. **Ready for production.** No scaffolding vocabulary or comment sludge in shipped code.
7. **Compaction is safe mid-task.** At a natural finish, start fresh with a handover.
8. **The simplest design wins.** The one that meets your decision.
9. **Parallel hands, not rushing.** Deliver the spirit of what you asked for: more only when the goal needs it; a minor unrelated fix or a nice-to-have is offered as an extension once the work is delivered. Living with a risk you accepted is not partial work.

## In more detail

### 🚦 Choosing the right way to run the work

Playbook never picks the mode for you. Before non-trivial work it proposes a goal and ranks every available mode, best first, each with one line on why it sits in that position, and marks the top one **(Recommended)**. You choose in an interactive picker, which asks as `Goal: <the goal> · Mode:` with the top four as the options and a fifth, if available, named in the question so you can type it. It's batched with any other early questions. Your pick confirms the goal and is recorded as a decision.

- It asks only when two or more modes make sense. When only one does, it just declares the route on its one line.
- Only the main thread asks. Helpers inherit the mode you picked.
- If you pick **workflows**, Playbook first settles the plan with you, because a workflow can't take your input once it's running. Then it asks you to reply **"use ultracode"**, typed: Claude Code treats that word in a typed message as opting the turn into workflows. Playbook checks Claude Code's record of the opt-in before the workflow starts. If it's missing, you're asked again, and from the second miss you're asked to run `/effort ultracode` instead, with a warning that it stays on for the session and a reminder to switch back to your earlier effort afterwards. The status line reads `workflows (awaiting opt-in)` until the workflow starts.
- The picker also asks who oversees the work: **You'll oversee**, **Defer to a judge after 10 mins waiting**, **Defer to a judge after 30 mins waiting** or **Autonomous development**. Your answer switches offline behaviour on or off by itself. While a judge oversees, no question ever opens a dialog that could block the run. With a 10 or 30 minute wait, Playbook pushes each question to your phone, asks it in the chat too, and waits that long for your typed reply before a judge takes over. With autonomous development, it takes the recommended answer, has a judge check anything you might reverse, and logs it without alerting you. With a judge overseeing, a workflows run is likely to launch many workflows while you're away, so Playbook asks you to run `/effort ultracode` before you go, instead of typing "use ultracode" each time, and reminds you to switch back afterwards. If it's still off when the workflow is ready, it takes the next mode and logs why.
- When only one mode makes sense and work is dispatched, helpers carry no goal rather than a stale one. That weakens the goal guard for that case, and you've accepted the trade.

The ranking starts from what kind of work it is, then its size and coupling. Each mode is just a way Claude Code already works, named so you can see the choice being made. The whole choice in one breath:

> **Single-thread work → 🐺. Repetitive work and exploration → 🐜. Small feature work across specialisms, or a fast kickoff → 🤝. Most medium to large feature work → ⚙️. New MVPs and big projects that must be right and scale → 🏗️.**

| Marker | Mode        | Claude Code primitive | When it runs                                                 |
| ------ | ----------- | --------------------- | ------------------------------------------------------------ |
| 🐺      | `lone-wolf` | main thread           | quick fixes, small contained changes, and coupled work one mind can hold when one worker won't take too long (or you've approved one worker for a cleaner architecture) |
| 🐜      | `interns`   | parallel **subagents**    | repetitive work and exploration over a set of defined changes, up to about ten units, each an unnamed background Sonnet helper that owns its files and reports once |
| 🤝      | `hackathon` | agent **teams**           | small to medium feature work across specialisms (say iOS, Android and backend) that must keep talking, or a fast project kickoff; the lead also talks to you |
| ⚙️      | `workflows` | dynamic workflows     | most medium to large feature development, planned up front and built and checked in stages; coupled work too big or too slow for one worker; more than about ten repetitive units |
| 🏗️      | `gsd`       | [GSD](https://github.com/open-gsd/gsd-core)                   | big project development where reliability and scale matter most and more planning and review time is fine; the usual pick for a new MVP, though not for feature development unless you ask for it |

<details>
<summary>View more detail on each of these execution modes:</summary>
<ul>
<!-- lone-wolf -->
<li>🐺 lone-wolf</li>
<ul>
	<li>TL;DR: One mind on one thread, for quick fixes, small contained changes, and coupled work that one head should hold.</li>
	<li>Reach for it when splitting the work would shred it. Coupled work stays here when one worker won't take too long, or when you've approved one worker knowing it may take longer because it's architecturally better. Sounds like: "fix this failing test", "rename this and update the call sites", "rewrite the parser's state machine".</li>
	<li>Note on routing bias: Claude's comfort zone is doing everything itself, which quietly turns separable work into slow serial work. Playbook prices helpers on what they actually cost (a brief, not a hire) and counts finishing sooner as a real routing input.</li>
</ul>
<!-- interns -->
<li>🐜 interns</li>
<ul>
	<li>TL;DR: Up to about ten cheap, obedient hands, parallel Sonnet helpers, each handed one brief that says exactly what to change or what to look at.</li>
	<li>Reach for it for repetitive edits, research sweeps and code crawls over a defined set of changes. It isn't for feature development: that's workflows or hackathon. Past about ten units, the reports flood the main thread, so it becomes workflows. While lanes run, the main thread takes no lane of its own, so it's free to take each report as it lands. Sounds like: "add a usage example to every command doc", "check these eight packages for the deprecated API".</li>
</ul>
<!-- hackathon -->
<li>🤝 hackathon</li>
<ul>
	<li>TL;DR: A small crew of specialists, such as backend, web and iOS, each owning one part and talking directly while they build, like a few friends at a hackathon. One person takes more of a leadership role (the lead talks to you and builds too), but everyone works together.</li>
	<li>Reach for it for small to medium feature work split across platforms or specialisms that must keep talking, such as one feature landing on iOS, Android and the backend at once, or to kick off a whole project fast when time matters more than polish. Nothing big: a large build is workflows or gsd. Teammates message each other directly, and a change to the shared interface pauses everyone's edits until the whole crew has talked it through and approved it, so there's no stream of refused edits.</li>
	<li>It needs the agent-teams flag switched on, and it's the mode where Claude hands over the most control. Sounds like: "ship the backend, iOS and Android parts of this feature together", "hack together a demo of this app's server, client and bot".</li>
</ul>
<!-- workflows -->
<li>⚙️ workflows</li>
<ul>
	<li>TL;DR: One mind writes the plan, a script runs it in stages, and the bulk stays out of the main context.</li>
	<li>Reach for it for most medium to large feature development that can be planned up front, then built and checked in stages; for coupled work too big for one context or too slow with one worker, run as a chain of steps one after another; and for more than about ten repetitive units. Not for small features. A workflow can't take your input mid-run, so its plan is settled with you first. Sounds like: "add team accounts with invites and roles", "move this module onto the new storage layer in stages", "a tailored note for every built-in Node module".</li>
	<li>Workflows are opt-in: you pick them, then reply "use ultracode". `/workflow` stays as your direct path.</li>
</ul>
<!-- gsd -->
<li>🏗️ gsd</li>
<ul>
	<li>TL;DR: The long game: big project development where reliability and scalability matter most, with lots of planning and review steps and state that outlives each session.</li>
	<li>Reach for it for building from scratch when it has to be right, or later, when part of a project needs a firm foundation, such as a hackathon demo's backend rebuilt to scale. It's the usual pick for a new MVP. For feature development it isn't the first recommendation, but Playbook ranks it when it's worth a look, and you can always pick it. Sounds like: "build me this product properly from scratch", "turn this demo's backend into something we can ship".</li>
</ul>
</ul>
</details>

### 🧘 Calm compaction

Native auto-compact is seamless: it summarises the conversation and the session simply keeps going. The platform never actually stops you. What makes agents wrap up early and break runs you left going is a context-warning hook (most commonly GSD's `gsd-context-monitor`) quietly injecting "you're running low, prepare to pause" into the model. Claude believes it and downs tools.

Playbook fixes this in one move:

- It spots competing context warnings and offers, once, to take the context channel over. Only with your consent, and it backs up your settings first. And ownership is re-verified rather than trusted: if a plugin update ever re-registers the warning hook, Playbook notices at the next session start and offers to quiet it again.
- From then on it's the single calm voice in the room: auto-compact is safe, nothing important is lost, keep going.
- After a compaction it brings back your confirmed goal, your own words behind it and your decisions, and picks the in-flight work straight back up.
- Compaction is safe mid-task. At a natural finish above about 200k tokens of context, Playbook nudges towards a fresh session with a short handover, which costs less than carrying on.
- If a long-lived terminal hits the stale subagent cap, Claude offers a fresh session with a handover first and `claude -r` second; offline, it carries on via Workflows.

### 🪙 The right model for the job

> 📚 Playbook dispatch: build the export lane · sonnet

- **Sonnet builds and checks. Opus plans and judges.** Stuck? Go up a tier. No agent exists only to watch another.
- The test is what happens when Claude is wrong: a loud, locally fixable mistake can run on a lighter model; a quiet mistake that propagates into other agents keeps the flagship.
- It's doctrine rather than a mode you enter, applied inside every workflow stage and nested subagent. The dispatch guard shows each dispatch's model on one line (as above), so Claude prints no marker of its own.

### 📌 Your decisions win

> Quote them; never credit the user with a rule they didn't state.

- Every answer you give in a picker or question, and every decision you state in your own words, is recorded verbatim and sent into every helper, workflow agent and teammate.
- Your decisions outrank Claude, and every helper, reviewer, judge and reviser. A conflict with one is a question for you, never a change.
- A standing rule sits above everything: if a choice could leave the work short of the goal, or go against one of your decisions, Claude stops and asks.

### 🎯 The North Star

The goal is set only when you confirm it in the picker, and never inferred from a slash command or an old message. Your own messages behind it are saved word for word and come back after a compaction. The one-line card asks every prompt whether this is new work and the goal is still right; new work re-runs the picker. After a long gap, or a merge, the goal is marked stale, and dispatches are refused until you confirm it again. When the work is met, Claude runs `playbook done`, and nothing is dispatched until a new goal is confirmed, apart from read-only lookups.

### 🌡️ Knowing when it's out of its depth

> 🌡️ **Playbook** `unease: concerned` *the same test failed three times*

- Playbook keeps a running unease score from evidence: your frustration and corrections, tests failing and failing again, tool failures in a row, long grinds with nothing landing, and a review round repeated. A pass or a commit brings it down, and your go halves it. Claude can add to it with `playbook unease <level> <reason>`, never subtract.
- **Uneasy** means stopping to rethink before the next edit or dispatch. **Concerned** means consulting a judge (a fresh Opus subagent, or Codex) before more edits or dispatches. **Alarmed** means a judge too, or asking you if you're here; offline, it pushes to your phone, waits your window and takes an outside judge's view. Until the level is answered, new edits and new helpers are held.
- The score is evidence for a stop, never proof of success or failure. Whether a stop was the right place to have stopped is your call.
- It only speaks when the score crosses a level, so its silence tells you just as much as its voice.
- With offline mode on, a rising score can go a step further and actually notify you.

### ⚖️ Weighing every review

> ⚖️ **Playbook** weighed (fix): fixing the crash, listing the slow sort as a possible extension, no further round

- When a review's report comes back to the main thread (a reviewer, an audit, a verify pass, or a review workflow), Playbook pauses Claude before it acts. Edits, shell writes and new helpers are held until it records its call; reading, tests, messages and questions still run.
- The pause reminds Claude that a review almost never comes back empty and that a bug found is not always a bug to fix, and asks whether the work still delivers the spirit of your request, which can mean less scope or more.
- A fix is recorded with `playbook weigh fix "<call>"` and the work carries on. Anything bigger than a fix (a new approach, a redesign, more scope) is recorded with `playbook weigh bigger "<assessment>"` and stays held until a judge signs it off or you do, in a picker or with a typed answer Claude records in your own words. A passing "thanks" is not sign-off.
- A judge may sign off on scope your goal needs and that is achievable, never on going against one of your decisions. A minor unrelated bug fix or a nice-to-have waits until the work is delivered, then comes to you as a possible extension.
- Pausing more often than strictly needed is the accepted cost; it is far better than Claude never finishing after a review.

### 🛂 Guards on dispatch

- Every dispatch needs an explicit `model`, and a brief that names a North Star must match the confirmed one.
- Outside a hackathon, a named helper or a team is refused: interns are unnamed background helpers that report once.
- The third round of the same review is held until you or a judge has answered, under the review rules: only a bug earns another round, and if two rounds still find bugs, stop reviewing and take a beat: simplify, accept a contained risk, or ask. Anything bigger than a fix needs a serious assessment and sign-off from a judge or you; on money or security code, Claude asks.
- You see one line per dispatch, its description and its model.

### 🔕 Teammate idle notices

Hackathon teammates declare their state with a `playbook` shell command, and the idle hook acts on it when a teammate is about to go idle:

- **Part done:** a teammate that declares `playbook part-done <name>`, outside a regroup, has its work stopped at its next idle, and the lead shuts it down once its part is integrated. A follow-up after that needs a fresh teammate.
- **Waiting:** `playbook waiting <name> on <colleague> <what>` lets it idle until it is messaged.
- **Open items:** otherwise a teammate with unfinished work is sent back to it, three pushes in a row at most, so a stuck one doesn't spin and the lead isn't woken for nothing. During a regroup nobody is sent back, since every edit is held.
- **Regroup:** the shared interface is kept by Playbook outside your project, never in your repository. It is changed in its draft and put in place with `playbook publish <what changed>`, so a typo costs nothing. Publishing holds every edit, through the shell as much as the Edit tool, until each crew member has read the agreed version and run `playbook aligned <name>`. Every crew member is told when the hold lifts, and the last to approve messages everyone `RESUME`.
- **Message priorities:** a teammate only receives a message when its turn ends, so the first word of a message says how hard it interrupts. `SOON:` tells the receiver at its next step to read it before its next piece of work, `ASAP:` to stop as soon as it reasonably can and read it, and `URGENT:` ends the receiver's turn so the message arrives at once (one colleague only, never the lead, and at most once in 10 minutes from the same sender, each one logged). `REGROUP:` and `RESUME:` belong to the regroup. One tag per message.

### 📊 Status line

Playbook can show the mode and any unease on your status line, for example `🤝 hackathon · 💬 14 crew messages · 🟨 uneasy`. `/playbook:setup` offers it with your consent and a backup of your settings: it wraps whatever status line you already have, runs it first, and appends Playbook's fields: the mode with its emoji; in a hackathon, how many messages the crew has sent each other (`❌ no crew messages yet` until the first), since those never appear in the lead's terminal; and the unease level, shown only once it reaches uneasy, concerned (🟧) or alarmed (🟥). It refreshes every 5 seconds so the count stays current while the lead waits. The way back is in the setup output, and a GSD update that replaces the wrapper is noticed at the next session start.

### 📴 Offline mode

For when Claude is working and you aren't watching, whether that's overnight or just while you're in a meeting. When Claude needs you it:

1. **Pulls you back** with a notification, and waits the window you set.
2. **Takes an outside judge's view** if you don't answer inside it (for example Codex), with a question about scope or one of your decisions always waiting for you instead.
3. **Makes the call and logs it,** writing every decision taken without you into a morning-readable HTML log. Questions such as the goal-and-mode picker take the top recommendation and log it.

Delivery is mechanical. While offline mode is on, a hook sends the push itself whenever Claude actually needs you: a permission prompt, a tool asking for input, a usage limit that stops the run, or a reply that asks you something, with that question as the notification. A reply that simply finishes is logged rather than pushed, so a ping always means you're needed. Every send and every decision taken without you lands in a durable log file as it happens, and the morning HTML is rendered from that file rather than from memory.

Notifications go through **ntfy or Pushover**, whichever you pick at setup, and you configure it once for the whole machine so every project can use it, with a per-project override when one needs its own. Pushover is the one for a guaranteed wake-up: it punches through iOS Do Not Disturb once you enable Critical Alerts in its app. ntfy is the free, self-hostable, Android-friendly option.

It's built to sit alongside Claude's native `/goal`, which owns the "am I actually finished" loop while offline mode holds the North Star, the pull-back, the score's offline path and the log.

### 🧭 Brainstorming

Not every job starts as a clear instruction. For the fuzzy front end, brainstorming:

- explores the options rather than grabbing the first one,
- asks you the sharp questions early instead of guessing,
- paints the picture of where it's heading, and converges on a plan before any code is written, then hands over to the mode picker.

It fires when a request is open-ended, or call it yourself with `/brainstorming`.

### 🌿 Worktrees for parallel sessions

For when **you** want to run several Claude Code sessions at once. This is for humans; it's not subagent parallelism!

- Creates a worktree under `.worktrees/` on its own branch, with an instance number.
- Offsets every resource that has to be isolated by that number: a per-instance Docker database, a dev-server port, a cache namespace.
- Any number of sessions run side by side without treading on each other; where there's nothing to isolate, it falls back to plain branch isolation.

### 🤐 No comment sludge

Claude loves explaining itself in the margin. Spend fifty minutes chasing a one-line bug and it wants to leave four lines of commentary next to the fix, and the result is a codebase where half of what you read is narration of what the line below already says. Telling it not to doesn't hold: the instruction is read once and the habit reasserts itself every time it writes a line.

So Playbook refuses the comment as it is being written, in any language, before it reaches your file. It reads only the text an edit inserts, so deleting comments is always allowed and code you never touched is never held against you.

Write none by default. A one-line fix gets a one-line change, and the time you spent finding the bug is not a reason to memorialise it. If the surrounding code carries no comments, yours has to be so incredibly vital and unclear that it deserves to be the only comment in the entire file.

A comment that genuinely earns its place says so out loud:

```swift
/// @nonobvious(forced-by) Safari collapses the flex gap here, so the row needs a spacer
```

The category comes from a closed set, and each one is a claim you have to mean:

| category | the claim |
|---|---|
| `forced-by` | an outside system made the code this shape |
| `mirrors` | it must stay in sync with a named place |
| `must-hold` | a condition the types and tests do not enforce |
| `deliberately-missing` | why the expected thing is not here |
| `means` | what a value means beyond its type |

There is deliberately no category for "explains what the code does". That reflex has nowhere to file itself, which is the entire point. Banners, `Step 2:` labels, work narration and any comment restating the line beneath it are refused whether they carry a tag or not, and an edit may never add more comment lines than lines of code.

A comment sitting at the end of a line of code is judged on what it says rather than on where it sits, so it needs no tag and is refused only when it restates the line it belongs to, or is one of the shapes above. This is the one place the short form earns its keep, because the thing worth saying is usually a unit, a bare value's meaning, or the intent behind an opaque literal:

```ts
const LOOP_MS = 1.5 * 3_600_000;            // 1.5 hours in ms
const EASING = [0.16, 1, 0.3, 1] as const;  // expo ease-out
const CATEGORY_ID = 39;                     // Funding
```

It needs `jq` and `awk`, and stays out of the way of generated trees, vendored dependencies, prose and config.

### 🧰 First-run setup

The first time you type `/playbook:hello` on a machine, it introduces itself and asks permission before it does anything else. Say yes and it takes a quick read-only look around. A few plugins out there genuinely fight Playbook (the classic ones re-prompt Claude every time it tries to stop, or scare it near the context limit), so it spots those, shows you the evidence, and offers to sort them out. It'll also make sure you've got `jq`, offer to set up notifications if you fancy offline mode, and offer to install the bare command aliases (`/fix`, `/debug` and the rest) so you don't have to type the `/playbook:` prefix, skipping any name another tool already owns.

Nothing happens without your say-so: it asks about each change, backs up your settings first, and only ever disables, never uninstalls. It's biased towards leaving your stuff alone, and at the end it offers a wider health check of your Claude Code setup, which you're free to decline. Run `/playbook:setup` whenever you want to do it again.

### 👻 It writes nothing into your project

- No `.playbook/` directory, no anchor file, no state in your repo. The goal, the routing and the unease score live in the hooks' own state outside your project, steered from the hook payloads.
- Everything Playbook keeps lives under `~/.local/state/playbook/` (or `$XDG_STATE_HOME/playbook/` if you set it), outside your project and outside `~/.claude`, where Claude Code would ask before every write. Per-session state, the hackathon crew's shared interface included, sits in `sessions/` and is cleaned up on its own after 7 days; your one-time setup marker, the status line files and, by default, your notification config sit at the top level. Playbook 2.8 kept these in `~/.claude/playbook/` and `~/.claude/hook-state/playbook/`; they are copied over the first time 3.0 runs, and the old folders are left for you to delete.
- The only things that ever land in your project are the ones you opt into: a per-project notification override under the gitignored `.claude/playbook/`, and your `.worktrees/`.

## Licence

MIT.
