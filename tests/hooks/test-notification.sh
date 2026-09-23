#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
H="$root/hooks/notification"
export CLAUDE_PLUGIN_ROOT="$root"

fail=0

sandbox="$(mktemp -d)"
trap 'rm -rf "$sandbox"' EXIT

state_dir="$sandbox/state"
sess_dir="$state_dir/sess1"
mkdir -p "$sess_dir"
flag="$sess_dir/offline"
log_file="$sess_dir/offline-log.jsonl"

stub_bin="$sandbox/bin"
mkdir -p "$stub_bin"
stub="$stub_bin/notify"
stub_log="$sandbox/stub.log"
cat >"$stub" <<'STUB'
#!/usr/bin/env bash
log="${STUB_LOG:-/dev/null}"
{
  echo "ARGS:"
  for a in "$@"; do printf '  %s\n' "$a"; done
} >>"$log"
exit "${STUB_EXIT:-0}"
STUB
chmod +x "$stub"

HOOK_OUT=""
HOOK_RC=0
run_hook() { # payload, stub-exit-code (default 0)
  rm -f "$stub_log"
  HOOK_OUT="$(printf '%s' "$1" | \
    PLAYBOOK_STATE_DIR="$state_dir" PLAYBOOK_NOTIFY_BIN="$stub" STUB_LOG="$stub_log" STUB_EXIT="${2:-0}" \
    bash "$H" 2>&1)" && HOOK_RC=0 || HOOK_RC=$?
}

payload() { # notification_type, message (either may be empty)
  jq -cn --arg sid "sess1" --arg nt "$1" --arg msg "$2" \
    '{hook_event_name:"Notification", session_id:$sid}
     + (if $nt  == "" then {} else {notification_type:$nt} end)
     + (if $msg == "" then {} else {message:$msg} end)'
}

echo "-- silent when no offline flag is set"
rm -f "$flag" "$log_file"
run_hook "$(payload permission_prompt '')"
[ "$HOOK_RC" -eq 0 ] && [ -z "$HOOK_OUT" ] \
  && echo "PASS: hook exits 0 with no output when offline flag is absent" \
  || { echo "FAIL: unexpected rc/out with no flag (rc=$HOOK_RC) [$HOOK_OUT]"; fail=1; }
[ ! -f "$stub_log" ] && echo "PASS: notify stub never called with no offline flag" \
  || { echo "FAIL: notify stub was called with no offline flag"; fail=1; }
[ ! -f "$log_file" ] && echo "PASS: no decision log written with no offline flag" \
  || { echo "FAIL: decision log written with no offline flag"; fail=1; }

echo "-- forwards to notify while the flag is set"
printf 'window=10\nwait=a\nsince=1\n' > "$flag"
run_hook "$(payload permission_prompt 'user input needed')"
[ "$HOOK_RC" -eq 0 ] && [ -z "$HOOK_OUT" ] \
  && echo "PASS: hook stays silent on stdout/stderr while forwarding" \
  || { echo "FAIL: hook spoke while forwarding (rc=$HOOK_RC) [$HOOK_OUT]"; fail=1; }
grep -qx '  --level' "$stub_log" && grep -qx '  action' "$stub_log" \
  && echo "PASS: permission_prompt maps to --level action" \
  || { echo "FAIL: permission_prompt did not map to action [$(cat "$stub_log")]"; fail=1; }
grep -qx '  user input needed' "$stub_log" \
  && echo "PASS: the captured message is passed as the detail" \
  || { echo "FAIL: message not forwarded as detail [$(cat "$stub_log")]"; fail=1; }
[ -f "$log_file" ] && [ "$(wc -l < "$log_file" | tr -d ' ')" -eq 1 ] \
  && echo "PASS: exactly one decision-log line appended" \
  || { echo "FAIL: decision log line count wrong"; fail=1; }
line="$(cat "$log_file")"
jq -e '.event == "notify" and .kind == "permission_prompt" and .level == "action" and .exit == 0 and (.ts|type) == "number"' \
  >/dev/null 2>&1 <<<"$line" \
  && echo "PASS: decision-log line carries the expected fields" \
  || { echo "FAIL: decision-log line malformed [$line]"; fail=1; }

reply() { # transcript file, final assistant text
  jq -cn '{type:"user", message:{role:"user", content:"do the thing"}}' > "$1"
  jq -cn --arg t "$2" '{type:"assistant", message:{id:"m1", role:"assistant", content:[{type:"text", text:$t}]}}' >> "$1"
}
idle_with() { # transcript file
  jq -cn --arg tp "$1" '{hook_event_name:"Notification", session_id:"sess1", notification_type:"idle_prompt", message:"Claude is waiting for your input", transcript_path:$tp}'
}
held() { tail -n1 "$log_file" | jq -e --arg k "$1" '.event == "notify_held" and .kind == $k and .exit == 0' >/dev/null 2>&1; }

echo "-- idle_prompt after a finished reply is held, not pushed"
t="$sandbox/done.jsonl"
reply "$t" $'Merged and green. The PR is at https://example.com/pr?id=4 and CI passed.\n\nNext: open the PR and skim it.\n\nPlaybook runs best on ultracode.\nRun `/effort ultracode` if you are not already there.\n\n📚 *Playbook skills available in this session*'
run_hook "$(idle_with "$t")"
[ ! -f "$stub_log" ] && echo "PASS: a done reply sends no push" \
  || { echo "FAIL: a done reply pushed [$(cat "$stub_log")]"; fail=1; }
held idle_prompt && echo "PASS: the held idle is still recorded in the decision log" \
  || { echo "FAIL: held idle not logged [$(tail -n1 "$log_file")]"; fail=1; }

