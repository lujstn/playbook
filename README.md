# Playbook

`@lujstn/playbook` is a native steering layer for Claude Code. It is invisible-but-visible: it activates on every session, steers Claude Code from the inside, and shows you what it is doing with a branded marker on every routing decision, but it never makes you pick a mode, never gates you behind a wizard, and never asks new questions just to function. It hops on top of native Claude Code, Superpowers and GSD and closes the specific places where their defaults fall short in practice, with the minimum mechanism.

The two things it cares about most: keep the original goal load-bearing across compaction, and route separable work for speed without ever rushing it.

## Install

```
/plugin marketplace add lujstn/playbook
/plugin install playbook
```

Then just work. Describe what you want in a normal sentence. Playbook activates at the start of any non-trivial work, announces how it is running the work, and stays out of your way.

## You can see it working

Every time Playbook routes work it prints one branded line, both as a nudge and as a heartbeat so you always know it is alive (and notice instantly if it ever vanishes):

```
🐺 Playbook · lone-wolf: single coherent change, no extra hands
```

When the model rule downshifts a spawn to save cost, it says so too:

```
🪙 executing on Sonnet: bulk implementation under a locked spec
```

## The five modes

Work is routed on **separability and durability, not size**. Size only decides whether to decompose first. Each mode is just how Claude Code already works, named so you can see the choice.

| Marker | Mode | Claude Code primitive | When it runs |
|---|---|---|---|
| 🐺 | `lone-wolf` | main thread | one coherent unit, no benefit from extra hands |
| 🐜 | `interns` | parallel subagents | several independent sub-tasks; helpers do not talk; includes the joint-leads to workers nested fan-out (e.g. 5 leads x 5 workers = 25, inside the depth-5 cap) |
| 🤝 | `hackathon` | agent teams | coupled work in one shared codebase; peers message each other |
| ⚙️ | `workflows` | dynamic workflows | separable work that needs real scale (dozens to hundreds of agents) or results kept out of context; opt-in via `/workflow` or the ultracode keyword |
| 🏗️ | `gsd` | GSD | a whole MVP in an unknown area; durable cross-session state |

The baseline is plain high-effort Claude Code, with no default mode. For separable work, `interns` runs directly (a few parallel subagents); `workflows` is the opt-in scale upgrade you trigger with `/workflow` (or by adding the keyword "ultracode" to a prompt), since the assistant cannot start a workflow on its own. When work is workflow-shaped, Playbook either runs interns and notes that `/workflow` would scale it further, or, for genuinely large work, points you at `/workflow`. It never gates you.

## The nine tenets

A doctrine carried by the hooks into the main thread and every subagent and workflow stage, so it survives compaction and rides into helpers without skill text being re-read.

1. **Remember what matters.** The original request and the one-line North Star, kept load-bearing and re-anchored after every compaction; the North Star travels into every dispatch.
2. **Front-load the questions.** Explore first, ask the batch once and early, so downstream can run unattended.
3. **Team of equals.** A lead holds coordination authority only, not intellectual authority; subagents and peers push back with technical reasoning.
4. **Unease.** Restated only when it increases, measured against the whole project, with a standing override to stop and ask if the North Star is at risk.
5. **Offline mode.** Enabled only by `playbook:offline-mode`, explicitly and per run.
6. **Ready for production.** No scaffolding vocabulary or comment sludge in shipped code; a final sweep before handing work back.
7. **Ride the compaction, do not fear it.** See below; this is the keystone.
8. **Less is more.** The cheapest sufficient mode and model; longer thinking and shorter output.
9. **Speed via more hands, not rushing.** Fan separable work across subagents and workflows at the same completeness bar; partial work to save time is forbidden.

## The model rule, always on

Playbook applies one model rule everywhere, including inside every workflow stage and nested subagent: **Sonnet executes, Opus plans and reviews and thinks hard, and you bump up a tier when stuck.** Classification is by what happens when the agent is wrong: a loud, locally fixable error can run on a lighter tier; a quiet error that propagates keeps the flagship. The rule is doctrine, not a mode you enter, and it is announced on each spawn that downshifts.

