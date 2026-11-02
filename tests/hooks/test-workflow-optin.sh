#!/usr/bin/env bash
set -uo pipefail
source "$(cd "$(dirname "$0")" && pwd)/payloads.sh"
DG="$root/hooks/dispatch-guard"
SL="$root/scripts/statusline"
unset PLAYBOOK_OPTIN_CHECK
export PLAYBOOK_NOW=1793116000

iso_at() { date -u -r "$1" '+%Y-%m-%dT%H:%M:%S.123Z'; }
T=""
transcript() { T="$SANDBOX/t.jsonl"; : > "$T"; }
kw_at() { printf '{"parentUuid":"p","isSidechain":false,"attachment":{"type":"workflow_keyword_request"},"type":"attachment","timestamp":"%s"}\n' "$(iso_at "$1")" >> "$T"; }
uc() { printf '{"parentUuid":"p","isSidechain":false,"attachment":{"type":"ultra_effort_%s","reminderType":"full"},"type":"attachment","timestamp":"%s"}\n' "$1" "$(iso_at "$PLAYBOOK_NOW")" >> "$T"; }
wf_go() {
  OUT="$(jq -cn --arg s "$1" --arg t "$T" '{hook_event_name:"PreToolUse",session_id:$s,transcript_path:$t,effort:{level:"high"},tool_name:"Workflow",tool_input:{script:"await agent(\"a\", {model:\"sonnet\"})"}}' | bash "$DG" 2>&1)"; RC=$?
}
picked() { iso; d="$(sd "$1")"; transcript; say "$1" "build team accounts"; playbook_ns_confirm "$d" "Team accounts with invites and roles" workflows picker; chan "$1" "playbook route workflows user picked workflows"; }
line_of() { OUT="$(printf '{"session_id":"%s"}' "$1" | PLAYBOOK_GLOBAL_DIR="$GLOBAL_TMP" bash "$SL" 2>/dev/null)"; }

echo "-- picking workflows leaves it awaiting the opt-in"
picked w1
eq "a workflows pick is pending" "pending" "$(st "$d" wf_optin)"
line_of w1; has "the status line says it is awaiting the opt-in" "workflows (awaiting opt-in)"

echo "-- a launch before the user has typed anything"
wf_go w1
eq "is refused" 2 "$RC"
has "and asks for a typed use ultracode after the plan is settled" 'Settle the plan with them first, then ask them to reply "use ultracode", typed rather than pasted'
eq "does not count as a failed opt-in" 0 "$(playbook_state_int "$d" wf_optin_fails 0)"

echo "-- the user types use ultracode and Claude Code records it"
PLAYBOOK_NOW=1793116100 say w1 "use ultracode"
has "the card tells Claude the opt-in was typed" "the user has typed the workflows opt-in"
kw_at 1793116100
PLAYBOOK_NOW=1793116110 wf_go w1
eq "the launch passes" 0 "$RC"
eq "the opt-in is recorded" "ok" "$(st "$d" wf_optin)"
line_of w1; has "the status line now reads workflows" "⚙️ workflows"; hasnt "and no longer awaits" "awaiting"

echo "-- a later turn needs its own opt-in"
PLAYBOOK_NOW=1793116500 say w1 "now do the second half"
PLAYBOOK_NOW=1793116510 wf_go w1
eq "a launch in a later turn without the keyword is refused" 2 "$RC"
line_of w1; has "while the first launch's opt-in still shows workflows" "⚙️ workflows"

echo "-- the keyword does not register, twice"
picked w2
kw_at 1793115000
PLAYBOOK_NOW=1793116100 say w2 "use ultracode"
PLAYBOOK_NOW=1793116110 wf_go w2
eq "a record older than the turn does not count" 2 "$RC"
has "the first miss asks the user to type it again" "did not register with Claude Code. Ask them to type \"use ultracode\" again"
eq "one failed opt-in" 1 "$(st "$d" wf_optin_fails)"
PLAYBOOK_NOW=1793116120 wf_go w2
eq "a retry in the same turn does not count twice" 1 "$(st "$d" wf_optin_fails)"
PLAYBOOK_NOW=1793116200 say w2 "use ultracode"
PLAYBOOK_NOW=1793116210 wf_go w2
eq "the second miss is refused" 2 "$RC"
has "and falls back to /effort ultracode" 'run `/effort ultracode` instead'
has "with the session-wide warning" "stays on for the whole session and pushes towards a workflow on every task"
has "naming the earlier effort level to switch back to" 'switch back with `/effort high`'

echo "-- ultracode switched on"
picked w3
uc enter
wf_go w3
eq "ultracode on lets a launch through without the keyword" 0 "$RC"
uc exit
wf_go w3
eq "ultracode switched off again is no opt-in" 2 "$RC"
printf '{"type":"user","message":{"content":[{"type":"tool_result","content":"\\"attachment\\":{\\"type\\":\\"ultra_effort_enter\\"}"}]}}\n' >> "$T"
wf_go w3
eq "a marker quoted inside a tool result does not count" 2 "$RC"

echo "-- /playbook:workflow is the user's own ask"
picked w4
PLAYBOOK_NOW=1793116100 say w4 "/playbook:workflow add team accounts"
PLAYBOOK_NOW=1793116110 wf_go w4
eq "a launch in the turn the command was typed passes" 0 "$RC"

