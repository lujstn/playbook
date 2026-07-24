#!/usr/bin/env bash
# Tests for hooks/notification: forwards a Notification event to scripts/notify
# only while the offline flag is set, maps the notification kind to a level
# and headline, and appends one line to the durable JSONL decision log
# whether the send succeeded or failed. Never speaks on stdout/stderr, and
# never fails the hook regardless of the stub's own exit code.
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

echo "-- agent_completed maps to info"
run_hook "$(payload agent_completed '')"
grep -qx '  --level' "$stub_log" && grep -qx '  info' "$stub_log" \
  && echo "PASS: agent_completed maps to --level info" \
  || { echo "FAIL: agent_completed did not map to info [$(cat "$stub_log")]"; fail=1; }
grep -qx '  Session finished while you were away' "$stub_log" \
  && echo "PASS: agent_completed uses the finished headline as detail when no message is given" \
  || { echo "FAIL: agent_completed detail fallback wrong [$(cat "$stub_log")]"; fail=1; }

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
