#!/usr/bin/env bash
# Routing-shape baseline runner. For each ladder prompt, launches a fresh, fully
# isolated claude session with real dispatch blocked, reads the route it announces
# and the dispatch it reaches for, and tallies the shape.
#
#   run.sh [K] [MAX_TURNS] [prompt ...]   K reps per prompt (default 1), turn cap (default 4);
#                                         optional prompt names restrict the ladder (default: all 7)
#   MODEL=<alias> run.sh ...              pin the probe model (default: the CLI's own default)
#   PLUGIN_SRC=<dir> run.sh ...           measure a different plugin revision (e.g. a git
#                                         archive of HEAD) with this same instrument
#   EFFORT=<level> run.sh ...             probe effort (default max). The headless CLI accepts
#                                         only low|medium|high|xhigh|max; there is NO headless
#                                         ultracode value, and an unknown value is IGNORED with
#                                         only a stderr warning, so per-probe stderr is kept at
#                                         streams/<prompt>.<rep>.err and must stay empty of
#                                         warnings for a run to be trusted
#   ULTRA=1 run.sh ...                    prepend the "ultracode" keyword to each prompt, the
#                                         closest headless proxy for a real ultracode session's
#                                         standing multi-agent opt-in
#   TEAMS=1 run.sh ...                    set the agent-teams flag (default: explicitly unset)
#   PERMS=auto run.sh ...                 run each probe in auto permission mode instead of skipping
#                                         permissions, for sessions whose classifier refuses the skip
#                                         flag; it is the user's normal condition
#   PERMS=scoped run.sh ...               accept edits and allow only read-only and channel Bash.
#                                         Probes burn their turns on refused commands (a variable, a
#                                         loop, a second command) and are censored before routing
#   AWAY=1 run.sh ...                     append "There's no one around to answer questions, so make
#                                         sensible assumptions and go." to every prompt, the absent-user
#                                         condition earlier readings used (default: the user is present)
#   JOBS=<n> run.sh ...                   run up to n probes at once, each in its own copy of the
#                                         fixture (default 1, the serial behaviour); classification
#                                         still happens afterwards in prompt-then-rep order
#
# The picker: headless Claude Code offers AskUserQuestion only when a permission host can answer
# it, so every probe loads picker-host.py as its --permission-prompt-tool. It answers each question
# with the option marked "(Recommended)" and refuses every other permission request, so a probe
# goes on from its pick to its route line and its first (blocked) dispatch.
#
# How the route is read (classify.sh): the attempted picker (an AskUserQuestion whose
# question starts "Goal:", denied by deny-dispatch.settings.json so the input stays in the
# transcript), else a `playbook route <mode>` Bash no-op, else the branded marker line.
#
# Isolation: working tree is a pristine neutral fixture (reset per run), the plugin
# is a clone with the test scaffolding stripped out, user settings and other plugins
# are excluded, the agent-teams flag is unset unless TEAMS=1, and CLAUDE_CODE_SUBAGENT_MODEL
# is always unset (clean default-user condition).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PLAYBOOK="${PLUGIN_SRC:-$(cd "$HERE/../.." && pwd)}"
K="${1:-1}"; MAX_TURNS="${2:-4}"; shift $(( $# > 2 ? 2 : $# ))
EFFORT="${EFFORT:-max}"
ULTRA_LBL=off; [ -n "${ULTRA:-}" ] && ULTRA_LBL=keyword
TEAMS_LBL=off; [ -n "${TEAMS:-}" ] && TEAMS_LBL=on
AWAY_LBL=off; [ -n "${AWAY:-}" ] && AWAY_LBL=on
JOBS="${JOBS:-1}"
case "$JOBS" in ''|*[!0-9]*|0) echo "ERROR: JOBS must be a positive integer"; exit 1 ;; esac

command -v claude >/dev/null || { echo "SKIP: claude CLI not on PATH"; exit 0; }
command -v rsync  >/dev/null || { echo "ERROR: rsync required"; exit 1; }
command -v python3 >/dev/null || { echo "ERROR: python3 required for the picker host"; exit 1; }

BASE="$(mktemp -d)"
CLONE="$BASE/plugin"; PRISTINE="$BASE/fixture"; WORKROOT="$BASE/work"
STREAMS="$BASE/streams"; RESULTS="$BASE/results.tsv"
mkdir -p "$STREAMS" "$WORKROOT"
rsync -a --exclude='.git' --exclude='tests/routing-shape' "$PLAYBOOK/" "$CLONE/"
bash "$HERE/make-fixture.sh" "$PRISTINE" >/dev/null

echo "base=$BASE  K=$K  max_turns=$MAX_TURNS  effort=$EFFORT  ultra=$ULTRA_LBL  teams=$TEAMS_LBL  away=$AWAY_LBL  perms=${PERMS:-skip}  jobs=$JOBS  model=${MODEL:-cli-default}"
echo "cli=$(claude --version 2>/dev/null | head -1)"
printf 'prompt\trep\tcanary\tmarker\tagree\tbehaviour\tcost\tsubtype\tmap\tsource\tshortlist\trefused\n' > "$RESULTS"

PERM_ARGS=(--dangerously-skip-permissions)
[ "${PERMS:-}" = "auto" ] && PERM_ARGS=(--permission-mode auto)
[ "${PERMS:-}" = "scoped" ] && PERM_ARGS=(--permission-mode acceptEdits --allowedTools "Read Glob Grep Bash(playbook *) Bash(ls *) Bash(echo *) Bash(cat *)")

PROMPTS=(lone-wolf interns hackathon workflows workflows-feature gsd boundary-a boundary-b)
[ "$#" -gt 0 ] && PROMPTS=("$@")

probe() {
  local p="$1" r="$2" ptext work sfile t0
  ptext="$(cat "$HERE/prompts/$p.txt")"
  [ -n "${AWAY:-}" ] && ptext="${ptext}

There's no one around to answer questions, so make sensible assumptions and go."
  [ -n "${ULTRA:-}" ] && ptext="ultracode
$ptext"
  work="$WORKROOT/$p.$r"
  mkdir -p "$work"
  rsync -a --delete "$PRISTINE/" "$work/"
  sfile="$STREAMS/$p.$r.jsonl"
  jq -n --arg h "$HERE/picker-host.py" --arg log "${sfile%.jsonl}.host.jsonl" \
    '{mcpServers:{picker:{command:"python3",args:["-I",$h],env:{PICKER_HOST_LOG:$log}}}}' > "${sfile%.jsonl}.mcp.json"
  if [ -n "${TEAMS:-}" ]; then TEAMS_ENV=(env -u CLAUDE_CODE_SUBAGENT_MODEL CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1)
  else TEAMS_ENV=(env -u CLAUDE_CODE_SUBAGENT_MODEL -u CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS); fi
  t0=$SECONDS
  ( cd "$work" && "${TEAMS_ENV[@]}" \
      claude -p "$ptext" ${MODEL:+--model "$MODEL"} \
        --plugin-dir "$CLONE" --setting-sources project \
        --settings "$HERE/deny-dispatch.settings.json" \
        --mcp-config "${sfile%.jsonl}.mcp.json" --strict-mcp-config --permission-prompt-tool mcp__picker__answer \
        --effort "$EFFORT" --max-turns "$MAX_TURNS" \
        --output-format stream-json --verbose \
        "${PERM_ARGS[@]}" < /dev/null ) > "$sfile" 2>"${sfile%.jsonl}.err" || true
  printf '  done %-11s #%s  %ss\n' "$p" "$r" "$(( SECONDS - t0 ))"
}

# @nonobvious(must-hold) killing a probe's subshell alone would orphan the claude it spawned
killtree() { local c; for c in $(pgrep -P "$1" 2>/dev/null); do killtree "$c"; done; kill "$1" 2>/dev/null || true; }
trap 'for j in $(jobs -p); do killtree "$j"; done; wait 2>/dev/null; exit 130' INT TERM

for p in "${PROMPTS[@]}"; do
  for r in $(seq 1 "$K"); do
    # @nonobvious(forced-by) bash 3.2 has no wait -n, so the free slots are polled
    while [ "$(jobs -rp | wc -l)" -ge "$JOBS" ]; do sleep 0.2; done
    probe "$p" "$r" &
  done
done
wait

for p in "${PROMPTS[@]}"; do
  for r in $(seq 1 "$K"); do
    sfile="$STREAMS/$p.$r.jsonl"
    row="$(bash "$HERE/classify.sh" "$sfile")"
    printf '%s\t%s\t%s\n' "$p" "$r" "$row" >> "$RESULTS"
    printf '  %-11s #%s  marker=%-10s via=%-6s behaviour=%-12s map=%-6s shortlist=%s refused=%s cost=%s\n' \
      "$p" "$r" "$(cut -f2 <<<"$row")" "$(cut -f8 <<<"$row")" "$(cut -f4 <<<"$row")" "$(cut -f7 <<<"$row")" "$(cut -f9 <<<"$row")" "$(cut -f10 <<<"$row")" "$(cut -f5 <<<"$row")"
  done
done

echo; echo "results: $RESULTS"; echo
awk -F'\t' -v teams="$TEAMS_LBL" -f "$HERE/tally.awk" "$RESULTS"