echo "-- idle_prompt after a reply that asks the user pushes the question itself"
reply "$t" $'Two routes fit.\n\nShould I ship the smaller one first?\n\n📚 *Playbook skills available in this session*'
run_hook "$(idle_with "$t")"
grep -qx '  action' "$stub_log" && grep -qx '  Claude asked you something' "$stub_log" \
  && echo "PASS: an asking reply pushes at action level with the asked headline" \
  || { echo "FAIL: asking reply not pushed as action [$(cat "$stub_log" 2>/dev/null)]"; fail=1; }
grep -qx '  Should I ship the smaller one first?' "$stub_log" \
  && echo "PASS: the question itself becomes the notification body" \
  || { echo "FAIL: question not used as detail [$(cat "$stub_log" 2>/dev/null)]"; fail=1; }

echo "-- a request for input without a question mark still counts"
reply "$t" $'This repo has no login button.\n\n**To continue, I need one of these:**\n- the project path, or\n- the file contents'
run_hook "$(idle_with "$t")"
grep -qx '  Claude asked you something' "$stub_log" \
  && echo "PASS: an 'I need one of these:' request pushes" \
  || { echo "FAIL: need-list request missed [$(cat "$stub_log" 2>/dev/null)]"; fail=1; }

echo "-- questions answered in place, or inside code, do not count"
reply "$t" $'Checked the logs.\n\nWas the poller running? No. Any expiries? Zero.\n\n```\nwhy?\n```\n\nAll done.'
run_hook "$(idle_with "$t")"
[ ! -f "$stub_log" ] && echo "PASS: rhetorical and code-fenced question marks are ignored" \
  || { echo "FAIL: rhetorical question pushed [$(cat "$stub_log")]"; fail=1; }

echo "-- an AskUserQuestion call counts as asking"
jq -cn '{type:"assistant", message:{id:"m2", role:"assistant", content:[{type:"tool_use", id:"t1", name:"AskUserQuestion", input:{questions:[{question:"Which database should this use?"}]}}]}}' >> "$t"
run_hook "$(idle_with "$t")"
grep -qx '  Which database should this use?' "$stub_log" \
  && echo "PASS: the AskUserQuestion question is pushed" \
  || { echo "FAIL: AskUserQuestion not pushed [$(cat "$stub_log" 2>/dev/null)]"; fail=1; }

echo "-- an unreadable transcript errs towards pushing"
run_hook "$(idle_with "$sandbox/missing.jsonl")"
grep -qx '  Claude has gone quiet and may need you' "$stub_log" \
  && echo "PASS: with no evidence either way the idle still pushes" \
  || { echo "FAIL: unreadable transcript did not push [$(cat "$stub_log" 2>/dev/null)]"; fail=1; }

echo "-- agent_completed is logged, never pushed"
run_hook "$(payload agent_completed '')"
[ ! -f "$stub_log" ] && echo "PASS: a finished background session sends no push" \
  || { echo "FAIL: agent_completed pushed [$(cat "$stub_log")]"; fail=1; }
held agent_completed && echo "PASS: agent_completed is recorded as held" \
  || { echo "FAIL: agent_completed not logged as held [$(tail -n1 "$log_file")]"; fail=1; }

echo "-- states that genuinely block on the user push at action level"
for k in elicitation_dialog elicitation_url_dialog agent_needs_input quota_auto_resume_stale quota_auto_resume_disabled; do
  run_hook "$(payload "$k" '')"
  { [ -f "$stub_log" ] && grep -qx '  action' "$stub_log"; } \
    && echo "PASS: $k pushes at action level" \
    || { echo "FAIL: $k did not push as action [$(cat "$stub_log" 2>/dev/null)]"; fail=1; }
done

echo "-- a failing notify send is still recorded, hook still exits 0"
run_hook "$(payload idle_prompt '')" 3
[ "$HOOK_RC" -eq 0 ] \
  && echo "PASS: hook exits 0 even when the notify stub fails" \
  || { echo "FAIL: hook propagated the stub failure (rc=$HOOK_RC)"; fail=1; }
tail -n1 "$log_file" | jq -e '.exit == 3' >/dev/null 2>&1 \
  && echo "PASS: the decision-log line records the failing exit code" \
  || { echo "FAIL: failing exit code not recorded [$(tail -n1 "$log_file")]"; fail=1; }

echo "-- malformed stdin degrades to silence"
run_hook 'not json'
[ "$HOOK_RC" -eq 0 ] && [ -z "$HOOK_OUT" ] \
  && echo "PASS: malformed stdin is silently survived" \
  || { echo "FAIL: malformed stdin errored (rc=$HOOK_RC) [$HOOK_OUT]"; fail=1; }

echo "-- an event other than Notification is ignored even with the flag set"
before="$(wc -l < "$log_file" | tr -d ' ')"
HOOK_OUT="$(jq -cn '{hook_event_name:"PreToolUse", session_id:"sess1"}' | \
  PLAYBOOK_STATE_DIR="$state_dir" PLAYBOOK_NOTIFY_BIN="$stub" STUB_LOG="$stub_log" \
  bash "$H" 2>&1)" && HOOK_RC=0 || HOOK_RC=$?
after="$(wc -l < "$log_file" | tr -d ' ')"
[ "$HOOK_RC" -eq 0 ] && [ -z "$HOOK_OUT" ] && [ "$before" -eq "$after" ] \
  && echo "PASS: non-Notification events are silently ignored" \
  || { echo "FAIL: non-Notification event was not ignored (rc=$HOOK_RC) [$HOOK_OUT]"; fail=1; }

exit $fail
