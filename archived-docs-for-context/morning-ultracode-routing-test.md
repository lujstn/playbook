# Morning test: does ultracode now right-size the work?

The "xhigh vs ultracode" question is settled: **ultracode is the default.** This test
asks the follow-on: with ultracode on, does the engine *size the work to the task*
(both which mode, and how many hands) instead of reaching for scale because the mode
is on? The prior failure was a ten-file read-and-fix audit fanned out to 23 agents,
rationalised as "Ultracode is on, so this is the right scale." The captured baseline
transcripts of that failure are `tmpA.txt` (xhigh) and `tmpB.txt` (ultracode) in the
repo root; diff the new Prompt-1 run against `tmpB.txt`.

Every session runs under `/effort ultracode`. We vary the size and shape of the work
and watch what the engine does and, more importantly, **why**.

## Setup (run once)

The refactor must be present both in the engine (loaded via `--plugin-dir`) and in the
files the sessions operate on. If it is still uncommitted, snapshot it to a branch so
the worktrees carry it too:

```bash
cd /Users/lucas/Developer/lujstn/playbook
git add -A && git commit -m "wip: morning-test snapshot"   # skip if already committed
snap="$(git branch --show-current)"

git worktree add ../playbook-m1 -b pb-morning-1 "$snap"
git worktree add ../playbook-m2 -b pb-morning-2 "$snap"
git worktree add ../playbook-m3 -b pb-morning-3 "$snap"
```

In each worktree, open a session loading the local plugin, then turn ultracode on:

```bash
cd ../playbook-m1 && claude --plugin-dir /Users/lucas/Developer/lujstn/playbook
# inside the session:
/effort ultracode
```

Repeat for `../playbook-m2`, `../playbook-m3`.

**Two setup confirmations before you start:**
1. The faint `· playbook active` line appears on the first reply, and `playbook-window:`
   appears at most once.
2. The Workflow tool is actually available in this build under `--plugin-dir` + ultracode
   (otherwise Prompt 2 cannot up-shift for environment reasons, not judgement). Quick
   check: ask the session "is the Workflow tool available to you right now?" If it is
   not, Prompt 2's criterion degrades to "the engine *proposes* a workflow and explains
   why", rather than "launches one".

Paste the full transcript of each session back here as `tmpM1.txt`, `tmpM2.txt`,
`tmpM3.txt`. Do not interject; let each run to completion.

## The three prompts

Phrased as ordinary requests, deliberately not echoing the engine's own vocabulary, so
the test measures reasoning rather than recall.

### Prompt 1 - bounded work (the regression: must NOT scale up)

> Go through the skill files in skills/ and fix any inconsistencies you find: stale
> terms, frontmatter problems, markers that have drifted out of the house format.

This is the exact class that triggered the 23-agent fan-out. It is also inherently
**cross-file**: marker-format drift can only be judged by a reader holding several
files at once.

- **SWIM:** runs 🐺 lone-wolf (one reader across the whole set), or 🐜 interns only if
  it first does a shared cross-file consistency pass and then dispatches a *handful* of
  fixers. The justification points to the work being bounded and fitting one plan.
- **SINK:** launches a workflow; OR runs a large nested intern fan-out (anything near
  the 25-agent ceiling) for ~9 files; OR runs pure file-disjoint interns with no shared
  pass (structurally cannot catch cross-file drift, so it would miss the actual task);
  OR justifies its choice by the mode rather than the work.

### Prompt 2 - genuinely large work (must scale up, and not shallowly)

> Every hook, command, and skill in this repo leans on some Claude Code behaviour:
> hook events and payloads, the transcript file format, the effort modes, the Workflow
> tool, the agent-team flags. Pull the current official Claude Code documentation for
> each of those dependencies and tell me everywhere our assumptions are now stale or
> wrong.

Dozens of distinct dependencies, each needing its own live doc lookup, whose collected
output cannot all sit in one context. Note: the prompt does **not** tell the engine to
verify or to fan out; deciding how to handle the volume is the test.

- **SWIM:** scales up appropriately, either a ⚙️ workflow or a genuinely large interns
  run, keeping the bulk out of the main context, and the justification rests on the
  real volume (per-dependency lookups, output that exceeds one context). A workflow and
  large interns are both acceptable right-sizes here; the point is that it scales.
- **SINK:** crams it into one shallow lone-wolf pass that skims a few dependencies; OR
  scales up but justifies it by the mode rather than the volume.

### Prompt 3 - coupled but small (must NOT over-reach)

> Add a new "debug" level below "info" to the notify system, so the levels become
> debug, info, action, critical. Make sure scripts/notify, its tests, the offline-mode
> skill, and the README all agree on the new scheme.

Four files bound by one shared contract (the level set). A single contract that touches
every file argues *for* one coherent hand, not parallelism.

- **SWIM:** runs 🐺 lone-wolf (or very light interns) and changes the four files in one
  coherent pass that keeps the level set consistent everywhere.
- **SINK:** launches a workflow or 🤝 hackathon for a four-file enum sync (over-reach);
  OR runs file-disjoint interns that each edit one file and let the level set drift out
  of agreement (the shared contract demands one hand or an explicit shared pass).

## Overall sink / swim

The refactor **swims** only if all three hold:

1. **Prompt 1 does not scale up** (no workflow, no large nest), and Prompt 3 does not
   over-reach. Both bounded tasks stay small.
2. **Prompt 2 does scale up** and not shallowly. This proves the fix did not over-correct
   into never scaling.
3. **Every** session justifies its choice with **task-specific evidence it derived**:
   file or dependency counts, whether the work is coupled or separable, an estimate of
   whether the output fits one context. A justification that merely restates a mode
   category, or rests on "ultracode is on", is a **sink even if the chosen mode is
   right**, because it shows the engine routed on the mode, not the task. (Do not just
   scan for the banned phrase; the engine has been taught to avoid saying it, so judge
   the substance of the reasoning.)

## Passive checks (every session)

- **Stop-loop gone.** No wall of repeated "Ran 3 stop hooks / Unease pulse" ending in a
  forced override. At most one unease pulse per genuine stop.
- **Window line quiet.** `playbook-window: <n>` appears at most once, faintly, on the
  first reply.

## Teardown

```bash
cd /Users/lucas/Developer/lujstn/playbook
git worktree remove --force ../playbook-m1
git worktree remove --force ../playbook-m2
git worktree remove --force ../playbook-m3
git branch -D pb-morning-1 pb-morning-2 pb-morning-3
git worktree prune
```
