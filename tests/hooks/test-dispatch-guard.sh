#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
H="$root/hooks/dispatch-guard"
export CLAUDE_PLUGIN_ROOT="$root"
export PLAYBOOK_STATE_DIR="$(mktemp -d)"
export PLAYBOOK_OPTIN_CHECK=off
export PLAYBOOK_NOW=1000000
unset CLAUDE_PID
FAKEHOME="$(mktemp -d)"
export HOME="$FAKEHOME"
SID=s1
EMPTY_OBJ="{}"
. "$root/hooks/lib/playbook-common.sh"
LIVE="$PLAYBOOK_STATE_DIR/$SID"
mkdir -p "$LIVE"

fail=0
GUARD_OUT=""
GUARD_RC=0

guard() { GUARD_OUT="$(printf '%s' "$1" | bash "$H" 2>&1)" && GUARD_RC=0 || GUARD_RC=$?; }
guard_off() { GUARD_OUT="$(printf '%s' "$1" | PLAYBOOK_DISPATCH_GUARD=off bash "$H" 2>&1)" && GUARD_RC=0 || GUARD_RC=$?; }

# Agent payload: subagent_type, prompt, model, description, extra JSON object
agent_payload() {
  jq -cn --arg st "$1" --arg p "$2" --arg m "$3" --arg d "$4" --argjson x "${5:-$EMPTY_OBJ}" --arg sid "$SID" \
    '{session_id:$sid, tool_name:"Agent", tool_input:(({prompt:$p}
      + (if $st == "" then {} else {subagent_type:$st} end)
      + (if $m == "" then {} else {model:$m} end)
      + (if $d == "" then {} else {description:$d} end)) + $x)}'
}
wf_script() { jq -cn --arg s "$1" --arg sid "$SID" '{session_id:$sid, tool_name:"Workflow", tool_input:{script:$s}}'; }
sendmsg() { jq -cn --arg m "$1" --arg sid "$SID" '{session_id:$sid, tool_name:"SendMessage", tool_input:{to:"x", message:$m}}'; }

ok() { echo "PASS: $1"; }
bad() { echo "FAIL: $1 [rc=$GUARD_RC] [$GUARD_OUT]"; fail=1; }
blocks() { guard "$2"; [ "$GUARD_RC" -eq 2 ] && ok "$1" || bad "$1"; }
allows() { guard "$2"; [ "$GUARD_RC" -eq 0 ] && ok "$1" || bad "$1"; }
says() { grep -qF -- "$2" <<<"$GUARD_OUT" && ok "$1" || bad "$1 (missing: $2)"; }
silent() { [ -z "$GUARD_OUT" ] && ok "$1" || bad "$1"; }

reset() {
  rm -rf "${PLAYBOOK_STATE_DIR:?}/${SID:?}"; mkdir -p "$LIVE"
}
confirm() { reset; playbook_ns_confirm "$LIVE" "$1" "${2:-lone-wolf}" picker; }
route() { reset; playbook_route_set "$LIVE" "$1" "because"; }

GOAL="Ship a working login page end to end"
NS="playbook-northstar: $GOAL"

echo "-- the kill switch"
reset
guard_off "$(agent_payload "" "no model, no goal" "" "")"
[ "$GUARD_RC" -eq 0 ] && silent "PLAYBOOK_DISPATCH_GUARD=off disables the guard" || bad "kill switch"

echo "-- model enforcement: Agent"
confirm "$GOAL"
blocks "an Agent call with no model is blocked" "$(agent_payload "" "Build it." "" "build")"
says "the model block names the rule" "Sonnet builds and checks, Opus plans and judges."
allows "an Agent call with a model passes" "$(agent_payload "" "Build it." sonnet "build")"
for t in Explore Plan claude-code-guide statusline-setup gsd-executor; do
  reset
  allows "exempt type $t skips model and goal checks" "$(agent_payload "$t" "look" "" "look around")"
  says "exempt type $t still shows the dispatch line" "Playbook dispatch"
