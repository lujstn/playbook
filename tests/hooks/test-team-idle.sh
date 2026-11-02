#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
H="$root/hooks/team-idle"
export CLAUDE_PLUGIN_ROOT="$root"
export PLAYBOOK_STATE_DIR="$(mktemp -d)"
export PLAYBOOK_NOW=1000000
unset CLAUDE_PID
export HOME="$(mktemp -d)"
SID=s1
TEAM=session-s1abcd
. "$root/hooks/lib/playbook-common.sh"
LIVE="$PLAYBOOK_STATE_DIR/$SID"
mkdir -p "$LIVE"

fail=0
OUT="" RC=0
ok() { echo "PASS: $1"; }
bad() { echo "FAIL: $1 [rc=$RC] [$OUT]"; fail=1; }
idle_payload() { # teammate, [extra jq object]
  jq -cn --arg n "$1" --arg t "$TEAM" --arg sid "$SID" --argjson x "${2:-$EMPTY}" \
    '{session_id:$sid, hook_event_name:"TeammateIdle", teammate_name:$n, team_name:$t} + $x'
}
EMPTY="{}"
idle() { OUT="$(idle_payload "$@" | bash "$H" 2>&1)" && RC=0 || RC=$?; }
pushed() { [ "$RC" -eq 2 ] && ok "$1" || bad "$1"; }
quiet() { [ "$RC" -eq 0 ] && [ -z "$OUT" ] && ok "$1" || bad "$1"; }
stopped() { [ "$RC" -eq 0 ] && [ "$(jq -r '.continue' <<<"$OUT" 2>/dev/null)" = "false" ] && [ -n "$(jq -r '.stopReason // empty' <<<"$OUT" 2>/dev/null)" ] && ok "$1" || bad "$1"; }
declare_() { playbook_team_declare "$(idle_payload "$1")" "$1" "$2" "${3:-}"; }
task() { # id owner status subject
  mkdir -p "$HOME/.claude/tasks/$TEAM"
  jq -cn --arg i "$1" --arg o "$2" --arg s "$3" --arg j "$4" '{id:$i, owner:$o, status:$s, subject:$j}' > "$HOME/.claude/tasks/$TEAM/$1.json"
}
fresh() { rm -rf "${PLAYBOOK_STATE_DIR:?}/${SID:?}" "${HOME:?}/.claude/tasks"; mkdir -p "$LIVE"; }

echo "-- A: part-done shuts a teammate down"
fresh
declare_ alice part-done
idle alice
stopped "a teammate that declared part-done is stopped"
grep -qF "Playbook stopped this teammate's work; the lead shuts it down once its part is integrated." <<<"$OUT" && ok "the stop reason says what happened" || bad "stop reason"
idle bob
pushed "an undeclared teammate is never stopped (it is pushed instead)"
declare_ carol part-done
idle bob
[ "$RC" -eq 2 ] && ok "another teammate's part-done does not stop this one" || bad "another teammate's part-done"
playbook_state_put "$LIVE" "ns_goal=g" "ns_state=confirmed"
playbook_ns_mark "$LIVE" done "x"
[ "$(playbook_ns_state "$LIVE")" = "done" ] && ok "(setup) the lead's North Star is done" || bad "setup ns done"
idle bob
[ "$RC" -eq 2 ] && ok "the lead's done does not stop any teammate" || bad "lead done stops a teammate"
idle alice
stopped "the lead's done does not unstop a part-done teammate either"

echo "-- B: open items push the teammate back to work"
fresh
idle dave
pushed "no task list and no declaration: pushed"
grep -qF 'run `playbook waiting <your name> on <colleague> <what>`' <<<"$OUT" && ok "the feedback teaches the waiting command" || bad "feedback waiting"
grep -qF 'run `playbook part-done <your name>`' <<<"$OUT" && ok "the feedback teaches the part-done command" || bad "feedback part-done"
grep -qF "Playbook: your part still has open items." <<<"$OUT" && ok "without a task list the feedback names no tasks" || bad "feedback shape"
idle dave; pushed "second push"
idle dave; pushed "third push"
idle dave
quiet "there is no fourth push in a row"
declare_ dave waiting erin "the schema"
declare_ dave "" ""
idle dave
pushed "a declaration resets the push count"
idle dave; idle dave
idle dave
quiet "the cap applies again after the reset"
playbook_team_message "$(idle_payload dave)" dave
idle dave
pushed "a message to the teammate resets the push count"

fresh
task 1 frank in_progress "wire the form"
task 2 frank pending "add tests"
task 3 frank completed "scaffold"
task 4 gina in_progress "other part"
idle frank
pushed "a teammate with open tasks is pushed"
grep -qF "open items: 2 tasks, " <<<"$OUT" && grep -qF "wire the form" <<<"$OUT" && grep -qF "add tests" <<<"$OUT" && ok "the feedback names the open tasks" || bad "feedback tasks"
grep -qF "scaffold" <<<"$OUT" && bad "completed task named" || ok "completed tasks are not named"
grep -qF "other part" <<<"$OUT" && bad "other owner's task named" || ok "another teammate's tasks are not named"
task 1 frank completed "wire the form"
task 2 frank completed "add tests"
idle frank
quiet "a teammate whose own tasks are all done idles"
idle henry
quiet "a teammate with no tasks in a list that exists idles"
task 5 "frank@$TEAM" pending "late task"
idle frank
pushed "an owner written name@team still counts"
echo "{ not json" > "$HOME/.claude/tasks/$TEAM/9.json"
idle frank
pushed "an unreadable task list degrades to the no-list rule"
rm -rf "$HOME/.claude/tasks"
playbook_team_message "$(idle_payload frank)" frank
idle frank
pushed "a missing task list degrades to the no-list rule"

echo "-- B: waiting lets a teammate idle until messaged"
fresh
declare_ iris waiting jules "the interface change"
idle iris
quiet "a waiting teammate idles silently"
idle iris
quiet "and keeps idling"
playbook_team_message "$(idle_payload iris)" iris
idle iris
pushed "a message clears waiting, so the next idle pushes again"
task 1 kate pending "open"
declare_ kate waiting jules "x"
idle kate
quiet "waiting beats open tasks"

echo "-- B: a failed idle passes through"
fresh
idle leo '{"idleReason":"failed"}'
quiet "an idle marked failed is never pushed"
declare_ mia part-done
idle mia '{"idleReason":"failed"}'
quiet "a failed idle is never stopped either"
idle leo '{"idleReason":"available"}'
pushed "an available idle is acted on"

echo "-- it stays out of the way"
OUT="$(printf '' | bash "$H" 2>&1)" && RC=0 || RC=$?; quiet "empty stdin is silent"
OUT="$(printf '{}' | bash "$H" 2>&1)" && RC=0 || RC=$?; quiet "a payload with no teammate is silent"
OUT="$(printf 'not json' | bash "$H" 2>&1)" && RC=0 || RC=$?; quiet "garbage is silent"
[ -x "$H" ] && ok "the hook is executable" || { echo "FAIL: not executable"; fail=1; }

echo "-- during a regroup nobody is sent back to work"
playbook_state_put "$LIVE" "rg_open=1"
idle regrouper; quiet "a teammate with no declaration idles while every edit is held"
playbook_state_put "$LIVE" "rg_open="
idle regrouper; pushed "once the regroup closes it is pushed again"

exit $fail
