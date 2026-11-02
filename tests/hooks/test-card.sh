#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/payloads.sh"
FIX="$root/tests/hooks/fixtures"
T="$FIX/transcript-beat.jsonl"   # 700020 tokens used
B="$FIX/transcript-basic.jsonl"  # 10020 tokens used
CARD="📚 Playbook: new work? Goal still right?"

prompt() { tb "$(jq -cn --arg s "$1" --arg t "$2" '{hook_event_name:"UserPromptSubmit",session_id:$s,prompt:$t}')"; }
batch()  { tb "$(jq -cn --arg s "$1" --arg t "$2" --arg a "${3:-}" '{hook_event_name:"PostToolBatch",session_id:$s,transcript_path:$t} + (if $a != "" then {agent_id:$a} else {} end)')"; }
compact() { tb "$(jq -cn --arg s "$1" '{hook_event_name:"SessionStart",source:"compact",session_id:$s}')"; }

# --- the card ---------------------------------------------------------------
iso; d="$(sd c)"
prompt c "Add a dark mode toggle."
eq "the card is exactly one line" "$CARD" "$(ctx_of)"
eq "emitted as UserPromptSubmit context" UserPromptSubmit "$(jq -r .hookSpecificOutput.hookEventName <<<"$OUT")"
eq "one JSON document per prompt" 1 "$(jq -s length <<<"$OUT")"
prompt c "<task-notification>background job finished</task-notification>"
eq "a non-user prompt still gets exactly the card" "$CARD" "$(ctx_of)"
eq "and is not stored as the user's words" 1 "$(wc -l < "$d/human.jsonl" | tr -d ' ')"
hasnt "the card never carries the old rules" "Divide your felt time"
hasnt "or an original request" "Original request"

# --- events ride the next prompt once ---------------------------------------
iso; d="$(sd ev)"
playbook_decision_add "$d" asked "Run live checks?" "Run, capped at 40"
prompt ev "carry on"
OUT="$(ctx_of)"
has "a recorded decision reaches the next prompt" 'Playbook decision recorded, verbatim: "Run, capped at 40"'
has "after the card" "$CARD"
prompt ev "and again"
eq "and is not repeated" "$CARD" "$(ctx_of)"

# --- branch notice ---------------------------------------------------------
iso
sleep 60 & owner=$!
base="$SANDBOX/br"; mkdir -p "$base"; echo "$owner" > "$base/owner"
printf 'score10=30\nns_goal=keep me\nns_state=confirmed\n' > "$base/state"
OUT="$(printf '{"hook_event_name":"UserPromptSubmit","session_id":"br","prompt":"hello"}' | CLAUDE_PID=$$ PLAYBOOK_OWNER_COMM=sleep bash "$TB" 2>/dev/null)"
has "a branched terminal tells the user once" "branched from a session that is still running"
has "alongside the card" "$CARD"
eq "on its own copy of the state" 30 "$(playbook_state_int "$base/branch-$$" score10 0)"
OUT="$(printf '{"hook_event_name":"UserPromptSubmit","session_id":"br","prompt":"hello again"}' | CLAUDE_PID=$$ PLAYBOOK_OWNER_COMM=sleep bash "$TB" 2>/dev/null)"
hasnt "the notice is not repeated" "branched"
eq "the parent's state is untouched" "" "$(st "$base" branch_notice)"
kill "$owner" 2>/dev/null; wait "$owner" 2>/dev/null

# --- compaction restore -----------------------------------------------------
iso; d="$(sd cp)"
say cp "Build the CSV exporter. Never touch the legacy importer."
playbook_decision_add "$d" asked "Merge policy?" "Merge only after I say so"
playbook_ns_confirm "$d" "Ship the CSV exporter" interns picker
playbook_route_set "$d" interns "three independent lanes"
playbook_state_put "$d" score10=70 calm_fired=1 nudge200_fired=1
playbook_gate_set "$d" rethink
compact cp
ctx="$(ctx_of)"; OUT="$ctx"
eq "the restore is SessionStart context" SessionStart "$(compact cp; jq -r .hookSpecificOutput.hookEventName <<<"$OUT")"
OUT="$ctx"
has "the confirmed goal returns" "Confirmed goal: Ship the CSV exporter"
has "with the mode and route" "Mode: interns (three independent lanes)"
has "the user's verbatim words return" "Never touch the legacy importer."
has "the decisions return verbatim" 'Answer: "Merge only after I say so"'
has "the score and level return" "Unease: uneasy, score 7.0"
has "with the gate" "gate: rethink"
has "it tells the model to resume" "compaction is not a reason to stop"
[ "${#ctx}" -lt 9000 ] && pass "the restore is under 9,000 characters" || flunk "restore is ${#ctx} characters"
eq "calm_fired is reset" 0 "$(playbook_state_int "$d" calm_fired 9)"
eq "nudge200_fired is reset" 0 "$(playbook_state_int "$d" nudge200_fired 9)"
eq "compaction keeps the score" 70 "$(score_of "$d")"

