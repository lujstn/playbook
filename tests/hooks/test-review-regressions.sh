#!/usr/bin/env bash
set -uo pipefail
source "$(cd "$(dirname "$0")" && pwd)/payloads.sh"
DG="$root/hooks/dispatch-guard"
TI="$root/hooks/team-idle"
dg() { OUT="$(printf '%s' "$1" | bash "$DG" 2>&1)"; RC=$?; }
agent() {
  jq -cn --arg s "$1" --arg d "$2" --arg p "${3:-do the task}" --arg n "${4:-}" \
    '{hook_event_name:"PreToolUse",session_id:$s,tool_name:"Agent",tool_input:({description:$d,prompt:$p,model:"sonnet",subagent_type:"general-purpose"} + (if $n != "" then {name:$n} else {} end))}'
}
ask_post() {
  post "$1" PostToolUse AskUserQuestion "$(jq -cn --arg q "$2" --arg a "$3" '{questions:[{question:$q}],answers:{($q):$a}}')" '{}'
}

iso
d="$(sd a1)"
say a1 "please build the export"
chan a1 'playbook unease alarmed testing the ask gate'
eq "alarmed sets the ask gate" "ask" "$(st "$d" gate)"
ask_post a1 "The score is alarmed; carry on?" "Yes, carry on"
eq "an AskUserQuestion answer lifts the ask gate" "" "$(st "$d" gate)"
pre_edit a1 /tmp/x.txt
eq "and the next edit is allowed" "" "$(decision_of)"

iso
d="$(sd a2)"
say a2 "review the parser"
chan a2 'playbook route lone-wolf parser review'
for r in 1 2; do dg "$(agent a2 "review the parser round $r")"; done
dg "$(agent a2 "review the parser round 3")"
eq "the third round is held" "2" "$RC"
ask_post a2 "Two rounds still found bugs; one more?" "Yes, one more round"
dg "$(agent a2 "review the parser round 3")"
eq "an AskUserQuestion answer releases the held round" "0" "$RC"

iso
d="$(sd b1)"
say b1 "yes, carry on"
chan b1 'playbook unease alarmed testing repeats'
say b1 "yes, carry on"
eq "a repeated prompt still lifts the ask gate" "" "$(st "$d" gate)"
iso
d="$(sd b2)"
export PLAYBOOK_NOW=1000
say b2 "continue"
playbook_ns_confirm "$d" "Ship the billing export" lone-wolf picker
export PLAYBOOK_NOW=$(( 1000 + 10 * 3600 ))
say b2 "continue"
eq "a repeated prompt after a 10-hour gap still marks the goal stale" "stale" "$(st "$d" ns_state)"
unset PLAYBOOK_NOW

iso
d="$(sd c1)"
say c1 "ship the billing export"
playbook_ns_confirm "$d" "Ship the billing export" interns picker
chan c1 'playbook route interns billing export lanes'
eq "a route following the pick in the same mode carries the goal" "Ship the billing export" "$(playbook_ns_carried "$d")"
chan c1 'playbook route lone-wolf fix the README typo'
eq "a route in a different mode carries no goal" "" "$(playbook_ns_carried "$d")"
dg "$(agent c1 "readme fix" "playbook-northstar: fix the README typo
fix it")"
eq "a brief for the new single-option work is not forced back to the old goal" "0" "$RC"
OUT="$(printf '{"hook_event_name":"SubagentStart","session_id":"c1","agent_id":"h1","cwd":"/tmp"}' | bash "$SS" | jq -r '.hookSpecificOutput.additionalContext')"
hasnt "the helper block does not carry the older goal" "Ship the billing export"
has "the helper block says no goal is confirmed" "none confirmed"
eq "the older goal stays confirmed for when the work returns" "confirmed" "$(st "$d" ns_state)"

iso
d="$(sd t1)"
say t1 "build the crew"
chan t1 'playbook route hackathon crew build'
chan t1 'playbook part-done backend' agent-old
OUT="$(printf '{"hook_event_name":"TeammateIdle","session_id":"t1","teammate_name":"backend"}' | bash "$TI" 2>&1)"
has "a declared part-done shuts the teammate down" '"continue":false'
dg "$(agent t1 "backend follow-up" "pick up the follow-up" backend)"
eq "spawning a fresh teammate of the same name is allowed under hackathon" "0" "$RC"
OUT="$(printf '{"hook_event_name":"TeammateIdle","session_id":"t1","teammate_name":"backend"}' | bash "$TI" 2>&1)"; RC=$?
hasnt "the fresh teammate does not inherit the old part-done" '"continue":false'
eq "and is pushed back to work instead" "2" "$RC"

