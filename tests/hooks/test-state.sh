#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/payloads.sh"

# --- keys and values --------------------------------------------------------
iso; d="$SANDBOX/k"
playbook_state_put "$d" "a=1" "b=x=y"
eq "a value may contain '='" "x=y" "$(st "$d" b)"
playbook_state_put "$d" "a=2"
eq "a put replaces its key" 2 "$(st "$d" a)"
eq "and keeps the others" "x=y" "$(st "$d" b)"
playbook_state_put "$d" "b="
eq "a blank put clears a key" "" "$(st "$d" b)"
eq "a missing key reads empty" "" "$(st "$d" nope)"
eq "int falls back on junk" 7 "$(playbook_state_int "$d" b 7)"
eq "no torn temp files survive" 0 "$(ls -A "$d" | grep -c '\.tmp$')"

# --- session ids ------------------------------------------------------------
eq "the session id is read from the payload" abc "$(playbook_session_id '{"session_id":"abc"}')"
eq "falling back on the transcript name" tr1 "$(playbook_session_id '{"transcript_path":"/x/tr1.jsonl"}')"
eq "unknown otherwise" unknown "$(playbook_session_id '{}')"
eq "unsafe characters are stripped" "abc" "$(playbook_session_id '{"session_id":"a/../bc"}' | tr -d '.')"

# --- one state dir per live process ----------------------------------------
iso
sleep 60 & p1=$!
sleep 60 & p2=$!
export PLAYBOOK_OWNER_COMM=sleep
S='{"session_id":"proc"}'
base="$(CLAUDE_PID=$p1 playbook_live_dir "$S")"
eq "the first process owns the session dir" "$SANDBOX/proc" "$base"
playbook_state_put "$base" "score10=40" "ns_goal=carry me"
: > "$base/offline"; echo '{}' > "$base/offline-log.jsonl"
eq "the same process gets the same dir" "$base" "$(CLAUDE_PID=$p1 playbook_live_dir "$S")"
br="$(CLAUDE_PID=$p2 playbook_live_dir "$S")"
eq "a second live process gets its own branch dir" "$base/branch-$p2" "$br"
eq "with a copy of the state" 40 "$(playbook_state_int "$br" score10 0)"
eq "and the goal" "carry me" "$(st "$br" ns_goal)"
eq "and a one-time notice flag" 1 "$(st "$br" branch_notice)"
eq "the offline flag is not copied" 0 "$([ -f "$br/offline" ] && echo 1 || echo 0)"
eq "nor the offline log" 0 "$([ -f "$br/offline-log.jsonl" ] && echo 1 || echo 0)"
playbook_state_put "$br" "score10=90"
eq "the branch diverges without touching its parent" 40 "$(playbook_state_int "$base" score10 0)"
eq "the branch is stable on the next call" "$br" "$(CLAUDE_PID=$p2 playbook_live_dir "$S")"
kill $p1 2>/dev/null; wait $p1 2>/dev/null
iso
sleep 0.2 & dead=$!; wait $dead 2>/dev/null
mkdir -p "$SANDBOX/proc2"; echo "$dead" > "$SANDBOX/proc2/owner"
playbook_state_put "$SANDBOX/proc2" "score10=33"
eq "a dead owner means a resume: the newcomer takes over" "$SANDBOX/proc2" "$(CLAUDE_PID=$p2 playbook_live_dir '{"session_id":"proc2"}')"
eq "and the state carries on" 33 "$(playbook_state_int "$SANDBOX/proc2" score10 0)"
eq "ownership moves to the newcomer" "$p2" "$(cat "$SANDBOX/proc2/owner")"
kill $p2 2>/dev/null; wait $p2 2>/dev/null
unset PLAYBOOK_OWNER_COMM

# --- agent dirs -------------------------------------------------------------
iso
live="$(playbook_live_dir '{"session_id":"ag"}')"
eq "a helper's state sits under the live dir" "$live/agents/h1" "$(playbook_state_dir '{"session_id":"ag","agent_id":"h1"}')"
eq "the main thread's is the live dir" "$live" "$(playbook_state_dir '{"session_id":"ag"}')"
eq "an agent id is made path-safe" "$live/agents/x" "$(playbook_state_dir '{"session_id":"ag","agent_id":"../x"}' | sed 's/\.\.//')"
eq "team state is keyed under the live dir" "$live/team/web" "$(playbook_team_dir '{"session_id":"ag"}' web)"

# --- events -----------------------------------------------------------------
iso; d="$SANDBOX/ev"; mkdir -p "$d"
playbook_event_push "$d" "one"; playbook_event_push "$d" "two"; playbook_event_push "$d" "one"
eq "events drain once, deduplicated, in order" "one

two" "$(playbook_event_drain "$d")"
eq "and are gone after" "" "$(playbook_event_drain "$d")"
for i in 1 2 3 4 5 6; do playbook_event_push "$d" "e$i"; done
for i in 1 2 3 4; do ( playbook_event_drain "$d" > "$SANDBOX/drain.$i" ) & done; wait
eq "four concurrent drains deliver the queue exactly once" 1 "$(cat "$SANDBOX"/drain.* | grep -c '^e1$')"

# --- the lock ---------------------------------------------------------------
iso; d="$SANDBOX/lk"; mkdir -p "$d"
bump() { ( source "$root/hooks/lib/playbook-common.sh"; playbook_lock "$d"; n=$(playbook_state_int "$d" n 0); sleep 0.01; playbook_state_put "$d" "n=$((n+1))" ) ; }
for i in 1 2 3 4 5 6 7 8; do bump & done; wait
eq "eight concurrent read-modify-writes lose nothing under the lock" 8 "$(playbook_state_int "$d" n 0)"
eq "and release the lock" 0 "$([ -d "$d/.lock" ] && echo 1 || echo 0)"

# --- gc ---------------------------------------------------------------------
iso
mkdir -p "$SANDBOX/old" "$SANDBOX/new"; touch -t 202001010000 "$SANDBOX/old"
playbook_state_gc
eq "state older than a week is collected" 0 "$([ -d "$SANDBOX/old" ] && echo 1 || echo 0)"
eq "recent state is kept" 1 "$([ -d "$SANDBOX/new" ] && echo 1 || echo 0)"

# --- /clear -----------------------------------------------------------------
iso; d="$(sd rs)"
playbook_ns_confirm "$d" g interns picker; playbook_decision_add "$d" a q a >/dev/null
say rs "hello there"
playbook_state_put "$d" score10=90 gate=judge calm_fired=1 away=1
playbook_conversation_reset "$d"
eq "a reset zeroes the score" 0 "$(score_of "$d")"
eq "clears the goal state" "" "$(playbook_ns_state "$d")"
eq "clears the gate" "" "$(playbook_gate "$d")"
eq "re-arms the calm note" 0 "$(playbook_state_int "$d" calm_fired 9)"
eq "forgets the user's words" 0 "$([ -e "$d/human.jsonl" ] && echo 1 || echo 0)"
eq "forgets the decisions" 0 "$([ -e "$d/decisions.jsonl" ] && echo 1 || echo 0)"

exit $fail
