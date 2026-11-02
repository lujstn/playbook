#!/usr/bin/env bash
set -uo pipefail
export HOME="$(mktemp -d)"
source "$(cd "$(dirname "$0")" && pwd)/payloads.sh"
export PLAYBOOK_NOW=1793116000

PICKER='[{"question":"Goal: add team accounts · Mode: which one runs it? gsd ranks fifth.","header":"Mode","multiSelect":false,"options":[{"label":"workflows (Recommended)","description":"plannable medium feature"},{"label":"lone-wolf","description":"one hand"},{"label":"interns","description":"not repetitive"},{"label":"hackathon","description":"no specialisms"}]},{"question":"Oversight: will you oversee this, or should a judge oversee it in the background?","header":"Oversight","multiSelect":false,"options":[{"label":"You'"'"'ll oversee","description":"You review progress and decisions yourself."},{"label":"Defer to a judge after 10 mins waiting","description":"ten minutes"},{"label":"Defer to a judge after 30 mins waiting","description":"thirty minutes"},{"label":"Autonomous development","description":"no alerts"}]}]'
GQ='Goal: add team accounts · Mode: which one runs it? gsd ranks fifth.'
OQ='Oversight: will you oversee this, or should a judge oversee it in the background?'

ask_pre() { sig "$(jq -cn --arg s "$1" --argjson q "$PICKER" --arg a "${2:-}" '{hook_event_name:"PreToolUse",session_id:$s,tool_name:"AskUserQuestion",tool_use_id:"tu1",tool_input:{questions:$q}} + (if $a != "" then {agent_id:$a} else {} end)')"; }
ask_post() { sig "$(jq -cn --arg s "$1" --argjson q "$PICKER" --argjson r "$2" '{hook_event_name:"PostToolUse",session_id:$s,tool_name:"AskUserQuestion",tool_use_id:"tu1",tool_input:{questions:$q},tool_response:$r}')"; }
answered() { jq -cn --arg g "$GQ" --arg o "$OQ" --arg ga "$1" --arg oa "$2" '{answers:{($g):$ga, ($o):$oa}}'; }

echo "-- the oversight answer switches offline behaviour"
iso; d="$(sd o1)"
ask_post o1 "$(answered workflows "You'll oversee")"
eq "You'll oversee leaves offline off" "no" "$(playbook_offline_on "$d" && echo yes || echo no)"
eq "the goal is the user's pick" "picker" "$(st "$d" ns_source)"
grep -qF "Judge" "$d/decisions.txt" 2>/dev/null; grep -qF "You'll oversee" "$d/decisions.txt" && pass "the oversight answer is recorded as the user's decision" || flunk "oversight decision missing"
ask_post o1 "$(answered workflows "Autonomous development")"
eq "Autonomous development turns offline on" "yes" "$(playbook_offline_on "$d" && echo yes || echo no)"
eq "with no wait" "b" "$(playbook_offline_get "$d" wait)"
eq "and no pushes" "1" "$(playbook_offline_get "$d" quiet)"
ask_post o1 "$(answered workflows "Defer to a judge after 10 mins waiting")"
eq "A ten-minute deferral waits" "a" "$(playbook_offline_get "$d" wait)"
eq "for ten minutes" "10" "$(playbook_offline_get "$d" window)"
ask_post o1 "$(answered workflows "Defer to a judge after 30 mins waiting")"
eq "A thirty-minute deferral waits thirty" "30" "$(playbook_offline_get "$d" window)"
ask_post o1 "$(answered workflows "You'll oversee")"
eq "You'll oversee again turns it off" "no" "$(playbook_offline_on "$d" && echo yes || echo no)"

echo "-- online, a question opens as usual"
iso; ask_pre o2
silent "the hook stays out of the way"

echo "-- a judge in the background: the question is answered, never shown"
iso; d="$(sd o3)"; playbook_offline_set "$d" 1 b
ask_pre o3
eq "the dialog is allowed with answers filled in" "allow" "$(decision_of)"
eq "the goal question takes the recommended option" "workflows (Recommended)" "$(jq -r --arg g "$GQ" '.hookSpecificOutput.updatedInput.answers[$g]' <<<"$OUT")"
eq "an unmarked question takes its first option" "You'll oversee" "$(jq -r --arg o "$OQ" '.hookSpecificOutput.updatedInput.answers[$o]' <<<"$OUT")"
has "the user is shown what was taken" "📴 Playbook answered for you"
has "Claude is told to consult a judge before acting on it" "consult a judge"
playbook_gate_set "$d" judge
ask_post o3 "$(answered "workflows (Recommended)" "You'll oversee")"
eq "the goal is confirmed as taken offline" "offline" "$(st "$d" ns_source)"
eq "the mode is the recommended one" "workflows" "$(st "$d" ns_mode)"
[ ! -s "$d/decisions.txt" ] && pass "an answer Playbook took is never recorded as the user's decision" || flunk "auto answer recorded as a decision"
grep -q 'Took the recommended answer without the user' "$d/offline-log.jsonl" && pass "it is logged for the morning" || flunk "not logged"
eq "an answer Playbook took does not release a held gate" "judge" "$(st "$d" gate)"
eq "a taken oversight answer does not switch offline off" "yes" "$(playbook_offline_on "$d" && echo yes || echo no)"