iso
d="$(sd i1)"
say i1 "build the crew"
chan i1 'playbook route hackathon crew build'
chan i1 'playbook interface /no/such/api.ts'
eq "an old-style path only names the interface, which Playbook keeps outside the project" "$d/interface/api.md" "$(st "$d" iface_path)"
[ ! -e /no/such/api.ts ] && pass "and nothing is written at that path" || flunk "the declaration wrote into the given path"
f="$d/interface/api.md"; printf 'GET /v1\n' > "$f"
chan i1 "playbook interface $f"
eq "declaring an existing interface file is allowed" "allow" "$(decision_of)"
pre_edit i1 "$SANDBOX/client.md" h1
eq "outside a regroup, an unread interface never blocks a helper's edit" "" "$(decision_of)"
playbook_team_declare '{"session_id":"i1"}' h2 ""
printf 'GET /v2\n' > "$f"
bash_post i1 "sed -i '' s/v1/v2/ api.md" 0 ""
pre_edit i1 "$SANDBOX/client.md" h2
eq "an interface rewritten through Bash still calls a regroup" "deny" "$(decision_of)"
chan i1 'playbook route interns next lanes'
pre_edit i1 "$SANDBOX/client.md" h2
eq "a new non-hackathon route clears the regroup" "" "$(decision_of)"
chan i1 'playbook route hackathon crew again'
chan i1 "playbook interface $f"
printf 'GET /v3\n' > "$f"
bash_post i1 "sed -i '' s/v2/v3/ api.md" 0 ""
pre_edit i1 "$SANDBOX/client.md" h2
eq "a regroup opens again under the new hackathon route" "deny" "$(decision_of)"
chan i1 'playbook done'
pre_edit i1 "$SANDBOX/client.md" h2
eq "done clears the regroup" "" "$(decision_of)"

iso
d="$(sd m1)"
say m1 "ship it"
playbook_ns_confirm "$d" "Ship it" lone-wolf picker
for c in "git merge-base HEAD origin/main" 'grep -rn "git merge" docs/' "git merge --abort"; do
  bash_post m1 "$c" 0 ""
done
eq "read-only merge mentions leave the goal confirmed" "confirmed" "$(st "$d" ns_state)"
bash_post m1 "git merge --no-ff feature" 0 ""
eq "a real merge marks the goal stale" "stale" "$(st "$d" ns_state)"
playbook_ns_confirm "$d" "Ship it" lone-wolf picker
bash_post m1 "cd repo && gh pr merge 41 --squash" 0 ""
eq "gh pr merge after cd marks the goal stale" "stale" "$(st "$d" ns_state)"

eq "different numbered reviews keep their own names" "review pr 41" "$(playbook_review_base "Review PR 41")"
eq "a round suffix is still stripped" "review parser" "$(playbook_review_base "Review the parser round 3")"
eq "a workflow round suffix is still stripped" "playbook-review" "$(playbook_review_base "playbook-review-r3")"
for d in "Review same-person PR 27" "Second review of same-person PR 27" "Third review of PR 27 fixes"; do
  eq "the incident's drifting PR 27 briefs share one review identity: $d" "review pr 27" "$(playbook_review_base "$d")"
done
eq "ordinals and stopwords never split a review" "$(playbook_review_base "Review the parser round 3")" "$(playbook_review_base "Second review of the parser")"
eq "a workflow round word leaves no trailing hyphen" "phase10-review" "$(playbook_review_base "phase10-review-round2")"

iso
d="$(sd j1)"
say j1 "ship it"
playbook_ns_confirm "$d" "Ship it" lone-wolf picker
playbook_ns_mark "$d" stale "test"
dg "$(agent j1 "judge: is the plan sound")"
eq "a judge is allowed under a stale goal" "0" "$RC"
dg "$(agent j1 "build the thing")"
eq "a builder is still refused under a stale goal" "2" "$RC"

