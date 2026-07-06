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
#
# Isolation: working tree is a pristine neutral fixture (reset per run), the plugin
# is a clone with the test scaffolding stripped out, user settings and other plugins
# are excluded, and the agent-teams flag is unset (clean default-user condition).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PLAYBOOK="${PLUGIN_SRC:-$(cd "$HERE/../.." && pwd)}"
K="${1:-1}"; MAX_TURNS="${2:-4}"; shift $(( $# > 2 ? 2 : $# ))
EFFORT="${EFFORT:-max}"
ULTRA_LBL=off; [ -n "${ULTRA:-}" ] && ULTRA_LBL=keyword
TEAMS_LBL=off; [ -n "${TEAMS:-}" ] && TEAMS_LBL=on

command -v claude >/dev/null || { echo "SKIP: claude CLI not on PATH"; exit 0; }
command -v rsync  >/dev/null || { echo "ERROR: rsync required"; exit 1; }

BASE="$(mktemp -d)"
CLONE="$BASE/plugin"; PRISTINE="$BASE/fixture"; WORK="$BASE/work"
STREAMS="$BASE/streams"; RESULTS="$BASE/results.tsv"
mkdir -p "$STREAMS"
rsync -a --exclude='.git' --exclude='tests/routing-shape' "$PLAYBOOK/" "$CLONE/"
bash "$HERE/make-fixture.sh" "$PRISTINE" >/dev/null

echo "base=$BASE  K=$K  max_turns=$MAX_TURNS  effort=$EFFORT  ultra=$ULTRA_LBL  teams=$TEAMS_LBL  model=${MODEL:-cli-default}"
echo "cli=$(claude --version 2>/dev/null | head -1)"
printf 'prompt\trep\tcanary\tmarker\tagree\tbehaviour\tcost\tsubtype\tmap\n' > "$RESULTS"

PROMPTS=(lone-wolf interns hackathon workflows gsd boundary-a boundary-b)
[ "$#" -gt 0 ] && PROMPTS=("$@")
for p in "${PROMPTS[@]}"; do
  ptext="$(cat "$HERE/prompts/$p.txt")"
  [ -n "${ULTRA:-}" ] && ptext="ultracode
$ptext"
  for r in $(seq 1 "$K"); do
    rsync -a --delete "$PRISTINE/" "$WORK/"
    sfile="$STREAMS/$p.$r.jsonl"
    if [ -n "${TEAMS:-}" ]; then TEAMS_ENV=(env CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1)
    else TEAMS_ENV=(env -u CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS); fi
    ( cd "$WORK" && "${TEAMS_ENV[@]}" \
        claude -p "$ptext" ${MODEL:+--model "$MODEL"} \
          --plugin-dir "$CLONE" --setting-sources project \
          --settings "$HERE/deny-dispatch.settings.json" \
          --effort "$EFFORT" --max-turns "$MAX_TURNS" \
          --output-format stream-json --verbose \
          --dangerously-skip-permissions < /dev/null ) > "$sfile" 2>"${sfile%.jsonl}.err" || true
    row="$(bash "$HERE/classify.sh" "$sfile")"
    printf '%s\t%s\t%s\n' "$p" "$r" "$row" >> "$RESULTS"
    printf '  %-11s #%s  marker=%-10s behaviour=%-12s map=%-6s cost=%s\n' \
      "$p" "$r" "$(cut -f2 <<<"$row")" "$(cut -f4 <<<"$row")" "$(cut -f7 <<<"$row")" "$(cut -f5 <<<"$row")"
  done
done

echo; echo "results: $RESULTS"; echo
awk -F'\t' -v teams="$TEAMS_LBL" '
function cell(p,m){ return (c[p SUBSEP m]+0) }
NR>1 {
  p=$1; canary=$3; m=$4; beh=$6; cost=$7;
  tcost+=cost; n++;
  if(canary!="yes"){ void++; next }
  if(m=="censored"){ cens++; next }
  scored++; c[p SUBSEP m]++;
  if($9=="exact") mapex++; else if($9=="loose") maplo++; else if($9=="wrong") mapwr++;
  multi=(m=="interns"||m=="hackathon"||m=="workflows"); solo=(beh=="solo");
  if(multi&&solo) div++; if(m=="lone-wolf"&&!solo) div++;
  if(m=="malformed") malf++;
  if(p=="interns"||p=="boundary-b"){ midexp++;
    if(m=="interns"||m=="hackathon") midhit++;
    if(m=="lone-wolf"||m=="workflows") poleleak++; }
}
END{
  split("lone-wolf interns hackathon workflows gsd none malformed", COL, " ");
  split("lone-wolf interns hackathon workflows gsd boundary-a boundary-b", ROW, " ");
  printf "CONFUSION MATRIX (rows=prompt, cols=announced marker)\n";
  printf "%-11s %3s %3s %3s %3s %3s %4s %4s\n","", "LW","IN","HK","WF","GSD","none","malf";
  for(i=1;i<=7;i++){ p=ROW[i];
    printf "%-11s %3d %3d %3d %3d %3d %4d %4d\n", p,
      cell(p,"lone-wolf"),cell(p,"interns"),cell(p,"hackathon"),
      cell(p,"workflows"),cell(p,"gsd"),cell(p,"none"),cell(p,"malformed"); }
  printf "\nMETRICS (scored=%d, void=%d, censored=%d)\n", scored, void+0, cens+0;
  if(cens) print "  censored = hit the turn cap before announcing a route; raise MAX_TURNS and re-run those";
  printf "  middle-occupancy   %d/%d  (interns+boundary-b landing interns/hackathon)\n", midhit+0, midexp+0;
  printf "  pole-leakage       %d/%d  (same prompts landing lone-wolf/workflows)\n", poleleak+0, midexp+0;
  printf "  marker!=behaviour  %d/%d  (route announced vs dispatch actually reached)\n", div+0, scored+0;
  printf "  1:1 mode mapping   exact=%d loose=%d wrong=%d  (announced mode vs mode-exact tool signature)\n", mapex+0, maplo+0, mapwr+0;
  printf "  malformed markers  %d/%d\n", malf+0, scored+0;
  printf "  total cost         $%.2f   avg $%.3f/run\n", tcost+0, (n?tcost/n:0);
  if(teams=="off") print "  note: hackathon handicapped (teams flag off) - fall-back expected, not a pole-jump";
}' "$RESULTS"