echo "-- autonomous development answers without alerting the user"
pushes() {
  local fake; fake="$(mktemp -d)"; mkdir -p "$fake/scripts"
  printf '#!/usr/bin/env bash\ntouch "%s/pushed"\n' "$fake" > "$fake/scripts/notify"
  CLAUDE_PLUGIN_ROOT="$fake" ask_pre "$1"
  for _ in 1 2 3 4 5 6 7 8 9 10; do [ -f "$fake/pushed" ] && break; sleep 0.1; done
  [ -f "$fake/pushed" ] && echo yes || echo no
}
iso; d="$(sd o3p)"; playbook_offline_set "$d" 1 b
eq "a judge with no wait still pushes the answer to the phone" "yes" "$(pushes o3p)"
iso; d="$(sd o3q)"; playbook_offline_set "$d" 1 b 1
eq "autonomous development never alerts the user" "no" "$(pushes o3q)"
ask_pre o3q
eq "and answers the same way" "allow" "$(decision_of)"

echo "-- a window: the question is pushed and held, not shown"
iso; d="$(sd o4)"; playbook_offline_set "$d" 30 a
ask_pre o4
eq "the dialog is refused" "deny" "$(decision_of)"
OUT="$(reason_of)"
has "Claude waits the window in the background" 'sleep 1800'
has "and asks the question in its reply too" "Ask it in your reply too"
has "and carries on with work that does not depend on it" "carry on with work that does not depend on the answer"
has "then takes the recommendation" "workflows (Recommended)"
has "decisions and nice-to-haves still wait for the user" "Going against one of the user's decisions is never a judge's call."

echo "-- a helper's question is never intercepted"
iso; d="$(sd o5)"; playbook_offline_set "$d" 1 b
ask_pre o5 a-helper
silent "helpers are left alone"

echo "-- a goal picker that closed on Claude Code's idle timeout waits for the user"
iso; d="$(sd o6)"
ask_post o6 '{"answers":{},"afkTimeoutMs":300000}'
OUT="$(ctx_of)"
eq "no goal is taken" "" "$(st "$d" ns_goal)"
eq "no mode is taken" "" "$(st "$d" ns_mode)"
eq "oversight does not pass to a judge" "no" "$(playbook_offline_on "$d" && echo yes || echo no)"
[ ! -s "$d/decisions.txt" ] && pass "nothing is recorded as the user's decision" || flunk "expired picker recorded as a decision"
has "Claude is told the work waits for the user" "new work never starts without the user's pick"
has "and to end its turn" "end your turn, and ask again when they reply"
grep -q 'the work waits for the user' "$d/offline-log.jsonl" && pass "the log says why" || flunk "no expiry log"
iso; d="$(sd o7)"
ask_post o7 "$(jq -cn --arg g "$GQ" '{answers:{($g):"lone-wolf"},afkTimeoutMs:300000}')"
OUT="$(ctx_of)"
eq "an option selected but never submitted is not taken either" "" "$(st "$d" ns_mode)"
has "but Claude is told what they had selected" "they had selected ${GQ}: lone-wolf"

echo "-- any other question that closed on the idle timeout hands oversight to a judge"
OTHER='[{"question":"Which config filename should plugins use?","header":"Config","multiSelect":false,"options":[{"label":"storekit.config.json (Recommended)","description":"repo root"},{"label":".storekitrc","description":"dotfile"}]}]'
iso; d="$(sd o8)"
playbook_gate_set "$d" judge
sig "$(jq -cn --argjson q "$OTHER" '{hook_event_name:"PostToolUse",session_id:"o8",tool_name:"AskUserQuestion",tool_use_id:"tu2",tool_input:{questions:$q},tool_response:{answers:{},afkTimeoutMs:300000}}')"
OUT="$(ctx_of)"
eq "a judge oversees from here" "b" "$(playbook_offline_get "$d" wait)"
[ ! -s "$d/decisions.txt" ] && pass "the recommendation is not recorded as the user's decision" || flunk "expired answer recorded as a decision"
eq "a held gate stays held" "judge" "$(st "$d" gate)"
grep -q 'closed unanswered after 300s' "$d/offline-log.jsonl" && pass "the log says why" || flunk "no expiry log"
has "Claude is told the user is away and a judge oversees" "the question closed unanswered after 300s"

exit "$fail"
