---
name: gsd-mode
description: The 🏗️ gsd route. Front-loads user involvement and research, pre-seeds the GSD stage files so the interactive pass is skipped, and post-processes generated plan frontmatter to force parallel execution. Reached from the playbook engine when work is an MVP in an unknown area requiring durable cross-session state.
user-invocable: false
---

# GSD Mode

## Overview

GSD mode is Playbook's wrapper around [get-shit-done-cc](https://github.com/gsd-build/get-shit-done). It does two things: it right-sizes how much user involvement GSD asks for, and it forces parallel execution where GSD would otherwise serialise. Marker: 🏗️ **Playbook** `gsd`.

The wrapper is built on three observations: GSD's interactive phase planning asks more questions than it needs if you supply a CONTEXT file upfront; GSD's executor serialises waves unless you set the right config knobs; and GSD's map-codebase is expensive to run unscoped. All three are fixable by the wrapper without forking or patching GSD itself.

## Detect GSD availability

Before doing anything else, check for GSD in this order:

1. `get-shit-done-cc` or `gsd-sdk` resolvable on `PATH`.
2. `~/.claude/get-shit-done/` exists.
3. `~/.claude/commands/gsd/` exists, or `gsd-*` skills are present.

If none of these match, do not fail. Emit:

> gsd needs GSD, which is a separate tool. Install it with: `npx get-shit-done-cc@latest`. Then re-run, or pick a different mode.

Detect whether a GSD project already exists by checking for `.planning/` at the project root. If it exists, optionally read `.planning/STATE.md` YAML frontmatter (`milestone`, `active_phase`, `next_action`) to report the current position before deciding what to do next.

## Front-load user involvement

GSD's default phase flow asks questions during the grey-areas pass and researcher pass. The wrapper collapses this into a single early conversation: ask only what the current phase needs, do it once, then pre-seed the stage files so GSD skips its interactive passes.

### Step 1: assess how much is actually needed

Before asking anything, assess what is already known: the user's request, any existing `.planning/` state, and the codebase. Ask only the questions that block planning. For a phase with a clear spec and a mapped codebase, zero questions may be needed.

### Step 2: optional targeted research

If there are genuine unknowns (external APIs, unfamiliar frameworks, library choices), do targeted research before writing the CONTEXT file. Prefer narrow lookups over unscoped map-codebase fan-outs; see "Tame over-investigation" below.

### Step 3: write the CONTEXT file

Write `.planning/phases/XX-slug/XX-CONTEXT.md` using this schema:

```markdown
## domain
<What this phase is about, in one short paragraph. No scaffolding vocabulary.>

## decisions
<Locked design decisions that the planner must not re-open. One decision per line.>

## code_context
<Relevant existing patterns, file locations, or conventions the planner must know.>

## specifics
<Phase-specific constraints: API contracts, data shapes, performance targets, etc.>

## deferred
<Explicitly out of scope for this phase. Deferred items do not become suggestions.>
```

Optionally write `XX-RESEARCH.md` with the findings from step 2 if they are substantial enough that the planner needs them.

### Step 4: run plan-phase with skip-research

```bash
/gsd:plan-phase XX --skip-research
```

GSD detects the CONTEXT file and bypasses the grey-areas and researcher passes. The planner has what it needs; no interactive prompts fire.

Express alternatives when a PRD or doc glob is available:

```bash
/gsd:plan-phase --prd <file>
/gsd:plan-phase --ingest <glob>
```

## Force parallel execution

GSD serialises execution by design: waves run sequentially, and intra-wave parallelism requires explicit configuration. The wrapper post-processes the generated plan frontmatter and sets the config knobs to make parallelism the default.

### Post-process plan frontmatter

After `/gsd:plan-phase` generates `XX-YY-PLAN.md` files, group independent, file-disjoint plans into the same `wave:` field. Two plans are file-disjoint when their file ownership sets do not overlap; verify this before assigning the same wave number. Plans that share files must remain in separate waves.

### Set parallelisation config

Write these keys into `.planning/config.json` (or merge them if the file already exists):

```json
{
  "parallelization": {
    "enabled": true,
    "plan_level": true,
    "max_concurrent_agents": 8,
    "min_plans_for_parallel": 2
  },
  "workflow": {
    "use_worktrees": true
  }
}
```

Raise `max_concurrent_agents` if the wave has more than 8 file-disjoint plans; keep it at or below the GSD project's own configured ceiling if one exists.

### Cross-phase parallelism

For work that spans phases, check whether phases are mutually independent before running them serially:

```bash
/gsd:manager --analyze-deps
```

Or use `/gsd:workstreams` to identify which phases can run concurrently.

## Apply the model rule via GSD's own knobs

Write into `.planning/config.json`:

```json
{
  "model_overrides": {
    "gsd-executor": "sonnet",
    "gsd-planner": "opus",
    "gsd-verifier": "opus"
  }
}
```

If the GSD version in use supports `model_profile` instead of `model_overrides`, use that. The model rule (Sonnet executes, Opus plans and reviews) propagates through GSD's own dispatch machinery rather than relying on spawn-level inheritance, which GSD may not honour across its internal agents.

## Tame over-investigation

GSD's `map-codebase` spawns up to four parallel researcher agents when run unscoped. This is expensive and often returns more than the planner needs.

Prefer:

- `--fast` or `--focus <area>` flags when available.
- Supplying `XX-RESEARCH.md` and passing `--skip-research` so the researcher is bypassed entirely.
- Narrow targeted reads of the relevant subsystem rather than a full codebase map.

Only run an unscoped `map-codebase` when the codebase is genuinely unknown and no targeted read would suffice.

## Write policy

Playbook may write only the following inside `.planning/`:

- `phases/XX-slug/XX-CONTEXT.md`
- `phases/XX-slug/XX-RESEARCH.md`
- `config.json` (only the keys listed above: `parallelization`, `workflow.use_worktrees`, `model_overrides`)
- `XX-YY-PLAN.md` wave frontmatter (the `wave:` field only, not plan content)

Everything else in `.planning/` is GSD-owned durable state and stays read-only. Do not write `STATE.md`, `ROADMAP.md`, `MILESTONE.md`, or any other GSD-managed file.

## Red Flags

**Never:**
- Write into `.planning/` outside the declared list above.
- Run unscoped `map-codebase` when targeted research would suffice.
- Assign the same wave number to plans that share file ownership.
- Set `model_overrides` keys that GSD does not recognise; verify against the installed version.
- Skip the availability check and proceed as if GSD is installed when it may not be.
- Ask more questions than the phase needs; assess what is already known first.

**Always:**
- Detect GSD availability before routing; emit the install prompt and let the user decide if it is absent.
- Write XX-CONTEXT.md before running plan-phase; this is what collapses the interactive passes.
- Verify file-disjointness before grouping plans into the same wave.
- Set `use_worktrees: true`; intra-wave parallelism without worktrees risks write collisions.
- Apply the model overrides via config.json so the rule propagates through GSD's own agents.

## Integration

**Before this skill:**
- `playbook:playbook` is the routing engine. It makes the gsd routing decision and announces 🏗️ **Playbook** `gsd` before this skill runs. The nine-tenet overlay and the North Star stay live throughout.

**External dependency:**
- GSD (`get-shit-done-cc`). Install with `npx get-shit-done-cc@latest`. This is the one mode in the common path that has a prerequisite; the wrapper prompts at the fork, never hard-fails.

**After the phase runs:**
- The tenet 6 production-ready sweep still applies: no scaffolding vocabulary in shipped code, no plan references, no comment sludge.
- Return to `playbook:playbook` if the routing decision for the next piece of work needs to be re-assessed.