iso; d="$(sd cp2)"
compact cp2; OUT="$(ctx_of)"
has "with no goal it says so" "No confirmed goal."
has "and still tells it to resume" "compaction is not a reason to stop"

iso; d="$(sd cp3)"
playbook_ns_confirm "$d" "g" lone-wolf picker
playbook_ns_mark "$d" stale "gap"
compact cp3; OUT="$(ctx_of)"
has "a stale goal is labelled stale, not confirmed" "awaiting re-confirmation (stale)"

iso; d="$(sd big)"
playbook_ns_confirm "$d" "big goal" lone-wolf picker
long="$(head -c 5000 /dev/zero | tr '\0' 'w')"
for i in 1 2 3 4 5 6 7 8; do playbook_decision_add "$d" asked "Q$i" "$long"; done
for i in 1 2 3 4 5 6; do printf '%s\n' "$(jq -cn --arg t "$long" '{at:1,text:$t}')" >> "$d/ns_words.jsonl"; done
compact big; ctx="$(ctx_of)"
[ -n "$ctx" ] && [ "${#ctx}" -le 9000 ] && pass "an oversized restore is cut under 9,000 characters (${#ctx})" || flunk "oversized restore is ${#ctx}"
OUT="$ctx"; has "and still ends with the resume line" "compaction is not a reason to stop"

# --- context events ---------------------------------------------------------
iso; d="$(sd ctx)"
batch ctx "$B"; silent "a small context is silent"
batch ctx "$T"
has "passing 200k queues the fresh-session nudge" "context has passed 200k tokens"
has "naming the handover" "fresh session with a short handover"
has "and never stopping mid-task" "never stop mid-task for it"
batch ctx "$T"; silent "the 200k nudge fires once per compaction cycle"
hasnt "no pulse exists" "pulse"
compact ctx
batch ctx "$T"
has "after compaction the nudge may fire again" "context has passed 200k tokens"

iso; d="$(sd calm)"
OUT="$(printf '{"hook_event_name":"PostToolBatch","session_id":"calm","transcript_path":"%s"}' "$T" | PLAYBOOK_WINDOW=800000 bash "$TB" 2>/dev/null)"
has "past the calm percentage the calm note fires" "Playbook context calm"
has "with the anti-scare core" "Auto-compact is seamless"
hasnt "without telling it not to wrap up" "wrap up early"
OUT="$(printf '{"hook_event_name":"PostToolBatch","session_id":"calm","transcript_path":"%s"}' "$T" | PLAYBOOK_WINDOW=800000 bash "$TB" 2>/dev/null)"
silent "and only once per cycle"
OUT="$(printf '{"hook_event_name":"PostToolBatch","session_id":"calm","transcript_path":"%s"}' "$T" | PLAYBOOK_WINDOW=800000 PLAYBOOK_CALM_PCT=99 bash "$TB" 2>/dev/null)"
silent "PLAYBOOK_CALM_PCT is honoured"

iso; d="$(sd hb)"
batch hb "$T" helper1; silent "a helper's batch is silent"
eq "and uncounted" 0 "$(playbook_state_int "$d" batches_np 0)"
batch hb "$B"
eq "a main-thread batch is counted" 1 "$(playbook_state_int "$d" batches_np 0)"

iso; d="$(sd batchev)"
playbook_state_put "$d" score10=45 batches_np=59
batch batchev "$B"
has "a batch that crosses a level announces it" "Playbook unease: uneasy"

exit $fail