echo "-- the check can be turned off"
picked w5
OUT="$(jq -cn --arg t "$T" '{hook_event_name:"PreToolUse",session_id:"w5",transcript_path:$t,tool_name:"Workflow",tool_input:{script:"await agent(\"a\", {model:\"sonnet\"})"}}' | PLAYBOOK_OPTIN_CHECK=off bash "$DG" 2>&1)"; RC=$?
eq "PLAYBOOK_OPTIN_CHECK=off skips it" 0 "$RC"

echo "-- routing away while ultracode is on reminds once to switch back"
picked w6
uc enter
sig "$(jq -cn --arg t "$T" '{hook_event_name:"PreToolUse",session_id:"w6",transcript_path:$t,effort:{level:"high"},tool_name:"Bash",tool_input:{command:"playbook route lone-wolf one small fix"}}')"
OUT="$(ctx_of)"; has "the first non-workflow route reminds Claude" 'switch back with `/effort high`'
sig "$(jq -cn --arg t "$T" '{hook_event_name:"PreToolUse",session_id:"w6",transcript_path:$t,effort:{level:"high"},tool_name:"Bash",tool_input:{command:"playbook route lone-wolf another fix"}}')"
OUT="$(ctx_of)"; hasnt "and only once" "switch back with"
sig "$(jq -cn --arg t "$T" '{hook_event_name:"PreToolUse",session_id:"w6",transcript_path:$t,tool_name:"Bash",tool_input:{command:"playbook route workflows the next big feature"}}')"
OUT="$(ctx_of)"; hasnt "a workflows route is not reminded" "switch back with"

echo "-- every agent() call is reminded to carry a model"
picked w7
PLAYBOOK_NOW=1793116100 say w7 "use ultracode"
has "the turn the user types the opt-in" "give every agent() call in the Workflow script a model key, reviewers and verifiers included"
iso; d="$(sd w8)"; say w8 "/playbook:workflow add team accounts"
has "the turn the workflow command is typed" "reviewers and verifiers included"
iso; d="$(sd w9)"; say w9 "build team accounts"
chan w9 "playbook route workflows plannable feature"
OUT="$(ctx_of)"; has "a workflows route" "reviewers and verifiers included"
iso; d="$(sd w10)"; say w10 "fix the typo"
PLAYBOOK_NOW=1793116100 say w10 "fix the typo in the header"
hasnt "an ordinary turn is not" "reviewers and verifiers included"
chan w10 "playbook route lone-wolf one typo"
OUT="$(ctx_of)"; hasnt "nor another route" "reviewers and verifiers included"

echo "-- with a judge overseeing, workflows asks for /effort ultracode"
iso; d="$(sd w11)"; transcript; say w11 "build team accounts overnight"
playbook_offline_set "$d" 1 b 1
playbook_ns_confirm "$d" "Team accounts with invites and roles" workflows picker
sig "$(jq -cn --arg t "$T" '{hook_event_name:"PreToolUse",session_id:"w11",transcript_path:$t,effort:{level:"high"},tool_name:"Bash",tool_input:{command:"playbook route workflows overnight feature build"}}')"
OUT="$(ctx_of)"
has "declaring the route asks for the session-wide switch" 'ask them now to run `/effort ultracode` instead'
has "with the warning" "stays on for the whole session"
has "and the switch-back level for the closing report" 'switch back with `/effort high`'
has "and a way out that never leaves the run waiting" "take the next-ranked mode and log why; never leave the run waiting on it"
wf_go w11
eq "a launch before it is on is refused" 2 "$RC"
has "with the same ask, not the typed word" 'ask them now to run `/effort ultracode` instead'
uc enter
wf_go w11
eq "once ultracode is on the launch passes" 0 "$RC"
iso; d="$(sd w12)"; transcript; say w12 "build team accounts overnight"
playbook_offline_set "$d" 30 a
uc enter
sig "$(jq -cn --arg t "$T" '{hook_event_name:"PreToolUse",session_id:"w12",transcript_path:$t,tool_name:"Bash",tool_input:{command:"playbook route workflows overnight feature build"}}')"
OUT="$(ctx_of)"; hasnt "already on, it is not asked for" "ask them now to run"
iso; d="$(sd w13)"; transcript; say w13 "build team accounts"
sig "$(jq -cn --arg t "$T" '{hook_event_name:"PreToolUse",session_id:"w13",transcript_path:$t,tool_name:"Bash",tool_input:{command:"playbook route workflows plannable feature"}}')"
OUT="$(ctx_of)"; hasnt "the user overseeing is asked for the typed word as usual" "ask them now to run"

echo "-- the missing-model refusal names the call"
iso
OUT="$(jq -cn '{hook_event_name:"PreToolUse",session_id:"m1",tool_name:"Workflow",tool_input:{script:"const a = await agent(\"build\", { label: \"build:x\", model: \"sonnet\" })\nconst b = await agent(\"review\",\n  { label: \"review:x\", phase: \"Review\" })"}}' | PLAYBOOK_OPTIN_CHECK=off bash "$DG" 2>&1)"; RC=$?
eq "a call with no model is refused" 2 "$RC"
has "naming its script line and label" "the agent() call at script line 2 (label review:x) sets no model"

exit "$fail"