iso
chan q1 "playbook rethink the user's spec"
eq "a channel line with an apostrophe is allowed" "allow" "$(decision_of)"
eq "but the shell gets it without the apostrophe, so it cannot fail" "🔁 Playbook rethink: the users spec" "$(ran_of)" #<<<"$OUT")"

iso
d="$(sd p1)"
say p1 "ship the export"
LC_ALL=C ask_post p1 "Goal: Ship the export · Mode: which fits?" "interns (Recommended)"
eq "the picker goal parses cleanly under a C locale" "Ship the export" "$(st "$d" ns_goal)"

iso
d="$(sd k1)"
export PLAYBOOK_NOW=50000
playbook_state_put "$d" "score10=100"; playbook_score_settle "$d"
playbook_judge_returned "$d"
export PLAYBOOK_NOW=$(( 50000 + 3600 ))
playbook_state_put "$d" "score10=100"; playbook_score_settle "$d"
eq "a second concerned within 2 hours is alarmed" "ask" "$(st "$d" gate)"
playbook_gate_clear "$d" all
export PLAYBOOK_NOW=$(( 50000 + 3600 + 3300 ))
playbook_state_put "$d" "score10=100" "level=0"; playbook_score_settle "$d"
eq "a third concerned 55 minutes after an upgraded one is alarmed too" "ask" "$(st "$d" gate)"
unset PLAYBOOK_NOW

iso
s0=$(date +%s)
OUT="$(printf '{"hook_event_name":"PreToolUse","session_id":"f1","tool_name":"Bash","tool_input":{"command":"ls -la"}}' | bash "$SIG")"
silent "an ordinary Bash command passes the channel hook silently"
[ -z "$(ls -A "$SANDBOX" 2>/dev/null)" ] && pass "and touches no state" || flunk "an ordinary Bash command created state"

iso
d="$(sd fx)"
say fx "close out PR 35"
chan fx 'playbook route lone-wolf PR 35 close'
dg "$(agent fx "Review the v1.1 close PR #35")"
dg "$(agent fx "Apply PR #35 review fixes and push")"
dg "$(agent fx "Re-review PR #35 at 956dfe2")"
eq "a fixer between two reviews is not a round, so the second review passes" "0" "$RC"
dg "$(agent fx "Re-review PR #35 after the second fixes")"
eq "the third real review of PR 35 is held" "2" "$RC"
for r in 1 2 3; do dg "$(agent fx "Fix PR #41 review round $r findings")"; done
eq "fix agents named after review rounds are never held as reviews" "0" "$RC"

iso
d="$(sd tc)"
say tc "fix the parser"
bash_post tc "grep -rn vitest package.json" 1 ""
bash_post tc "grep -rn vitest package.json" 1 ""
eq "a search that names a test runner and finds nothing adds nothing" "0" "$(score_of "$d")"
bash_post tc "npm test" 1 "1 failing"
playbook_state_put "$d" "score10=40"
bash_post tc "cat jest.config.js" 0 "module.exports = {}"
eq "printing a test config is not a pass" "40" "$(score_of "$d")"
eq "and the failing state stays" "1" "$(st "$d" failed_since_pass)"
bash_post tc "cd app && npm test" 0 "ok"
eq "a real test run after cd still counts as the pass" "10" "$(score_of "$d")"

for c in "Goal: a working realtime pixel-art MVP in a new subfolder, protocol settled as the build goes. Which mode?|Goal: pixel-art MVP · Mode: hackathon team (Recommended)|pixel-art MVP|hackathon" \
         "Goal: Ship the export. Which mode fits?|🐜 interns|Ship the export|interns" \
         "Goal: Ship the export · Mode: which fits?|Lone wolf (Recommended)|Ship the export|lone-wolf"; do
  IFS='|' read -r q a g m <<<"$c"
  iso; d="$(sd pk)"; say pk "build it"
  ask_post pk "$q" "$a"
  eq "a picker answered '$a' confirms the goal" "$g" "$(st "$d" ns_goal)"
  eq "and the mode $m" "$m" "$(st "$d" ns_mode)"
done
iso; d="$(sd pk2)"; say pk2 "build it"
ask_post pk2 "Goal: Ship the export · Mode: which fits?" "Solo build"
eq "a pick that names no mode confirms nothing" "" "$(st "$d" ns_goal)"

