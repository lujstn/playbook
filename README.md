# Playbook

`@lujstn/playbook` is a small, opinionated steering layer for Claude Code that forces Claude to keep the original goal in sight, **keeps track of its own unease** as it works, **asks for help** (with a **notification**) when that unease builds, decides when to reach for **workflows, teams or subagents** on its own, and adds proper new commands for **brainstorming** and a dedicated **offline mode** for when it's running without you. In other words, all the stuff I think Claude Code should have.

It stays out of the way, only pops up when needed, and will always tell you what matters in one line.

## Install

Playbook is a Claude Code plugin, so setup is two lines inside Claude Code:

```
/plugin marketplace add lujstn/playbook
/plugin install playbook
```

You'll know it's live when you see `📚 Playbook skills available in this session` in your chat.

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

Every command also answers to its namespaced `/playbook:*` form, which behaves identically; if another tool already owns the plain name, use that one.

| Command          | Alias                       | What it does                                                 |
| ---------------- | --------------------------- | ------------------------------------------------------------ |
| `/brainstorming` | `/playbook:brainstorming`   | explore options, ask sharp questions, paint the picture, converge (also fires on its own for fuzzy work) |
| `/offline-mode`  | `/playbook:offline-mode`    | turn on offline behaviour and notifications for this run     |
| `/worktrees`     | `/playbook:worktrees`       | isolate a separate Claude Code session in `.worktrees/` with its own branch and instance number |
| `/workflow`      | `/playbook:workflow`        | ⚙️ run this task as a dynamic workflow, carrying the North Star and the model rule into the script |
| `/fix`           | `/playbook:fix`             | 🦞 strict, production-ready fix protocol, typed for the stack and validated at the boundaries |
| `/debug`         | `/playbook:debug`           | 👾 a strict read, summarise, diagnose, confirm debugging cycle |
| `/playbook`      | `/pb`                       | a status heartbeat: whether Playbook is active, which mode, which model split, offline on or off; its first run also checks your machine for plugin conflicts |

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

Work is routed on **separability and durability, not size**. Size only decides whether to break the work up first. Each mode is just a way Claude Code already works, named so you can see the choice being made.

| Marker | Mode        | Claude Code primitive | When it runs                                                 |
| ------ | ----------- | --------------------- | ------------------------------------------------------------ |
| 🐺      | `lone-wolf` | main thread           | one coherent unit, no benefit from extra hands               |
| 🐜      | `interns`   | parallel subagents    | several independent sub-tasks; the helpers do not talk to each other |
| 🤝      | `hackathon` | agent teams           | coupled work in one shared codebase, where the peers need to message each other |
| ⚙️      | `workflows` | dynamic workflows     | many genuinely independent units, or a scale one context cannot hold, or work that needs independent verification |
| 🏗️      | `gsd`       | GSD                   | a whole MVP in an unknown area, with state that must survive across sessions |

The thing this fights hardest is over-reach:

- The assumed baseline is ultracode, where Claude can launch a whole dynamic workflow on its own, so the discipline that matters is restraint.
- The tool is sized to the task, never to the mode: a read-and-fix over a known set of files is `lone-wolf` or a handful of `interns`, never a twenty-agent swarm.
- "Ultracode is on" is never by itself a reason to fan out; a workflow has to earn its place with real volume, real scale, or a genuine need for independent verification.
- When ultracode is off, `workflows` becomes opt-in, and Playbook points you at `/workflow` rather than reaching for it itself.

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

Notifications go through **ntfy or Pushover**, whichever you pick at setup. Pushover is the one for a guaranteed wake-up: it punches through iOS Do Not Disturb once you enable Critical Alerts in its app. ntfy is the free, self-hostable, Android-friendly option.

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

The first time you type `/playbook` on a machine, it has a quick look around before doing anything else. A few plugins out there genuinely fight Playbook (the classic ones re-prompt Claude every time it tries to stop, or scare it near the context limit), so it spots those, shows you the evidence, and offers to sort them out. It'll also make sure you've got `jq`, and offer to set up notifications if you fancy offline mode.

Nothing happens without your say-so: it asks about each change, backs up your settings first, and only ever disables, never uninstalls. It's biased towards leaving your stuff alone, and at the end it offers a wider health check of your Claude Code setup, which you're free to decline. Run `/playbook:setup` whenever you want to do it again.

### 👻 It writes nothing into your project

- No `.playbook/` directory, no anchor file, no state in your repo. The goal, the routing and the unease all live in the conversation itself, steered by the hooks.
- One tiny throttle file lives at `~/.claude/hook-state/playbook/`, outside your project and cleaned up on its own, and the one-time setup marker sits under `~/.claude/playbook/`.
- The only things that ever land in your project are the ones you opt into: offline mode's notification config under the gitignored `.claude/playbook/`, and your `.worktrees/`.

## Licence

MIT.
