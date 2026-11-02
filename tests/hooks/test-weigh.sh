#!/usr/bin/env bash
set -uo pipefail
source "$(cd "$(dirname "$0")" && pwd)/payloads.sh"
DG="$root/hooks/dispatch-guard"
export PLAYBOOK_OPTIN_CHECK=off
dg() { OUT="$(printf '%s' "$1" | bash "$DG" 2>&1)"; RC=$?; }
agent() {
  jq -cn --arg s "$1" --arg d "$2" '{hook_event_name:"PreToolUse",session_id:$s,tool_name:"Agent",tool_input:{description:$d,prompt:"do the task",model:"sonnet",subagent_type:"general-purpose"}}'
}
# launched <session> <description> <agent id>: a background Agent call returning at once, as Claude Code reports it
launched() {
  post "$1" PostToolUse Agent "$(jq -cn --arg d "$2" '{description:$d,prompt:"p",model:"opus",run_in_background:true}')" \
    "$(jq -cn --arg d "$2" --arg i "$3" '{isAsync:true,status:"async_launched",agentId:$i,description:$d}')"
}
# handback <session> <agent id>: the report arriving as its own turn
handback() {
  say "$1" "Another Claude session sent a message:
<agent-message from=\"$2\">
[Subagent hand-back] The text below is the final report of a subagent this session delegated to.
  Bad news first: I found 5 bugs.
</agent-message>"
}
# notice <session> <task id> <summary> [status]
notice() {
  say "$1" "<task-notification>
<task-id>$2</task-id>
<tool-use-id>toolu_x</tool-use-id>
<status>${4:-completed}</status>
<summary>$3</summary>
</task-notification>"
}
substop() { sig "$(jq -cn --arg s "$1" --arg a "$2" '{hook_event_name:"SubagentStop",session_id:$s,agent_id:$a,agent_type:"general-purpose",last_assistant_message:"done"}')"; }
shell() { chan "$1" "$2"; }
routed() { iso; d="$(sd "$1")"; say "$1" "build the export"; chan "$1" "playbook route lone-wolf one change"; }
PAUSE="a review just came back. Take a beat before you act"

echo "-- a background review's report arriving as a turn"
routed b1
launched b1 "Second bugs-only review of the fixes" ada20b9fff13ab4c6
eq "the launch alone arms nothing" "" "$(st "$d" weigh)"
pre_edit b1 "$SANDBOX/a.js"; eq "so edits still run while it works" "" "$(decision_of)"
handback b1 ada20b9fff13ab4c6
OUT="$(ctx_of)"; has "the report comes with the pause" "$PAUSE"
has "which says findings are expected" "A review almost never comes back empty"
has "and that a bug is not always one to fix" "a bug found is not always a bug to fix"
has "and asks after the spirit of the request" "am I delivering the spirit of the user's request"
has "and keeps nice-to-haves for after delivery" "A minor unrelated bug fix or a nice-to-have change waits until the work has been delivered, then goes to the user as a possible extension."
eq "and arms the hold" "pending" "$(st "$d" weigh)"
pre_edit b1 "$SANDBOX/a.js"; eq "an edit is held" "deny" "$(decision_of)"
OUT="$(reason_of)"; has "with the pause as its reason" "$PAUSE"
shell b1 "sed -i '' 's/a/b/' $SANDBOX/a.js"; eq "so is a shell write" "deny" "$(decision_of)"
shell b1 "cat $SANDBOX/a.js | head -5"; eq "a read is not" "" "$(decision_of)"
shell b1 "npm test"; eq "nor are tests" "" "$(decision_of)"
dg "$(agent b1 "build lane one")"; eq "a dispatch is held" "2" "$RC"
dg "$(agent b1 "judge: is the fix proportionate")"; eq "a judge is not" "0" "$RC"
say b1 "thanks"
eq "a passing message from the user does not end the pause" "pending" "$(st "$d" weigh)"
notice b1 ada20b9fff13ab4c6 'Agent "Second bugs-only review of the fixes" finished'
OUT="$(ctx_of)"; hasnt "its later notice does not repeat the pause" "$PAUSE"
chan b1 'playbook weigh fix "fixing the two one-liners, listing the rest for the user, no further round"'
eq "recording the call is approved" "allow" "$(decision_of)"
eq "and ends the pause" "" "$(st "$d" weigh)"
pre_edit b1 "$SANDBOX/a.js"; eq "so edits run again" "" "$(decision_of)"
handback b1 ada20b9fff13ab4c6
eq "the same review never arms twice" "" "$(st "$d" weigh)"

echo "-- a review landing mid-turn"
routed b2
launched b2 "audit the notify script" a1111
substop b2 a1111
eq "SubagentStop arms the hold" "pending" "$(st "$d" weigh)"
pre_edit b2 "$SANDBOX/a.js"; OUT="$(reason_of)"; has "and the refusal carries the pause" "$PAUSE"
handback b2 a1111
OUT="$(ctx_of)"; hasnt "a pause already shown by a refusal is not repeated" "$PAUSE"
substop b2 a2222
chan b2 'playbook weigh fix "nothing here matters for the goal"'
substop b2 a2222
eq "a helper that is not a review arms nothing" "" "$(st "$d" weigh)"

echo "-- as Claude Code really delivers it: a reminder first, then the hand-back, in one prompt"
routed b7
launched b7 "Review slugify.js for bugs" a3d22f8f5bbbcff1e
say b7 "<system-reminder>
<tools-used-before-summary>Read</tools-used-before-summary>
</system-reminder>
Another Claude session sent a message:
<agent-message from=\"a3d22f8f5bbbcff1e\">
[Subagent hand-back] The text below is the final report of a subagent this session delegated to.
  2 bugs found.