upd() { jq -r '.hookSpecificOutput.updatedInput.command // empty' <<<"$OUT"; }
iso; d="$(sd rl)"; say rl "build the app"
chan rl 'playbook route hackathon three specialists (server, client, load-bot) share a protocol'
eq "a route line with brackets is recorded" "hackathon" "$(st "$d" route_mode)"
eq "and allowed" "allow" "$(decision_of)"
eq "with the brackets taken out of what is recorded" "three specialists server, client, load-bot share a protocol" "$(st "$d" route_reason)"
eq "and the hackathon named as a team in what is shown" "📚 Playbook session started · building with 🤝 hackathon team" "$(ran_of)"
iso; d="$(sd rl2)"; say rl2 "build the utilities"
chan rl2 'playbook route interns six utilities; mkdir -p lib/utils && echo ok'
eq "a route line with a chained command is still recorded" "interns" "$(st "$d" route_mode)"
eq "with the reason cut at the separator" "six utilities" "$(st "$d" route_reason)"
eq "but the call is not approved, so the chained command goes to Claude Code's own permission check" "" "$(decision_of)"
eq "and the shell gets the command as Claude wrote it" "" "$(upd)"
eq "the route line is still shown" "📚 Playbook session started · building with 🐜 interns" "$(shown_of)"
iso; d="$(sd rl3)"; say rl3 "build it"
chan rl3 'playbook route interns reason $(rm -rf /) `id` "quoted"'
eq "command substitution and quotes never reach the shell" "📚 Playbook session started · building with 🐜 interns" "$(ran_of)"
eq "nor what is recorded" "reason rm -rf / id quoted" "$(st "$d" route_reason)"
iso; d="$(sd rq)"; say rq "build it"
chan rq 'playbook route lone-wolf "user picked lone-wolf; small codebase, coupled pieces"'
eq "a quoted reason with a semicolon inside is one reason, not a chained command" "allow" "$(decision_of)"
eq "and is recorded whole" "user picked lone-wolf, small codebase, coupled pieces" "$(st "$d" route_reason)"
eq "and shown as the start line" "📚 Playbook session started · building with 🐺 lone-wolf" "$(ran_of)"
chan rq 'playbook route lone-wolf "one reason"; rm -rf /'
eq "a separator after the closing quote is still a chained command" "" "$(decision_of)"
say rq "I said keep the user's own words"
chan rq "playbook decision \"keep the user's own words\""
eq "an apostrophe in a decision survives the shell quoting" "📌 Playbook decision recorded: keep the user's own words" "$(ran_of)"
chan rl3 $'playbook route interns first line\nrm -rf /'
eq "a second line is a chained command too, never approved" "" "$(decision_of)"
eq "with the route cut at the line break" "first line" "$(st "$(sd rl3)" route_reason)"
chan rl3 'playbook interface api(v2).md'
eq "an interface name keeps only plain characters" "$(sd rl3)/interface/api.md" "$(st "$(sd rl3)" iface_path)"
chan rl3 'playbook route fix a typo'
eq "a word that is not a mode is still refused" "deny" "$(decision_of)"
iso; d="$(sd rl4)"; say rl4 "rename it"
sig "$(jq -cn --arg m $'playbook route lone-wolf Mechanical single-name rename; one viable mode.\nThe rename is done.' '{hook_event_name:"Stop",session_id:"rl4",last_assistant_message:$m}')"
eq "a route line printed in the final reply is recorded at the end of the turn" "lone-wolf" "$(st "$d" route_mode)"
iso; d="$(sd rl5)"; say rl5 "explain it"
sig "$(jq -cn --arg m 'Declare it with `playbook route <mode> <reason>` when only one mode fits.' '{hook_event_name:"Stop",session_id:"rl5",last_assistant_message:$m}')"
eq "a route line quoted mid-sentence is not a route" "" "$(st "$d" route_mode)"
sig "$(jq -cn --arg m 'playbook route <mode> <reason>' '{hook_event_name:"Stop",session_id:"rl5",last_assistant_message:$m}')"
eq "nor is the placeholder form" "" "$(st "$d" route_mode)"
chan rl5 'playbook route lone-wolf x' agent-h1
eq "a helper's route line is refused as before" "deny" "$(decision_of)"

exit $fail
