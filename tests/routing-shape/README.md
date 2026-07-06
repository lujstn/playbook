# routing-shape

A report-only harness that measures **which mode Playbook routes to** across a ladder
of jobs, to test whether routing collapses to the poles (lone-wolf / workflows) and
skips the middle (interns / hackathon). Not a CI gate; the deterministic guards live in
`tests/hooks/test-doctrine.sh`.

## Run
```bash
bash tests/routing-shape/run.sh [K] [MAX_TURNS] [prompt ...]   # K reps/prompt (default 1), turn cap (default 4)
```
`run.sh 1` is the cheap smoke; `run.sh 5` is a baseline reading. Trailing prompt names
restrict the ladder (e.g. `run.sh 2 4 interns boundary-b`), and `MODEL=<alias>` pins the
probe model so readings taken on different days stay comparable. Needs the `claude` CLI,
a live auth, `jq`, and `rsync`.

## Label validation and framing arms
```bash
bash tests/routing-shape/validate-labels.sh [N] [variant] [prompt ...]
```
Hands each job to plain no-Playbook sessions as a staffing question, N votes each.
Variants change only the framing, never the task: `baseline` is the original human-team
question (the control, wording frozen), `deadline` adds wall-clock pressure with the
quality bar pinned, and `agentcost` states the true economics of subagent dispatch.
Comparing variants shows *why* a job lands where it does: a flip under `deadline` means
speed was the missing objective, a flip under `agentcost` means the human-team framing
was mispricing parallel hands.

## What it does per run
1. Resets the working tree to a pristine **neutral fixture** (`make-fixture.sh`) so a
   probe never reads Playbook's own mode doctrine and lets it bias the route.
2. Launches a fresh session at `--effort ultracode`, plugin loaded from a **clone with
   this scaffolding stripped out**, user settings and other plugins excluded, agent-teams
   flag off, and real dispatch blocked by `deny-dispatch.settings.json` (records the
   attempt, spawns nothing, keeps cost down).
3. `classify.sh` reads the stream: overlay canary, first route marker (emoji↔chip check),
   first real dispatch the model reached for, cost.
4. `run.sh` tallies a confusion matrix and the metrics defined in `thresholds.md`.

## Files
- `prompts/` — one job per intended mode, plus two boundary jobs. Neutral wording, no
  engine vocabulary, identical "no one to answer, make assumptions" suffix.
- `make-fixture.sh` — generates the pristine neutral toy project.
- `deny-dispatch.settings.json` — the cost-guard (PreToolUse deny on Agent/Workflow/SendMessage).
- `classify.sh` — one stream → one result row.
- `run.sh` — orchestrates, tallies, prints the matrix and metrics.
- `thresholds.md` — pre-registered expectations, written before the first run.

## Known limits
- `hackathon` can't reach its own mode with the teams flag off; a flag-on pass measures
  that separately.
- Marker capture depends on the branded marker format staying stable (guarded in
  `test-doctrine.sh`).
- Stochastic: a single K=1 smoke shows the pipeline works and a first shape, not a claim.
