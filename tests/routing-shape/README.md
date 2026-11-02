# routing-shape

A report-only harness that measures **which mode Playbook routes to** across a ladder
of jobs, to test whether routing collapses to the poles (lone-wolf / workflows) and
skips the middle (interns / hackathon). Not a CI gate; the deterministic guards live in
`tests/hooks/test-doctrine.sh`.

## Run
```bash
bash tests/routing-shape/run.sh [K] [MAX_TURNS] [prompt ...]   # K reps/prompt (default 1), turn cap (default 4)
```
`PERMS=auto` runs each probe in auto permission mode, the user's normal condition; use it where the
session's own classifier refuses the default skip-permissions flag. `PERMS=scoped` is a narrow
allowlist and starves the probe: every refused command (a variable, a loop, a second command)
spends a turn, so probes are censored before they route. `AWAY=1` appends "There's no one around
to answer questions, so make sensible assumptions and go." to every prompt, the absent-user
condition the readings before 3.0.0 used; by default the user is present, which is what the
picker needs.
`JOBS=<n>` runs up to n probes at once (default 1), each in its own copy of the fixture, and prints a line as each finishes; the rows and tally are still classified afterwards in prompt-then-rep order.
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
2. Launches a fresh session at `--effort max` (or `EFFORT`), plugin loaded from a **clone with
   this scaffolding stripped out**, user settings, other plugins and MCP servers excluded,
   `CLAUDE_CODE_SUBAGENT_MODEL` unset, agent-teams flag off unless `TEAMS=1`, and real dispatch blocked by `deny-dispatch.settings.json` (records the
   attempt, spawns nothing, keeps cost down).
3. `classify.sh` reads the stream: overlay canary, the routing decision (see below), first
   real dispatch the model reached for, cost.
4. `run.sh` tallies a confusion matrix and the metrics defined in `thresholds.md`.

## How the route is read
Routing is opt-in, so the decision is a tool call, not a line of prose. Headless Claude Code
offers `AskUserQuestion` only when a permission host can answer it (an Agent SDK `canUseTool`
callback or a `--permission-prompt-tool`); a PreToolUse hook does not count. So every probe
loads `picker-host.py`, a stdlib MCP server, as its `--permission-prompt-tool` with
`--strict-mcp-config`. It answers each question with the option marked `(Recommended)`, as a
user who takes the recommendation would, refuses every other permission request, and logs each
call next to the stream (`<prompt>.<rep>.host.jsonl`). The probe then goes on to its route line
and its first dispatch, which `deny-dispatch.settings.json` blocks. `classify.sh` takes the
first of:
1. **The picker**: an `AskUserQuestion` whose question starts `Goal:`. The mode is its
   option labelled `(Recommended)`, and every option's mode is the shortlist.
2. **The route line**: a Bash no-op starting `playbook route <mode>`, which is what the
   model emits when only one mode fits and there is nothing to ask. The mode is the route
   and the shortlist.
3. **The marker line** (the original reading): the first branded `**Playbook**` line in
   assistant text. It stays as the fallback and for older doctrine versions.

The result row gains two columns, `source` (`picker`, `route`, `marker`, `none`) and
`shortlist`. A picker with no recommended option, or whose recommendation is not a mode
name, is `malformed`. A picker decision with no dispatch after it has `map=na`, because the
run stopped after the question without reaching for a helper. `run.sh` adds three lines to its metrics: the decision
sources, how often the recommendation sits in the expected set for the job, and how often
the shortlist contains an expected mode. `tally.awk` holds the tally so it can be tested
without a paid run.

Offline checks (free): `bash tests/hooks/test-routing-shape.sh` runs `classify.sh` over the
synthetic streams in `fixtures/` (picker, batched picker, route line, fallback, censored),
the deny settings, the tally, and the neutral fixture from `make-fixture.sh`.

## Files
- `prompts/` — one job per intended mode, plus two boundary jobs. Neutral wording, no
  engine vocabulary, identical "no one to answer, make assumptions" suffix.
- `make-fixture.sh` — generates the pristine neutral toy project.
- `deny-dispatch.settings.json` — the cost-guard (PreToolUse deny on Agent/Workflow/SendMessage/TeamCreate and AskUserQuestion).
- `classify.sh` — one stream → one result row.
- `fixtures/` — synthetic streams for the picker and the route line, used by the offline test.
- `run.sh` — orchestrates, prints the matrix and metrics; `tally.awk` computes them.
- `doctrine-versions/` — snapshots of the routing doctrine, `v6-shortlist` being the 3.0.0 one.
- `thresholds.md` — pre-registered expectations, written before the first run.

## Known limits
- `hackathon` can't reach its own mode with the teams flag off; a flag-on pass measures
  that separately.
- Marker capture depends on the branded marker format staying stable (guarded in
  `test-doctrine.sh`).
- Stochastic: a single K=1 smoke shows the pipeline works and a first shape, not a claim.
