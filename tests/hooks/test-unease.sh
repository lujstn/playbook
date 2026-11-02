#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/payloads.sh"

# --- self-reports are a floor, never a ceiling -----------------------------
for pair in "uneasy:50:rethink" "concerned:100:judge" "alarmed:150:ask"; do
  lvl="${pair%%:*}"; rest="${pair#*:}"; floor="${rest%%:*}"; gate="${rest#*:}"
  iso; d="$(sd "u$lvl")"
  chan "u$lvl" "playbook unease $lvl the reason"
  eq "'$lvl' sets the gate" "$gate" "$(playbook_gate "$d")"
  want="$floor"; [ "$lvl" = alarmed ] && want=50
  eq "'$lvl' leaves the score at its floor (alarmed then drops to 5.0 once the user is asked)" "$want" "$(score_of "$d")"
done
iso; d="$(sd above)"
playbook_state_put "$d" score10=70
chan above 'playbook unease uneasy still fine'
eq "a lower self-report never lowers the score" 70 "$(score_of "$d")"

# --- the register is the score's own levels --------------------------------
iso; d="$(sd reg)"
for old in calm settled watchful faintly_uneasy strained troubled near_breaking attentive clear; do
  chan reg "playbook unease $old x"
  eq "the retired level '$old' is refused" deny "$(decision_of)"
done
eq "and none of them moved the score" 0 "$(score_of "$d")"

# --- would this have been the right place to stop? -------------------------
# A level crossing blocks the next edit; the gate is the stop, and each gate has exactly one way out.
iso; d="$(sd out)"
chan out 'playbook unease uneasy drifting from the brief'
pre_edit out /tmp/x; eq "uneasy stops the next edit" deny "$(decision_of)"
chan out 'playbook rethink back to the brief'
pre_edit out /tmp/x; silent "a rethink is the way out of uneasy"
chan out 'playbook unease concerned the tests keep failing'
pre_edit out /tmp/x; eq "concerned stops edits again" deny "$(decision_of)"
chan out 'playbook rethink trying to talk my way out'
pre_edit out /tmp/x; eq "a rethink does not clear a judge gate" deny "$(decision_of)"
post out PostToolUse Agent '{"description":"judge: review the approach"}' '{}'
pre_edit out /tmp/x; silent "only a judge does"

exit $fail