</agent-message>"
OUT="$(ctx_of)"; has "the pause arrives with the report" "$PAUSE"
eq "and the hold is armed" "pending" "$(st "$d" weigh)"

echo "-- a report Playbook cannot read, after SubagentStop has armed the hold"
routed b8
launched b8 "review the parser" a8a8
substop b8 a8a8
post b8 PostToolUse Read '{"file_path":"/x/a.js"}' '{"file":{"content":"x"}}'
OUT="$(ctx_of)"; has "the next step's result brings the pause, before any edit is tried" "$PAUSE"
post b8 PostToolUse Read '{"file_path":"/x/a.js"}' '{"file":{"content":"x"}}'
OUT="$(ctx_of)"; hasnt "once only" "$PAUSE"
routed b9
launched b9 "review the parser" a9a9
substop b9 a9a9
say b9 "a report in some future format"
OUT="$(ctx_of)"; has "or the next prompt does" "$PAUSE"

echo "-- which reports count"
routed b3
launched b3 "apply the review fixes" a3333
handback b3 a3333
eq "a builder applying review fixes is not a review" "" "$(st "$d" weigh)"
launched b3 "find the callers of notify" a4444
handback b3 a4444
eq "a lookup is not a review" "" "$(st "$d" weigh)"
post b3 PostToolUse Workflow '{"script":"export const meta={}"}' '{"status":"async_launched","taskId":"wfo6ystpl","taskType":"local_workflow","workflowName":"phase7-adversarial-review","summary":"Adversarial review of the diff"}'
notice b3 wfo6ystpl 'Dynamic workflow "Adversarial review of the diff" completed'
OUT="$(ctx_of)"; has "a review workflow completing brings the pause" "$PAUSE"
chan b3 'playbook weigh fix "listing all three for the user"'
notice b3 wfzz 'Dynamic workflow "verify the release notes" completed' failed
eq "a review that failed brings nothing to weigh" "" "$(st "$d" weigh)"
post b3 PostToolUse Agent '{"description":"review the diff","prompt":"p","model":"opus"}' '{"content":[{"type":"text","text":"3 findings"}]}'
OUT="$(ctx_of)"; has "a foreground review returning brings the pause" "$PAUSE"
eq "and arms the hold" "pending" "$(st "$d" weigh)"
pre_edit b3 "$SANDBOX/a.js" ahelper-1; eq "a helper's own edits are never held" "" "$(decision_of)"

echo "-- bigger than a fix"
routed b4
launched b4 "review the storage move" a5555
handback b4 a5555
chan b4 'playbook weigh bigger "the read approval needs replacing, not patching"'
eq "a bigger call is approved" "allow" "$(decision_of)"
eq "and keeps the hold for sign-off" "bigger" "$(st "$d" weigh)"
pre_edit b4 "$SANDBOX/a.js"; OUT="$(reason_of)"; has "the refusal asks for sign-off" "signed off by a judge or the user"
chan b4 'playbook weigh fix "only the one-liners after all"'
eq "a bigger call cannot be talked down to a fix" "deny" "$(decision_of)"
say b4 "thanks, carry on"
eq "a passing message is not sign-off" "bigger" "$(st "$d" weigh)"
chan b4 'playbook decision "thanks, carry on"'
eq "a typed sign-off recorded in the user's own words is" "" "$(st "$d" weigh)"
handback b4 a5555; launched b4 "review round two" a6666; handback b4 a6666
chan b4 'playbook weigh bigger "needs a new approach"'
post b4 PostToolUse Agent '{"description":"judge: sign off the new approach","prompt":"p","model":"opus"}' '{}'
eq "a judge returning signs it off" "" "$(st "$d" weigh)"
launched b4 "review round three" a7777; handback b4 a7777
chan b4 'playbook weigh bigger "needs more scope"'
post b4 PostToolUse AskUserQuestion '{"questions":[{"question":"Sign off the new approach?","options":[{"label":"Yes (Recommended)"},{"label":"No"}]}]}' '{"answers":{"Sign off the new approach?":"Yes (Recommended)"}}'
eq "the user's answer in a picker signs it off" "" "$(st "$d" weigh)"

echo "-- offline"
routed b5
playbook_offline_set "$d" 0 b 1
launched b5 "review the export" a8888; handback b5 a8888
chan b5 'playbook weigh fix "fixing the crash, the slow sort is a possible extension"'
OUT="$(cat "$d/offline-log.jsonl" 2>/dev/null)"; has "the call goes into the morning log" "fixing the crash, the slow sort is a possible extension"

echo "-- the channel"
routed b6
chan b6 'playbook weigh fix "no review is waiting"'
eq "a call with no review waiting is still recorded" "allow" "$(decision_of)"
chan b6 'playbook weigh'
eq "a call needs fix or bigger" "deny" "$(decision_of)"
chan b6 'playbook weigh soon "x"'
eq "and nothing else" "deny" "$(decision_of)"
chan b6 'playbook weigh fix "x"' ahelper-2
eq "a helper is not held, so it records no call" "deny" "$(decision_of)"
launched b6 "review the export" a9999; handback b6 a9999
OUT="$(printf '%s' '{"hook_event_name":"SessionStart","source":"clear","session_id":"b6"}' | bash "$TB" 2>/dev/null)"
eq "/clear ends a pause from the old conversation" "" "$(st "$d" weigh)"

exit "$fail"