done

echo "-- model enforcement: Workflow scripts (heuristic: each agent( call, up to the next agent(, must hold a model key; a spread of an options object declared with model counts)"
confirm "$GOAL"
SCR='await agent("a", {model: "sonnet"}); await agent("b", {prompt:"x", model:"opus"})'
allows "every agent() has a model" "$(wf_script "$SCR")"
SCR='await agent("a", {model: "sonnet"}); await agent("b", {prompt:"x"})'
blocks "one agent() lacks a model" "$(wf_script "$SCR")"
says "the workflow block names the rule" "Sonnet builds and checks, Opus plans and judges."
allows "shorthand model key counts" "$(wf_script "const model='opus'; await agent('a', {model})")"
SCR='const opts = {model: "sonnet", effort: "low"};
await agent("a", {...opts, prompt: "x"})'
allows "a spread of an options object with model counts" "$(wf_script "$SCR")"
SCR='const opts = {effort: "low"};
await agent("a", {...opts, prompt: "x"})'
blocks "a spread of an options object without model does not count" "$(wf_script "$SCR")"
allows "a script with no agent() calls passes" "$(wf_script "console.log('hi')")"
mkdir -p "$FAKEHOME/w" "$FAKEHOME/proj/.claude/workflows" "$FAKEHOME/.claude/workflows"
printf "await agent('a', {prompt:'x'})\n" > "$FAKEHOME/w/bad.js"
printf "await agent('a', {prompt:'x', model:'sonnet'})\n" > "$FAKEHOME/w/good.js"
blocks "scriptPath to a script lacking a model is blocked" "$(jq -cn --arg p "$FAKEHOME/w/bad.js" --arg sid "$SID" '{session_id:$sid,tool_name:"Workflow",tool_input:{scriptPath:$p}}')"
allows "scriptPath to a script with models passes" "$(jq -cn --arg p "$FAKEHOME/w/good.js" --arg sid "$SID" '{session_id:$sid,tool_name:"Workflow",tool_input:{scriptPath:$p}}')"
printf "await agent('a', {prompt:'x'})\n" > "$FAKEHOME/proj/.claude/workflows/named-bad.js"
printf "await agent('a', {prompt:'x', model:'opus'})\n" > "$FAKEHOME/.claude/workflows/named-good.mjs"
blocks "a named project workflow lacking a model is blocked" "$(jq -cn --arg c "$FAKEHOME/proj" --arg sid "$SID" '{session_id:$sid,cwd:$c,tool_name:"Workflow",tool_input:{name:"named-bad"}}')"
allows "a named user workflow with models passes" "$(jq -cn --arg c "$FAKEHOME/proj" --arg sid "$SID" '{session_id:$sid,cwd:$c,tool_name:"Workflow",tool_input:{name:"named-good"}}')"
allows "a named workflow that cannot be found fails open" "$(jq -cn --arg sid "$SID" '{session_id:$sid,tool_name:"Workflow",tool_input:{name:"nope"}}')"
allows "a scriptPath that does not exist fails open" "$(jq -cn --arg sid "$SID" '{session_id:$sid,tool_name:"Workflow",tool_input:{scriptPath:"/nonexistent/x.js"}}')"