## Compaction calm (the keystone)

Native auto-compact is seamless: it summarises and the session keeps going, the platform never stops you. The thing that makes agents fearful near the limit, doing less work, wrapping up early, breaking overnight runs, is a context-warning hook (commonly GSD's `gsd-context-monitor`) that injects "you are running low, prepare to pause" into the model.

Playbook fixes this in one move. It detects a competing context-warning hook and offers, once, to let Playbook own the context channel instead: with your consent and a backup, it quiets the competing warning and becomes the single calm voice. From then on it does not scare the agent near the limit, it reassures it ("auto-compact is seamless, you keep what matters, keep going"), and after a compaction it re-anchors on the original request and the North Star and resumes the in-flight work. Nothing is ever edited without your explicit consent.

## Commands

Plugin name stays `playbook`. Every command ships under two names: a branded `/pb-*` that is canonical and collision-proof on top of Superpowers or GSD, and a bare natural alias for newcomers.

| Branded | Natural | What it does |
|---|---|---|
| `/pb-brainstorming` | `/brainstorming` | explore options, ask sharp questions, paint the picture, converge (also auto-triggers on fuzzy work) |
| `/pb-offline-mode` | `/offline-mode` | enable offline behaviour and notifications for this run |
| `/pb-worktrees` | `/worktrees` | isolate a separate Claude Code session in `.worktrees/` with its own branch and instance number |
| `/pb-workflow` | `/workflow` | ⚙️ run this task as a dynamic workflow at scale, carrying the North Star and model rule into the workflow |
| `/pb-fix` | `/fix` | 🦞 strict fix protocol, production-ready, strongly typed for the stack, validated at boundaries |
| `/pb-debug` | `/debug` | 👾 strict read, summarise, diagnose, confirm debugging cycle |
| `/pb` | | status heartbeat: is Playbook active, which mode, which model split, offline on or off |

If another tool already owns a bare name, the `/pb-` form is the safe one.

## Offline mode and notifications

`playbook:offline-mode` is opt-in, enabled fresh per session, never carried over. While active it runs a wait-then-escalate ladder, pulls you back when work blocks, falls back to an external manager if you do not respond within the window you declared, and exports the absent-decisions as a morning-readable HTML log.

Notifications support **Pushover or ntfy**, chosen at setup. Pushover is recommended when you need a guaranteed wake-up: it can break through iOS Do Not Disturb and Focus (you enable Critical Alerts once in the Pushover app). ntfy stays as the free, self-hostable, Android-friendly option. A single abstraction maps three levels onto either provider: `info`, `action`, and `critical`, and the running agent can choose the level per event and fire a critical alert when it genuinely matters.

Going to sleep on a long run pairs well with native `/goal`: let `/goal` own the "am I actually done?" loop while offline mode owns the North Star, the notification pull-back, the escalation ladder, and the decision log.

## Worktrees for parallel sessions

`playbook:worktrees` is for the human running several Claude Code sessions at once, not for subagent parallelism. It creates a worktree under `.worktrees/` on a dedicated branch and assigns it an instance number, then offsets every resource the stack needs to isolate by that number, a per-instance Docker database, a dev-server port, a cache namespace, so any number of sessions run side by side without collision. It degrades gracefully to branch-only isolation when no isolatable resource is found.

## Prerequisites and graceful degradation

The common path is zero-dependency. `lone-wolf`, `interns`, `hackathon`, `workflows`, the model rule, the compaction calm, and all nine tenets need only native Claude Code. Only `gsd` needs a prerequisite, and Playbook prompts to install it at exactly that fork rather than failing: `npx get-shit-done-cc@latest`. You can always pick a different mode.

## Runtime state

The core writes no file into your working tree: no `.playbook/` directory, no anchor file, no ledger. The original request, the North Star and the unease sense live in the conversation, steered across compaction by the hooks, and re-derived if a compaction loses them. The opt-in pieces are the only exceptions, and only when you enable them: offline mode stores its notification config under the gitignored `.claude/playbook/`, the context-calm choice is remembered there too, and `.worktrees/` holds your parallel-session worktrees.

## Licence

MIT.
