# Playbook

`@lujstn/playbook` is a small, opinionated steering layer for Claude Code that forces Claude to keep the original goal in sight, **keeps track of its own unease** as it works, **asks for help** (with a **notification**) when that unease builds, decides when to reach for **workflows, teams or subagents** on its own, and adds proper new commands for **brainstorming** and a dedicated **offline mode** for when it's running without you. In other words, all the stuff I think Claude Code should have.

It stays out of the way, only pops up when needed, and will always tell you what matters in one line.

## Install

Playbook is a Claude Code plugin, so setup is two lines inside Claude Code:

```
/plugin marketplace add lujstn/playbook
/plugin install playbook
```

You'll know it's live when you see `📚 Playbook skills available in this session` in your chat. Say `/playbook:hello` any time to have it introduce itself, check its pulse, and (the first time on a machine) look for plugin conflicts.

You don't need to install anything else, but it's worth having `jq` for goal recovery and smooth compactions. It's on most machines already, and Playbook will tell you if it isn't.

Playbook prioritises native Claude development flows, with the one exception of large MVPs, where I'd point you at the [GSD](https://github.com/open-gsd/gsd-core) framework, which you install separately from their repo.

## How it works

Playbook is a set of Claude Code hooks and skills. There's no runtime, no daemon, and nothing written into your working tree. When a session starts, and again after every compaction, it does four things:

1. **Re-states the goal.** It recovers your original request from the transcript and keeps a one-line North Star in front of Claude at every decision.
2. **Picks how to run the work,** judged on how separable and durable it is rather than how big it looks.
3. **Keeps Claude calm near the context limit,** so it doesn't do less or stop early as the window fills.
4. **Watches its own unease** and speaks up, visibly, only when something genuinely starts going wrong.

None of it happens behind your back. Every choice is announced on one branded line, part nudge, part heartbeat, so you always know Playbook is alive and would spot it instantly if it vanished:

> 🐺 **Playbook** `lone-wolf` *single coherent change, no extra hands*

Everything below is one of those jobs done properly, and they all matter; the detail on each is [further down](#in-more-detail).

## Commands

Start with `/playbook:hello`. It says hi, reports Playbook's pulse (whether it's active, the current mode, the model split, offline on or off) and, the first time on a machine, offers a read-only check for plugin conflicts. It's also where offline notifications get set up. Run it whenever you like.

The rest are verbs. Each ships as its namespaced `/playbook:*` form, which always works, because Claude Code namespaces every plugin command. The plain name in the left column is an optional convenience: on first run (or any time you run it) `/playbook:setup` offers to install the bare `/brainstorming`, `/debug` and friends as standalone commands that point straight back at the plugin. Where another tool already owns a plain name, setup leaves that one alone and the `/playbook:*` form still covers it.