echo "-- North Star: confirmed goal"
confirm "$GOAL"
allows "a matching playbook-northstar line passes" "$(agent_payload "" "Do it.
$NS" sonnet "d")"
allows "a match ignores case, spacing and trailing punctuation" "$(agent_payload "" "Do it.
playbook-northstar:   ship A working   login page end to end.  " sonnet "d")"
blocks "a mismatching line is blocked" "$(agent_payload "" "Do it.
playbook-northstar: rewrite the billing engine" sonnet "d")"
says "the mismatch quotes the current goal" "$GOAL"
allows "no line at all passes (the hook carries it)" "$(agent_payload "" "Do it." sonnet "d")"
allows "a deliberate none line passes (it carries no wrong goal)" "$(agent_payload "" "Do it.
playbook-northstar: none (task-only)" sonnet "d")"
blocks "a mismatching line in a Workflow script is blocked" "$(wf_script "// playbook-northstar: something else entirely
await agent('a', {model:'sonnet'})")"
blocks "a mismatching line in Workflow args is blocked" "$(jq -cn --arg sid "$SID" '{session_id:$sid,tool_name:"Workflow",tool_input:{script:"await agent(\"a\", {model:\"sonnet\"})",args:{note:"playbook-northstar: other goal"}}}')"
allows "a matching line in a Workflow script passes" "$(wf_script "// $NS
await agent('a', {model:'sonnet'})")"
echo "-- North Star: SendMessage gets the match check only"
allows "SendMessage with a matching line passes" "$(sendmsg "$NS
please continue")"
blocks "SendMessage with a mismatching line is blocked" "$(sendmsg "playbook-northstar: wrong goal")"
says "the SendMessage mismatch quotes the goal" "$GOAL"
allows "SendMessage with no line passes" "$(sendmsg "please continue")"
reset
allows "SendMessage with no goal confirmed and no line passes" "$(sendmsg "please continue")"
silent "SendMessage prints no dispatch line"

echo "-- North Star: unconfirmed, stale, done, route"
reset
blocks "no goal and no route is blocked" "$(agent_payload "" "Do it." sonnet "d")"
says "the block teaches the picker and the route line" 'Run the picker (AskUserQuestion whose question starts `Goal: … · Mode:`'
says "the block names the single-option route" 'playbook route <mode> <reason>'
says "the block opens with the required text" "No confirmed goal."
confirm "$GOAL"; playbook_ns_mark "$LIVE" stale "a merge landed"
blocks "a stale goal is blocked" "$(agent_payload "" "Do it." sonnet "d")"
says "the stale block quotes the goal" "$GOAL"
confirm "$GOAL"; playbook_ns_mark "$LIVE" done "x"
blocks "a done goal is blocked" "$(agent_payload "" "Do it." sonnet "d")"
allows "an exempt read-only type still passes under done" "$(agent_payload "Explore" "look" "" "look")"
confirm "$GOAL"; playbook_ns_mark "$LIVE" stale "x"; PLAYBOOK_NOW=1000010 playbook_route_set "$LIVE" lone-wolf "single mode"
allows "a live route allows without a goal after stale" "$(agent_payload "" "Do it." sonnet "d")"
confirm "$GOAL"; playbook_ns_mark "$LIVE" done "x"; PLAYBOOK_NOW=1000010 playbook_route_set "$LIVE" lone-wolf "single mode"
allows "a live route allows without a goal after done" "$(agent_payload "" "Do it." sonnet "d")"
route lone-wolf
allows "a route with no goal allows" "$(agent_payload "" "Do it." sonnet "d")"
allows "a Workflow under a route passes" "$(wf_script "await agent('a', {model:'sonnet'})")"
reset
blocks "a Workflow with no goal and no route is blocked" "$(wf_script "await agent('a', {model:'sonnet'})")"

echo "-- Teams (the user's decision C)"
for m in lone-wolf interns; do
  route "$m"
  blocks "a named Agent is refused under $m" "$(agent_payload "" "Do it." sonnet "d" '{"name":"alice"}')"
  blocks "a team_name Agent is refused under $m" "$(agent_payload "" "Do it." sonnet "d" '{"team_name":"t"}')"
  allows "an unnamed background Agent is allowed under $m" "$(agent_payload "" "Do it." sonnet "d" '{"run_in_background":true}')"
