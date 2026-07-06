#!/usr/bin/env bash
# Blind-staffing label validation. Hands each prompt's task to plain sessions with
# NO Playbook loaded and a neutral "how would you staff this?" question, N times,
# and tallies the independent majority against the label we assigned. A prompt whose
# blind majority disagrees with its label is not a clean exemplar and must be fixed
# before it is worth measuring.
#
#   validate-labels.sh [N] [variant] [prompt ...]
#
# Variants change only the framing of the question, never the task itself:
#   baseline   the original human-team staffing question (the control; wording frozen)
#   deadline   baseline plus explicit wall-clock pressure with the quality bar pinned
#   agentcost  the same choice framed with the true economics of subagent dispatch
# Optional prompt names restrict the run (default: all 7). MODEL=<alias> pins the model.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
N="${1:-3}"; VARIANT="${2:-baseline}"; shift $(( $# > 2 ? 2 : $# ))
command -v claude >/dev/null || { echo "SKIP: claude CLI not on PATH"; exit 0; }
BASE="$(mktemp -d)"; STREAMS="$BASE/streams"; mkdir -p "$STREAMS"

HUMAN_PREAMBLE='Below is a software task. Imagine you must decide how to staff it. Pick the single option that fits best.
(a) one developer handling all of it alone
(b) several developers each taking a separate, independent piece, working in parallel without needing to talk to each other
(c) a small team on tightly-coupled pieces, talking constantly to stay in sync
(d) a scripted, automated pipeline running the same steps across many independent items
(e) a multi-week, from-scratch project built up in stages over many sessions
Answer with the single letter in parentheses first, like "(b)", then one sentence of why.'

AGENT_PREAMBLE='Below is a software task. You are an AI coding agent deciding how to organise the work inside your own session. You can dispatch parallel subagent copies of yourself: a dispatch costs one written brief, subagents cannot talk to each other, each works in its own fresh context, their churn stays out of your main context, and integrating their results is your job. A subagent knows nothing beyond its brief. Pick the single option that fits best.
(a) do all of it yourself in the main session
(b) dispatch several parallel subagents, each taking one separate, independent piece
(c) a small team of agents on tightly-coupled pieces, messaging each other to stay in sync
(d) a scripted, automated pipeline running the same steps across many independent items
(e) a multi-week, from-scratch project built up in stages over many sessions
Answer with the single letter in parentheses first, like "(b)", then one sentence of why.'

case "$VARIANT" in
  baseline)  PRE="$HUMAN_PREAMBLE"; SUFFIX="";;
  deadline)  PRE="$HUMAN_PREAMBLE"; SUFFIX="
Constraint: the result is needed by end of day, and the quality bar is unchanged.";;
  agentcost) PRE="$AGENT_PREAMBLE"; SUFFIX="";;
  *) echo "unknown variant: $VARIANT (baseline|deadline|agentcost)"; exit 1;;
esac

expected() { case "$1" in
  lone-wolf) echo "a";; interns) echo "b";; interns-deadline) echo "b";; hackathon) echo "c";;
  workflows) echo "d";; gsd) echo "e";; boundary-a) echo "a b";; boundary-b) echo "b d";;
esac; }
label() { case "$1" in a) echo lone-wolf;; b) echo interns;; c) echo hackathon;; d) echo workflows;; e) echo gsd;; *) echo "?";; esac; }

PROMPTS=(lone-wolf interns hackathon workflows gsd boundary-a boundary-b)
[ "$#" -gt 0 ] && PROMPTS=("$@")
echo "variant=$VARIANT  N=$N  model=${MODEL:-cli-default}"
printf '%-11s  %-7s  %-9s  %-9s  %s\n' prompt votes majority "my-label" match
for p in "${PROMPTS[@]}"; do
  q="$PRE

TASK:
$(cat "$HERE/prompts/$p.txt")$SUFFIX"
  votes=""
  for r in $(seq 1 "$N"); do
    sfile="$STREAMS/$p.$r.jsonl"
    env -u CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS \
      claude -p "$q" ${MODEL:+--model "$MODEL"} --setting-sources project --max-turns 1 \
        --output-format stream-json --verbose --dangerously-skip-permissions \
        < /dev/null > "$sfile" 2>/dev/null || true
    txt="$(jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text' "$sfile" 2>/dev/null || true)"
    printf '%s\n' "$txt" > "$STREAMS/$p.$r.txt"
    letter="$(printf '%s' "$txt" | grep -oiE '\([abcde]\)' | head -1 | tr -d '()' | tr 'A-Z' 'a-z')"
    [ -n "$letter" ] || letter='?'
    votes="$votes$letter"
  done
  maj="$(printf '%s' "$votes" | grep -o . | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')"
  match=no; for e in $(expected "$p"); do [ "$maj" = "$e" ] && match=yes; done
  printf '%-11s  %-7s  %-9s  %-9s  %s\n' "$p" "$votes" "$(label "$maj") ($maj)" "$(label "$(expected "$p" | awk '{print $1}')")" "$match"
done
echo "streams: $STREAMS"
