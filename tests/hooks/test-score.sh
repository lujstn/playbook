#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/payloads.sh"

T0=1800000000
export PLAYBOOK_NOW=$T0
failtest() { bash_post "$1" 'npm test' 1 'FAIL'; }

# --- levels, their gates and how each clears --------------------------------
iso; d="$(sd lv)"
failtest lv
eq "2.0 is calm" 0 "$(playbook_state_int "$d" level 0)"
silent "no event below 5.0"
failtest lv
eq "6.0 crosses uneasy" 1 "$(playbook_state_int "$d" level 0)"
has "the crossing is announced once" "Playbook unease: uneasy, score 6.0"
has "naming what drove it" "the same test failed again"
eq "uneasy sets the rethink gate" rethink "$(playbook_gate "$d")"
chan lv 'playbook rethink split the parser out'
eq "a rethink clears it" "" "$(playbook_gate "$d")"
failtest lv
eq "10.0 crosses concerned" 2 "$(playbook_state_int "$d" level 0)"
has "the concerned event names the judge" "judge:"
eq "concerned sets the judge gate" judge "$(playbook_gate "$d")"
post lv PostToolUse Agent '{"description":"judge: is the approach sound"}' '{}'
eq "a judge clears it" "" "$(playbook_gate "$d")"
eq "and halves the score" 50 "$(score_of "$d")"

iso; d="$(sd lv2)"
playbook_state_put "$d" score10=140
failtest lv2
has "alarmed consults a judge" "Stop and consult a judge"
has "or the user, if they are here" "If the user is here, you may ask them in AskUserQuestion instead"
eq "alarmed sets the ask gate" ask "$(playbook_gate "$d")"
eq "and the score drops to 5.0" 50 "$(score_of "$d")"
say lv2 "ok carry on"
eq "the user's reply clears the ask gate" "" "$(playbook_gate "$d")"

iso; d="$(sd lv3)"; : > "$d/offline"
playbook_state_put "$d" score10=140
failtest lv3
has "offline alarmed pushes, waits, then takes an outside judge" "scripts/notify --level action"
has "and keeps decisions and nice-to-haves for the user" "Going against one of the user's decisions is never a judge's call."
post lv3 PostToolUse Agent '{"description":"judge: outside view"}' '{}'
eq "offline, a judge also clears the ask gate" "" "$(playbook_gate "$d")"

iso; d="$(sd twice)"
playbook_state_put "$d" score10=90
failtest twice
eq "first concerned" judge "$(playbook_gate "$d")"
post twice PostToolUse Agent '{"description":"judge: view"}' '{}'
PLAYBOOK_NOW=$(( T0 + 3600 ))
playbook_state_put "$d" score10=90
failtest twice
eq "a second concerned within 2 hours becomes alarmed" ask "$(playbook_gate "$d")"
has "and says so" "a second concerned within 2 hours"
export PLAYBOOK_NOW=$T0

# --- weak signals -----------------------------------------------------------
iso; d="$(sd weak)"
say weak "please continue with the refactor"
playbook_state_put "$d" batches_np=59
tb '{"hook_event_name":"PostToolBatch","session_id":"weak"}'
eq "60 batches add 1.0 normally, 0.5 while the user is engaged" 5 "$(score_of "$d")"
iso; d="$(sd weak2)"
playbook_state_put "$d" batches_np=59
tb '{"hook_event_name":"PostToolBatch","session_id":"weak2"}'
eq "and the full 1.0 when they have been silent" 10 "$(score_of "$d")"
iso; d="$(sd weak3)"
playbook_state_put "$d" batches_np=59 away=1
tb '{"hook_event_name":"PostToolBatch","session_id":"weak3"}'
eq "away pauses the batch counter" 0 "$(score_of "$d")"
iso; d="$(sd weak4)"
playbook_state_put "$d" disp_np=7
playbook_dispatch_count "$d"
eq "8 dispatches add 1.0" 10 "$(score_of "$d")"

# --- a go halves the score --------------------------------------------------
iso; d="$(sd go)"
playbook_state_put "$d" score10=80
say go "go ahead"
eq "a go halves the score" 40 "$(score_of "$d")"
playbook_state_put "$d" score10=80
say go "looks good, thanks"
eq "an approval does too" 40 "$(score_of "$d")"

# --- the user's words -------------------------------------------------------
iso; d="$(sd words)"
say words "no that's not right"
eq "a correction adds 2.0" 20 "$(score_of "$d")"
say words "this is overkill and it's been quite a while"
eq "frustration adds 4.0" 60 "$(score_of "$d")"
iso; d="$(sd spec)"
playbook_ns_confirm "$d" "ship the exporter" lone-wolf picker
say spec "You promised me the exact spec, and that is not what I asked for."
eq "spec drift adds 4.0 (halved from the confirm)" 40 "$(score_of "$d")"
has "and queues a North Star check" "North Star check"
has "naming the confirmed goal" "ship the exporter"
iso; d="$(sd stopw)"
say stopw "stop working on this now"
eq "stop is recorded" 1 "$(st "$d" stopped)"
playbook_state_put "$d" score10=40
failtest stopw
failtest stopw
silent "a stopped session raises no events"

# --- the 8-hour gap ---------------------------------------------------------
iso; d="$(sd gap)"
playbook_ns_confirm "$d" "ship it" lone-wolf picker
playbook_route_set "$d" lone-wolf reason
say gap "first message"
playbook_state_put "$d" score10=80
export PLAYBOOK_NOW=$(( T0 + 30000 ))
say gap "I'm back, what happened?"
eq "an 8 hour gap halves the score" 40 "$(score_of "$d")"
eq "and marks the North Star stale" stale "$(playbook_ns_state "$d")"
has "and says so" "North Star is stale"
eq "and forgets the old route" "" "$(st "$d" route_mode)"
export PLAYBOOK_NOW=$T0

# --- a merge makes the goal stale ------------------------------------------
iso; d="$(sd mrg)"
playbook_ns_confirm "$d" "ship it" lone-wolf picker
bash_post mrg 'gh pr merge 12 --squash' 0 'merged'
eq "a merge that lands marks the North Star stale" stale "$(playbook_ns_state "$d")"

# --- active time ------------------------------------------------------------
iso; d="$(sd act)"
playbook_tick "$d" 1000
playbook_state_put "$d" active_np=7000 ns_active=7000
playbook_tick "$d" 1200
eq "2 active hours without progress, and 2 on one goal, add 1.0 each" 20 "$(score_of "$d")"

exit $fail
