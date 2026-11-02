#!/usr/bin/env bash
set -uo pipefail
source "$(cd "$(dirname "$0")" && pwd)/payloads.sh"
DG="$root/hooks/dispatch-guard"
export PLAYBOOK_OPTIN_CHECK=off
dg() { OUT="$(printf '%s' "$1" | bash "$DG" 2>&1)"; RC=$?; }
agent() {
  jq -cn --arg s "$1" --arg d "$2" --arg t "${3:-general-purpose}" --arg a "${4:-}" --arg n "${5:-}" \
    '{hook_event_name:"PreToolUse",session_id:$s,tool_name:"Agent",tool_input:({description:$d,prompt:"do the task",model:"sonnet",subagent_type:$t} + (if $n != "" then {run_in_background:true} else {} end))} + (if $a != "" then {agent_id:$a} else {} end)'
}
wf() { jq -cn --arg s "$1" --arg c "$2" --argjson g "${3:-null}" '{hook_event_name:"PreToolUse",session_id:$s,tool_name:"Workflow",tool_input:({script:$c} + (if $g != null then {args:$g} else {} end))}'; }
send() { jq -cn --arg s "$1" '{hook_event_name:"PreToolUse",session_id:$s,tool_name:"SendMessage",tool_input:{to:"a1",message:"carry on"}}'; }
judge_back() { post "$1" PostToolUse Agent '{"description":"judge: is this sound","subagent_type":"general-purpose","model":"opus"}' '{}'; }
routed() { iso; d="$(sd "$1")"; say "$1" "build the export"; chan "$1" "playbook route interns export lanes"; }

for lv in uneasy:rethink concerned:judge alarmed:ask; do
  routed "g-${lv%%:*}"
  s="g-${lv%%:*}"
  chan "$s" "playbook unease ${lv%%:*} testing the dispatch hold"
  eq "${lv%%:*} sets the ${lv##*:} gate" "${lv##*:}" "$(st "$d" gate)"
  dg "$(agent "$s" "build lane one")"
  eq "${lv%%:*} holds a new Agent dispatch" "2" "$RC"
  has "and the refusal names the level" "(${lv%%:*})"
  dg "$(wf "$s" "await agent('a', {model:'sonnet'})")"
  eq "${lv%%:*} holds a new Workflow" "2" "$RC"
  dg "$(agent "$s" "judge: is the approach sound")"
  eq "${lv%%:*} lets a judge through" "0" "$RC"
  dg "$(agent "$s" "find the callers" Explore)"
  eq "${lv%%:*} lets a read-only lookup through" "0" "$RC"
  dg "$(send "$s")"
  eq "${lv%%:*} lets a message to a running helper through" "0" "$RC"
  dg "$(agent "$s" "sub-worker" general-purpose helper-1)"
  eq "${lv%%:*} leaves a helper's own dispatch alone" "0" "$RC"
done

routed g-rethink2
chan g-rethink2 'playbook unease uneasy grinding'
chan g-rethink2 'playbook rethink split the export into two lanes'
dg "$(agent g-rethink2 "build lane one")"
eq "a rethink releases the uneasy hold on dispatch" "0" "$RC"

routed g-judge2
chan g-judge2 'playbook unease concerned grinding'
judge_back g-judge2
dg "$(agent g-judge2 "build lane one")"
eq "a judge's return releases the concerned hold on dispatch" "0" "$RC"

routed g-ask2
chan g-ask2 'playbook unease alarmed grinding'
dg "$(agent g-ask2 "build lane one")"
has "online, the alarmed refusal sends Claude to a judge" "judge:"
has "and lets it ask the user instead if they're here" "If the user is here, you may ask them in AskUserQuestion instead"
judge_back g-ask2
eq "online, a judge's return clears the alarmed gate" "" "$(st "$d" gate)"
dg "$(agent g-ask2 "build lane one")"
eq "and dispatch resumes" "0" "$RC"
pre_edit g-ask2 /tmp/x.txt
eq "and so do edits" "" "$(decision_of)"

routed g-ask3
chan g-ask3 'playbook unease alarmed grinding'
pre_edit g-ask3 /tmp/x.txt
OUT="$(reason_of)"
has "the alarmed edit refusal also offers a judge first" "consult a judge before more edits"

routed g-off
: > "$d/offline"
chan g-off 'playbook unease alarmed grinding'
dg "$(agent g-off "build lane one")"
has "offline, the alarmed dispatch refusal pushes and waits first" "Push a notification, wait the declared window"

echo "-- GSD agents: unease holds only"
iso; d="$(sd gsd)"; say gsd "run the phase"
gsdp() { jq -cn --arg d "$1" '{hook_event_name:"PreToolUse",session_id:"gsd",tool_name:"Agent",tool_input:{description:$d,prompt:"execute the plan",subagent_type:"gsd-executor"}}'; }
dg "$(gsdp "execute plan 01")"
eq "a GSD agent with no goal, no route and no model is allowed" "0" "$RC"
for r in 1 2 3; do dg "$(gsdp "review phase 3 round $r")"; done
eq "a GSD review series is not held at round 3" "0" "$RC"
chan gsd 'playbook unease concerned grinding'
dg "$(gsdp "execute plan 02")"
eq "a concerned score holds a GSD agent" "2" "$RC"
has "with the unease refusal" "(concerned)"
judge_back gsd
dg "$(gsdp "execute plan 02")"
eq "and a judge releases it" "0" "$RC"