done
route interns; guard "$(agent_payload "" "x" sonnet "d" '{"name":"alice"}')"
says "the teams refusal names the decision" "Teams are for hackathon only (the user's decision C)"
says "the refusal offers the unnamed background helper" "run_in_background: true"
route hackathon
allows "a named Agent is allowed under hackathon" "$(agent_payload "" "Do it." sonnet "d" '{"name":"alice","team_name":"t"}')"
allows "an unnamed background Agent is allowed under hackathon" "$(agent_payload "" "Do it." sonnet "d" '{"run_in_background":true}')"
confirm "$GOAL" hackathon
allows "a named Agent is allowed under a confirmed hackathon goal" "$(agent_payload "" "Do it." sonnet "d" '{"name":"alice"}')"
confirm "$GOAL" interns
blocks "a named Agent is refused under a confirmed interns goal" "$(agent_payload "" "Do it." sonnet "d" '{"name":"alice"}')"

echo "-- the dispatch line"
confirm "$GOAL"
guard "$(agent_payload "" "Do it." sonnet "wire up the form")"
[ "$GUARD_RC" -eq 0 ] && ok "allowed" || bad "allowed"
[ "$(jq -r '.systemMessage' <<<"$GUARD_OUT")" = "📚 Playbook dispatch: wire up the form · sonnet" ] && ok "Agent line shows description and model" || bad "Agent line"
[ "$(jq -r '.hookSpecificOutput.permissionDecision // "unset"' <<<"$GUARD_OUT")" = "unset" ] && ok "no permissionDecision is set when allowing" || bad "permissionDecision"
SCR='const meta = {name: "ship-it", description: "x"};
await agent("a", {model:"sonnet"})'
guard "$(wf_script "$SCR")"
[ "$(jq -r '.systemMessage' <<<"$GUARD_OUT")" = "📚 Playbook dispatch: ship-it · models per agent" ] && ok "Workflow line shows meta name and models per agent" || bad "Workflow line"
guard "$(jq -cn --arg sid "$SID" '{session_id:$sid,tool_name:"Workflow",tool_input:{name:"zzz-missing"}}')"
[ "$(jq -r '.systemMessage' <<<"$GUARD_OUT")" = "📚 Playbook dispatch: zzz-missing · models per agent" ] && ok "a named Workflow line shows its name" || bad "named Workflow line"
guard "$(agent_payload "" "Do it." "" "")"
says "blocks go to stderr with exit 2" "Playbook dispatch guard"

echo "-- counting"
confirm "$GOAL"
for i in 1 2 3 4 5 6 7 8; do guard "$(agent_payload "" "Do it." sonnet "task $i")"; done
[ "$(playbook_state_int "$LIVE" disp_np 0)" -eq 8 ] && ok "main-thread Agent calls are counted" || bad "dispatch count"
[ "$(playbook_score10 "$LIVE")" -gt 0 ] && ok "the eighth dispatch adds to the score" || bad "dispatch_burst"
confirm "$GOAL"
guard "$(jq -c '. + {agent_id:"helper1"}' <<<"$(agent_payload "" "Do it." sonnet "d")")"
[ "$(playbook_state_int "$LIVE" disp_np 0)" -eq 0 ] && ok "a helper's dispatch is not counted" || bad "helper count"
guard "$(agent_payload "" "x" "" "d")"
[ "$(playbook_state_int "$LIVE" disp_np 0)" -eq 0 ] && ok "a blocked call is not counted" || bad "blocked count"
confirm "$GOAL"
guard "$(jq -c '. + {agent_id:"helper1"}' <<<"$(agent_payload "" "Do it.
playbook-northstar: not the goal" sonnet "d")")"
[ "$GUARD_RC" -eq 2 ] && ok "a helper is checked against the main North Star" || bad "helper ns check"