| Bare alias       | Always available            | What it does                                                 |
| ---------------- | --------------------------- | ------------------------------------------------------------ |
| `/brainstorming` | `/playbook:brainstorming`   | explore options, ask sharp questions, paint the picture, converge (also fires on its own for fuzzy work) |
| `/offline-mode`  | `/playbook:offline-mode`    | turn on offline behaviour and notifications for this run     |
| `/worktrees`     | `/playbook:worktrees`       | isolate a separate Claude Code session in `.worktrees/` with its own branch and instance number |
| `/workflow`      | `/playbook:workflow`        | ⚙️ run this task as a dynamic workflow, carrying the North Star and the model rule into the script |
| `/fix`           | `/playbook:fix`             | 🦞 strict, production-ready fix protocol, typed for the stack and validated at the boundaries |
| `/debug`         | `/playbook:debug`           | 👾 a strict read, summarise, diagnose, confirm debugging cycle |
| `/review-panel`  | `/playbook:review-panel`    | ⚖️ four independent reviewers (🧬 architect, 💰 CTPO, 🌱 junior, ⚔️ devil's advocate) over a plan, design doc, diff or PR |

## The nine tenets

The doctrine underneath everything. The hooks carry these into the main thread and every subagent, so they survive compaction and reach helpers without any skill text being re-read.

1. **Remember what matters.** The North Star is re-anchored after every compaction and passed into every dispatch.
2. **Front-load the questions.** Ask the batch once, early, so the rest can run unattended.
3. **Team of equals.** A lead coordinates; it doesn't get the last word.
4. **Unease.** Restated only when it rises, and measured against the whole project, not just the task at hand.
5. **Offline mode is opt-in.** Enabled per run, never assumed.
6. **Ready for production.** No scaffolding vocabulary or comment sludge in shipped code.
7. **Ride the compaction, do not fear it.** A compaction is a steered breath, not a wipe.
8. **Less is more.** The cheapest sufficient mode and model; longer thinking, shorter output.
9. **Speed comes from more hands, not from rushing.** Cutting a job short to save time is off the table.

## In more detail

### 🚦 Choosing the right way to run the work

Work is routed on **separability and durability, not size**. Size only decides whether to break the work up first. Each mode is just a way Claude Code already works, named so you can see the choice being made. The whole choice in one breath:

> **Quick or coherent → 🐺. A list of separable chores → 🐜. A living build that needs a crew of different experts → 🤝. A frozen plan at parallel scale → ⚙️. A multi-session MVP → 🏗️.**

| Marker | Mode        | Claude Code primitive | When it runs                                                 |
| ------ | ----------- | --------------------- | ------------------------------------------------------------ |
| 🐺      | `lone-wolf` | main thread           | quick or coherent work that one mind should hold from start to finish *(Claude's solo bias)* |
| 🐜      | `interns`   | parallel **subagents**    | a list of separable chores, each handed to a Sonnet helper as one crisp brief |
| 🤝      | `hackathon` | agent **teams**           | an expert crew sprinting towards a shared north star: each peer owns their specialism, and they **actively communicate** to converge |
| ⚙️      | `workflows` | dynamic workflows     | lone-wolf thinking at parallel scale: a medium-or-larger plan, frozen before launch, executed wide *(Claude's workflow bias under `/effort ultracode`)* |
| 🏗️      | `gsd`       | [GSD](https://github.com/open-gsd/gsd-core)                   | a full MVP spanning multiple sessions, a day's work or more, with plans that must survive between them |

<details>
<summary>View more detail on each of these execution modes:</summary>
<ul>
<!-- lone-wolf -->
<li>🐺 lone-wolf</li>
<ul>
	<li>TL;DR: One mind on one thread, for work that is quick, or so coherent that a single head should hold all of it from start to finish.</li>
	<li>Reach for it when the thinking *is* the work and splitting it would shred it. The wrong fit is anything with a hidden list inside: this is Claude's comfort zone, and the smell of over-picking it is one mind grinding through separable items one at a time. Sounds like: "fix this failing test", "rename this and update the call sites", "explain this module".</li>
	<li>Note on routing bias: this is the <strong>solo bias</strong>, Claude's comfort zone of doing everything itself, which quietly turns separable work into slow serial work. Playbook treats it as a failure rather than a preference, so it prices staffing on what helpers actually cost (a brief, not a hire) and treats finishing sooner and keeping the main thread sharp as real routing inputs.</li>
</ul>
<!-- interns -->
<li>🐜 interns</li>
<ul>
	<li>TL;DR: Many cheap, obedient hands, parallel Sonnet lone-wolves, each handed one crisp brief, racing through separable chores so the whole batch lands sooner.</li>
	<li>Reach for it for research sweeps, code crawls, repetitive edits and bulk data changes: chains of action that need following, not debating. The wrong fit is pieces that must negotiate with each other, or units you can't specify in a single brief. One hand per genuine unit, never a headcount. Sounds like: "write tests for these eight modules", "check all fifteen repos for the deprecated API", "apply this refactor everywhere".</li>
</ul>
<!-- hackathon -->
<li>🤝 hackathon</li>
<ul>
	<li>TL;DR: A cross-communicating crew of experts, each a specialist owning their own piece, talking simply and often, shipping one shared MVP faster than heavyweight process ever could.</li>
	<li>The analogy is literal. The people at a hackathon are already brilliant at their day jobs, and for money or love of the game they build in a weekend what a big organisation takes months to deliver, because each of them builds in their own field and they coordinate by actually talking rather than by process. That's this mode: cross-functional specialists (server, client, bot; backend, frontend, tests), one shared North Star, simple communication, fast iteration.</li>
	<li>Reach for it when a real build is still taking shape and spans specialisms that must land together. The tie-break against 🐺 is spine density: a thin shared interface over deep pieces is crew-shaped, and a backend platform, a web UI and a native app landing together is the canonical case; only when the interface effectively *is* the build does one mind win. The wrong fit is mechanical chores (that's interns), a plan already frozen (that's workflows), or a solo methodical build across sessions (that's gsd, this mode's single-mind sibling).</li>
	<li>It needs the agent-teams flag switched on, and it's the mode where Claude hands over the most control, which is exactly why it never picks it unprompted; Playbook's job is to license that trust when the build deserves it. Sounds like: "build this three-part app and work the protocol out as you go", "ship the backend, the web app and the mobile app for this feature together", "you three each take a layer and argue the interfaces out amongst yourselves".</li>
</ul>
<!-- workflows -->
<li>⚙️ workflows</li>
<ul>
	<li>TL;DR: Lone-wolf thinking at parallel scale, where one mind writes a frozen plan, a script executes it wide, the bulk stays out of the context and control stays at home.</li>
	<li>Reach for it when the steps are known before launch and the scale is medium or larger: volume beyond one context, or verification as the deliverable (generate, then independently check). The wrong fit is anything that will need re-planning mid-run, because a workflow cannot change its mind; the tie-break against 🤝 is one question: *will the plan survive contact unchanged?* Workflows are how the big organisation ships the frozen plan; hackathon is the crew of experts outbuilding it while the plan is still alive. Ultracode over-picks this mode, so a workflow must earn its place, never inherit it. Sounds like: "a tailored, fact-checked note for every built-in Node module", "migrate four hundred files with a verify stage".</li>
	<li>Note on routing bias: this is the <strong>workflow bias</strong>, reaching for a frozen fan-out because ultracode makes it easy. Playbook assumes the baseline is ultracode (which we recommend, so that Claude has permission to launch dynamic workflows on its own), and that power is exactly why the discipline here is restraint rather than reach. The tool is sized to the task, never to the mode, so a read-and-fix over a known set of files is `lone-wolf` or a handful of `interns`, never a twenty-agent swarm, and "ultracode is on" is never by itself a reason to fan out. When ultracode is off, `workflows` becomes opt-in, and Playbook points you at `/workflow` rather than reaching for it itself.</li>
</ul>
<!-- gsd -->
<li>🏗️ gsd</li>
<ul>
	<li>TL;DR: The long game, a full MVP, a day's work or more, spanning multiple sessions, with plans and state that must outlive each one.</li>
	<li>Reach for it for greenfield products and anything that would die if the session were cleared. The wrong fit is anything that finishes inside one session, however big it feels. Sounds like: "build me this product from scratch", "take this idea to a working MVP".</li>
</ul>
</ul>
</details>

### 🧘 Calm compaction

Native auto-compact is seamless: it summarises the conversation and the session simply keeps going. The platform never actually stops you. What makes agents wrap up early and break runs you left going is a context-warning hook (most commonly GSD's `gsd-context-monitor`) quietly injecting "you're running low, prepare to pause" into the model. Claude believes it and downs tools.

Playbook fixes this in one move:

- It spots competing context warnings and offers, once, to take the context channel over. Only with your consent, and it backs up your settings first.
- From then on it's the single calm voice in the room: auto-compact is safe, nothing important is lost, keep going.
- After a compaction it re-anchors on your original request and the North Star, and picks the in-flight work straight back up.

### 🪙 The right model for the job

> 🪙 **Playbook** `sonnet` *bulk implementation under a locked spec*

- **Sonnet executes. Opus plans, reviews, and thinks hard.** Stuck? Go up a tier.
- The test is what happens when Claude is wrong: a loud, locally fixable mistake can run on a lighter model; a quiet mistake that propagates into other agents keeps the flagship.
- It's doctrine rather than a mode you enter, applied inside every workflow stage and nested subagent, and announced (as above) whenever a spawn drops to a cheaper tier.

### ⏱️ Honest time estimates

> A plan estimated at "about two hours" landing in thirteen minutes is not a fluke, it's the constant.

- **Form the human-engineer estimate, then divide by ten**, and give a range: a "2 hours" feel becomes "10-15 min". Agent intuition is trained on humans estimating human effort, then executes at machine speed; measured, the bias is uniform across subtasks, so one scalar corrects it.
- External-system waits (CI, deploys, rate-limited APIs, paid crawl or LLM runs) are never divided: they're items × rate, and hours are a legitimate answer. Commands with already-observed durations are added at face value.
- User round-trips are a count, never a duration, and an actual landing outside the stated range gets said out loud so the divisor can be recalibrated.

### 🌡️ Knowing when it's out of its depth

> 🌡️ **Playbook** `unease: watchful` *three edits in a row failed to apply*

- Playbook holds a quiet sense of how uneasy Claude is, measured against the whole project rather than just the task in front of it.
- It only speaks when the worry genuinely climbs, so its silence tells you just as much as its voice.
- A standing rule sits above everything: if a decision could compromise the goal itself, stop and ask you first.
- With offline mode on, rising unease can go a step further and actually notify you, rather than stalling until you next look.

### 📴 Offline mode

For when Claude is working and you aren't watching, whether that's overnight or just while you're in a meeting. It runs a "wait-then-escalate" ladder:

1. **Pulls you back** with a notification when the work genuinely blocks.
2. **Falls back to an external manager** if you don't answer inside the window you set.
3. **Makes the call and logs it** if it must, writing every decision taken without you into a morning-readable HTML log.

Notifications go through **ntfy or Pushover**, whichever you pick at setup, and you configure it once for the whole machine so every project can use it, with a per-project override when one needs its own. Pushover is the one for a guaranteed wake-up: it punches through iOS Do Not Disturb once you enable Critical Alerts in its app. ntfy is the free, self-hostable, Android-friendly option.

It's built to sit alongside Claude's native `/goal`, which owns the "am I actually finished" loop while offline mode holds the North Star, the pull-back, the ladder and the log.

### 🧭 Brainstorming

Not every job starts as a clear instruction. For the fuzzy front end, brainstorming:

- explores the options rather than grabbing the first one,
- asks you the sharp questions early instead of guessing,
- paints the picture of where it's heading, and converges on a plan before any code is written.

It fires on its own when a request is open-ended, or call it yourself with `/brainstorming`.

### 🌿 Worktrees for parallel sessions

For when **you** want to run several Claude Code sessions at once. This is for humans; it's not subagent parallelism!

- Creates a worktree under `.worktrees/` on its own branch, with an instance number.
- Offsets every resource that has to be isolated by that number: a per-instance Docker database, a dev-server port, a cache namespace.
- Any number of sessions run side by side without treading on each other; where there's nothing to isolate, it falls back to plain branch isolation.

### 🧰 First-run setup

The first time you type `/playbook:hello` on a machine, it introduces itself and asks permission before it does anything else. Say yes and it takes a quick read-only look around. A few plugins out there genuinely fight Playbook (the classic ones re-prompt Claude every time it tries to stop, or scare it near the context limit), so it spots those, shows you the evidence, and offers to sort them out. It'll also make sure you've got `jq`, offer to set up notifications if you fancy offline mode, and offer to install the bare command aliases (`/fix`, `/debug` and the rest) so you don't have to type the `/playbook:` prefix, skipping any name another tool already owns.

Nothing happens without your say-so: it asks about each change, backs up your settings first, and only ever disables, never uninstalls. It's biased towards leaving your stuff alone, and at the end it offers a wider health check of your Claude Code setup, which you're free to decline. Run `/playbook:setup` whenever you want to do it again.

### 👻 It writes nothing into your project

- No `.playbook/` directory, no anchor file, no state in your repo. The goal, the routing and the unease all live in the conversation itself, steered by the hooks.
- One tiny throttle file lives at `~/.claude/hook-state/playbook/`, outside your project and cleaned up on its own. Your one-time setup marker and, by default, your notification config sit under `~/.claude/playbook/`, also outside any repo.
- The only things that ever land in your project are the ones you opt into: a per-project notification override under the gitignored `.claude/playbook/`, and your `.worktrees/`.

## Licence

MIT.
