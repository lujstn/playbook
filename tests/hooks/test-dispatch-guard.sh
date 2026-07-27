#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
H="$root/hooks/dispatch-guard"
export CLAUDE_PLUGIN_ROOT="$root"

fail=0
GUARD_OUT=""
GUARD_RC=0

guard() { GUARD_OUT="$(printf '%s' "$1" | bash "$H" 2>&1)" && GUARD_RC=0 || GUARD_RC=$?; }
guard_off() { GUARD_OUT="$(printf '%s' "$1" | PLAYBOOK_DISPATCH_GUARD=off bash "$H" 2>&1)" && GUARD_RC=0 || GUARD_RC=$?; }

agent_payload() { # subagent_type (may be empty), prompt
  jq -cn --arg st "$1" --arg p "$2" \
    '{tool_name:"Agent", tool_input:({prompt:$p} + (if $st == "" then {} else {subagent_type:$st} end))}'
}

workflow_payload_script() { jq -cn --arg s "$1" '{tool_name:"Workflow", tool_input:{script:$s}}'; }

blocks() { # label, payload
  guard "$2"
  if [ "$GUARD_RC" -eq 2 ]; then echo "PASS: $1"; else echo "FAIL: $1 (rc=$GUARD_RC) [$GUARD_OUT]"; fail=1; fi
}
allows() { # label, payload
  guard "$2"
  if [ "$GUARD_RC" -eq 0 ] && [ -z "$GUARD_OUT" ]; then
    echo "PASS: $1"
  else
    echo "FAIL: $1 (rc=$GUARD_RC) [$GUARD_OUT]"; fail=1
  fi
}

echo "-- Agent dispatch requires a North Star line"
blocks "prompt without a northstar line is blocked" "$(agent_payload "" "Please build the login page.")"
guard "$(agent_payload "" "Please build the login page.")"
grep -qF "playbook-northstar" <<<"$GUARD_OUT" \
  && echo "PASS: the block message mentions playbook-northstar" \
  || { echo "FAIL: block message missing playbook-northstar [$GUARD_OUT]"; fail=1; }
grep -qF "none (task-only)" <<<"$GUARD_OUT" \
  && echo "PASS: the block message teaches the task-only opt-out" \
  || { echo "FAIL: block message missing the none opt-out [$GUARD_OUT]"; fail=1; }
allows "a deliberate task-only dispatch passes" "$(agent_payload "" "Do the tiny chore.
playbook-northstar: none (task-only)")"
allows "prompt with a northstar line is allowed" "$(agent_payload "" "Do the thing.
playbook-northstar: ship a working login page end to end")"

big_filler="$(head -c 200000 /dev/zero | tr '\0' 'a')"
allows "a large prompt with the northstar line near the top is allowed" \
  "$(agent_payload "" "$(printf 'playbook-northstar: ship the whole feature\n%s\n' "$big_filler")")"
allows "a large Workflow script with the northstar string is allowed" \
  "$(workflow_payload_script "$(printf '# playbook-northstar: ship it\nsteps:\n%s\n' "$big_filler")")"

echo "-- the skip list is exempt without needing a northstar line"
allows "subagent_type Explore is exempt" "$(agent_payload "Explore" "find the file")"
allows "subagent_type Plan is exempt" "$(agent_payload "Plan" "design the approach")"
allows "subagent_type claude-code-guide is exempt" "$(agent_payload "claude-code-guide" "explain a hook")"
allows "subagent_type statusline-setup is exempt" "$(agent_payload "statusline-setup" "configure the status line")"
allows "subagent_type gsd-executor matches the gsd-* prefix" "$(agent_payload "gsd-executor" "run the plan")"

echo "-- the kill switch disables the guard entirely"
guard_off "$(agent_payload "" "no northstar here")"
[ "$GUARD_RC" -eq 0 ] && [ -z "$GUARD_OUT" ] \
  && echo "PASS: PLAYBOOK_DISPATCH_GUARD=off disables the guard" \
  || { echo "FAIL: kill switch did not disable the guard (rc=$GUARD_RC) [$GUARD_OUT]"; fail=1; }

echo "-- Workflow launches require the North Star string in script or args"
allows "Workflow script containing playbook-northstar is allowed" \
  "$(workflow_payload_script 'steps:
  - run: echo hi
# playbook-northstar: ship the whole feature')"
blocks "Workflow script lacking it is blocked" \
  "$(workflow_payload_script 'steps:
  - run: echo hi')"
allows "a Workflow with only a name field fails open (content not visible)" \
  "$(jq -cn '{tool_name:"Workflow", tool_input:{name:"x"}}')"
allows "a Workflow with only a scriptPath fails open (content not visible)" \
  "$(jq -cn '{tool_name:"Workflow", tool_input:{scriptPath:"/tmp/w.js"}}')"
allows "playbook-northstar found only in args is allowed" \
  "$(jq -cn '{tool_name:"Workflow", tool_input:{script:"echo hi", args:{note:"playbook-northstar: ship it"}}}')"

echo "-- it stays out of the way"
allows "tool_name Bash is ignored" "$(jq -cn '{tool_name:"Bash", tool_input:{command:"ls"}}')"
guard ''
[ "$GUARD_RC" -eq 0 ] && [ -z "$GUARD_OUT" ] \
  && echo "PASS: empty stdin is survivable and silent" \
  || { echo "FAIL: empty stdin errored (rc=$GUARD_RC) [$GUARD_OUT]"; fail=1; }
guard '{}'
[ "$GUARD_RC" -eq 0 ] && [ -z "$GUARD_OUT" ] \
  && echo "PASS: an empty payload is survivable and silent" \
  || { echo "FAIL: empty payload errored (rc=$GUARD_RC) [$GUARD_OUT]"; fail=1; }

exit $fail