echo "-- the third review round"
rev() { agent_payload "" "Review it." opus "${1:-review the auth module}"; }
revwf() { jq -cn --arg n "$1" --arg sid "$SID" '{session_id:$sid,tool_name:"Workflow",tool_input:{name:$n,script:"await agent(\"a\", {model:\"opus\"})"}}'; }
for label in confirmed route; do
  if [ "$label" = confirmed ]; then confirm "$GOAL"; else route lone-wolf; fi
  allows "[$label] review round 1 passes" "$(rev "review the auth module round 1")"
  allows "[$label] review round 2 passes (suffix stripped)" "$(rev "review the auth module round 2")"
  blocks "[$label] review round 3 is held" "$(rev "review the auth module round 3")"
  says "[$label] the hold carries review line 4" "Only a bug earns another round."
  says "[$label] the hold says when it lifts" "This round is held until the user answers or a judge (an Agent whose description starts \`judge:\`) returns."
  [ -n "$(playbook_state_get "$LIVE" review_hold)" ] && ok "[$label] review_hold is recorded" || bad "[$label] review_hold"
  [ "$(playbook_state_get "$LIVE" review_hold)" = "$(playbook_review_scope "$LIVE")"$'\t'"review auth module"$'\t'"3" ] && ok "[$label] the hold names scope, base and round" || bad "[$label] hold format"
  blocks "[$label] retrying the held round stays held" "$(rev "review the auth module round 3")"
  [ "$(playbook_review_rounds "$LIVE" "$(playbook_review_scope "$LIVE")" "review auth module")" -eq 2 ] && ok "[$label] a held round is not counted" || bad "[$label] held round counted"
  playbook_route_set "$LIVE" lone-wolf "again"
  blocks "[$label] re-declaring the route does not reset the count" "$(rev "review the auth module round 3")"
  printf '%s\n' "$(playbook_state_get "$LIVE" review_hold)" >> "$LIVE/review_cleared"
  allows "[$label] a clearance lets round 3 through" "$(rev "review the auth module round 3")"
  [ "$(playbook_score10 "$LIVE")" -ge 20 ] && ok "[$label] round 3 adds review_repeat to the score" || bad "[$label] review_repeat ($(playbook_score10 "$LIVE"))"
  blocks "[$label] round 4 needs a fresh clearance" "$(rev "review the auth module round 4")"
done
confirm "$GOAL"
playbook_review_bump "$LIVE" "$(playbook_review_scope "$LIVE")" "audit" >/dev/null
playbook_review_bump "$LIVE" "$(playbook_review_scope "$LIVE")" "audit" >/dev/null
allows "a judge is never held at round 3" "$(rev "judge: audit round 3")"
allows "an uppercase JUDGE: is a judge too" "$(rev "JUDGE: audit round 4")"
guard "$(jq -c '. + {tool_input: (.tool_input + {subagent_type:"codex:codex-rescue"})}' <<<"$(rev "audit round 5")")"
[ "$GUARD_RC" -eq 0 ] && ok "codex:codex-rescue is never held" || bad "codex judge"
[ "$(playbook_review_rounds "$LIVE" "$(playbook_review_scope "$LIVE")" "audit")" -eq 2 ] && ok "judges are never counted" || bad "judge counted"
allows "a non-review description is never counted" "$(rev "build the form 3")"
confirm "$GOAL"
for r in 1 2; do guard "$(revwf "security-review-r$r")"; done
blocks "a Workflow review series is held at round 3 by its name" "$(revwf "security-review-r3")"
confirm "$GOAL"
printf '%s\t%s\t%s\n' "$(playbook_review_scope "$LIVE")" "review auth module" "3" > "$LIVE/review_cleared"
for r in 1 2; do guard "$(rev "review the auth module round $r")"; done
allows "a clearance recorded before the hold lets round 3 through" "$(rev "review the auth module round 3")"
confirm "$GOAL"
for r in 1 2; do guard "$(rev "review the auth module round $r")"; done
guard "$(rev "review the auth module round 3")"
playbook_human_message "$LIVE" "carry on, fix the bug" 1000200 || true
allows "the user's next message clears the hold" "$(rev "review the auth module round 3")"
confirm "$GOAL"
for r in 1 2; do guard "$(rev "review the auth module round $r")"; done
guard "$(rev "review the auth module round 3")"
playbook_judge_returned "$LIVE"
allows "a judge's return clears the hold" "$(rev "review the auth module round 3")"
confirm "$GOAL"
for r in 1 2; do guard "$(rev "review the auth module round $r")"; done
allows "an exempt type skips the review count" "$(jq -c '. + {tool_input: (.tool_input + {subagent_type:"Explore"})}' <<<"$(rev "review round 3")")"