echo "-- go words halve the score but clear no hold"
for w in "great, thanks" "perfect" "go ahead"; do
  routed gw; chan gw 'playbook unease concerned grinding'
  s0="$(score_of "$d")"
  say gw "$w"
  eq "'$w' leaves the concerned hold in place" "judge" "$(st "$d" gate)"
  eq "'$w' still halves the score" "$(( s0 / 2 ))" "$(score_of "$d")"
done
routed gw2; chan gw2 'playbook unease uneasy grinding'
say gw2 "thanks"
eq "'thanks' leaves the uneasy hold until a rethink" "rethink" "$(st "$d" gate)"
routed gw3; chan gw3 'playbook unease alarmed grinding'
say gw3 "yes, a judge isn't needed, carry on with the plan"
eq "your reply still answers an alarmed hold" "" "$(st "$d" gate)"

echo "-- 'preview' is not a review"
iso; d="$(sd pv)"; say pv "fix the layout"; chan pv 'playbook route lone-wolf layout'
for r in 1 2 3; do dg "$(agent pv "Fix preview layout")"; done
eq "a third 'Fix preview layout' is not held as a review round" "0" "$RC"
playbook_match review "Fix preview layout" && flunk "'preview' matches the review pattern" || pass "'preview' does not match the review pattern"
playbook_match review "Re-review the parser" && pass "'re-review' still counts as a review" || flunk "'re-review' no longer counts"
playbook_match review "playbook-review-r3" && pass "a workflow review name still counts" || flunk "a workflow review name no longer counts"

echo "-- back after a permission prompt"
iso; d="$(sd pp)"
export PLAYBOOK_NOW=10000
say pp "build the export"
sig '{"hook_event_name":"Notification","session_id":"pp","notification_type":"permission_prompt","message":"Claude needs your permission to use Bash"}'
eq "a permission prompt marks the user away" "1" "$(st "$d" away)"
export PLAYBOOK_NOW=10600
bash_post pp "ls" 0 "a"
eq "the tool that ran after it marks the user back" "0" "$(st "$d" away)"
eq "and the wait for the answer is not counted as active time" "0" "$(playbook_state_int "$d" active_np 0)"
export PLAYBOOK_NOW=10700
bash_post pp "ls" 0 "a"
eq "later work is counted again" "100" "$(playbook_state_int "$d" active_np 0)"
say pp "going to bed, carry on"
sig '{"hook_event_name":"Notification","session_id":"pp","notification_type":"idle_prompt","message":"waiting"}'
bash_post pp "ls" 0 "a"
eq "an idle notice is not undone by a tool call" "1" "$(st "$d" away)"
unset PLAYBOOK_NOW

echo "-- background tests are neither a pass nor a failure"
iso; d="$(sd bt)"
say bt "fix the parser"
bash_post bt "npm test" 1 "1 failing"
playbook_state_put "$d" "score10=40"
s1=40
post bt PostToolUse Bash '{"command":"npm test","run_in_background":true}' '{"stdout":"Command running in background with ID: b1","stderr":"","interrupted":false}'
eq "a background test launch takes nothing off the score" "$s1" "$(score_of "$d")"
eq "and leaves the failing state in place" "1" "$(st "$d" failed_since_pass)"
bash_post bt "npm test > test.log 2>&1 &" 0 ""
eq "a trailing & launch is neutral too" "$s1" "$(score_of "$d")"
bash_post bt "npm test 2>&1" 0 "ok"
eq "a real pass after failing still takes 3 off" "$(( s1 - 30 ))" "$(score_of "$d")"

echo "-- Workflow scripts: named options objects and template goal lines"
iso; d="$(sd wf)"; say wf "ship the export"
playbook_ns_confirm "$d" "Ship the export" workflows picker
SCR='const OPTS = {model: "sonnet", effort: "low"};
await agent("build it", OPTS)'
dg "$(wf wf "$SCR")"
eq "an options object with a model passed by name counts" "0" "$RC"
SCR='const OPTS = {effort: "low"};
await agent("build it", OPTS)'
dg "$(wf wf "$SCR")"
eq "one without a model still does not" "2" "$RC"
SCR='const NS = "Ship the export";
await agent(`playbook-northstar: ${NS}
build it`, {model: "sonnet"})'
dg "$(wf wf "$SCR")"
eq "a goal line built from a matching constant passes" "0" "$RC"
SCR='const NS = "Ship something else";
await agent(`playbook-northstar: ${NS}
build it`, {model: "sonnet"})'
dg "$(wf wf "$SCR")"
eq "a goal line built from a different constant is refused" "2" "$RC"
SCR='await agent(`playbook-northstar: ${args.goal}
build it`, {model: "sonnet"})'
dg "$(wf wf "$SCR" '{"goal":"Ship the export"}')"
eq "a goal line built from a matching workflow arg passes" "0" "$RC"
dg "$(wf wf "$SCR" '{"goal":"Another goal"}')"
eq "a goal line built from a different workflow arg is refused" "2" "$RC"
SCR='await agent(`playbook-northstar: ${computeGoal()}
build it`, {model: "sonnet"})'
dg "$(wf wf "$SCR")"
eq "a goal line that can't be resolved is not refused" "0" "$RC"

exit $fail