echo "-- hackathon message tags"
tagmsg() { jq -cn --arg m "$1" --arg t "${2:-client}" --arg a "${3:-}" --arg sid "$SID" '{session_id:$sid, tool_name:"SendMessage", tool_input:{to:$t, message:$m}} + (if $a != "" then {agent_id:$a} else {} end)'; }
playbook_route_set "$LIVE" hackathon "realtime crew"
mkdir -p "$LIVE/team/server" "$LIVE/team/client"
allows "an untagged message passes" "$(tagmsg "the ws handler is in server.js")"
for t in SOON ASAP URGENT; do allows "a single $t passes" "$(tagmsg "$t: the port is 8081")"; done
blocks "two tags are refused" "$(tagmsg "URGENT: REGROUP: the schema moved")"
says "with each tag's meaning kept apart" "Use one tag per message: SOON, ASAP, URGENT, REGROUP or RESUME. Each means something different."
blocks "two tags without a colon between them too" "$(tagmsg "URGENT REGROUP: the schema moved")"
blocks "or joined with a slash" "$(tagmsg "ASAP/URGENT: look")"
allows "a tag word later in the message is fine" "$(tagmsg "SOON: once the regroup is over, RESUME the seed work")"
blocks "REGROUP with no regroup open is refused" "$(tagmsg "REGROUP: let's realign" "*" aserver-1a2b)"
says "and says how to call one" "REGROUP is only for calling a regroup: publish your change with \`playbook publish <what changed>\` first, then send it."
playbook_state_put "$LIVE" "rg_open=1" "rg_by=server"
allows "the regroup's caller may send REGROUP" "$(tagmsg "REGROUP: the cursor event gains a colour" "*" aserver-1a2b)"
blocks "anyone else may not" "$(tagmsg "REGROUP: me too" "*" aclient-3c4d)"
blocks "the lead neither, when it did not call it" "$(tagmsg "REGROUP: me too" "*")"
blocks "RESUME while the regroup is open is refused" "$(tagmsg "RESUME: interface v3" "*" aserver-1a2b)"
says "and says when it goes out" "The regroup is still open; RESUME goes out once everyone has aligned."
allows "an URGENT during a regroup passes" "$(tagmsg "URGENT: the bot writes to prod" client aserver-1a2b)"
playbook_state_put "$LIVE" "rg_open=" "rg_by="
allows "RESUME once it has closed passes" "$(tagmsg "RESUME: interface v3 aligned" "*" aserver-1a2b)"
blocks "URGENT to everyone is refused" "$(tagmsg "URGENT: stop" "*")"
says "and names REGROUP for stopping everyone" "URGENT is for one colleague. To stop everyone, publish a change to the interface with \`playbook publish <what changed>\` and send REGROUP."
playbook_route_set "$LIVE" interns "three lanes"
allows "outside a hackathon tags are not checked" "$(tagmsg "URGENT: REGROUP: x" "*")"

echo "-- it stays out of the way"
allows "tool_name Bash is ignored" "$(jq -cn '{tool_name:"Bash", tool_input:{command:"ls"}}')"
guard ''
[ "$GUARD_RC" -eq 0 ] && silent "empty stdin is survivable and silent" || bad "empty stdin"
guard '{}'
[ "$GUARD_RC" -eq 0 ] && silent "an empty payload is survivable and silent" || bad "empty payload"

exit $fail
