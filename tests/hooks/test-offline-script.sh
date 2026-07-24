#!/usr/bin/env bash
# Tests for scripts/offline: manages the per-session offline flag and appends
# to the durable decision log. The state directory is resolved from the
# newest transcript for the current working directory, exactly as a running
# session would resolve it, so these tests fake ~/.claude/projects/<encoded-
# cwd>/ rather than pointing PLAYBOOK_STATE_DIR at a pre-made session dir.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
OFFLINE="$root/scripts/offline"

fail=0

sandbox="$(mktemp -d)"
trap 'rm -rf "$sandbox"' EXIT

proj="$sandbox/proj"
mkdir -p "$proj"
enc="$(printf '%s' "$proj" | tr '/' '-')"
fake_home="$sandbox/home"
mkdir -p "$fake_home/.claude/projects/$enc"
printf '{"type":"user","message":{"role":"user","content":"hi"}}\n' > "$fake_home/.claude/projects/$enc/session.jsonl"

state_dir="$sandbox/state"
sess_dir="$state_dir/session"  # sanitised stem of session.jsonl, no session_id given
flag="$sess_dir/offline"
log_file="$sess_dir/offline-log.jsonl"

OFFLINE_OUT=""
OFFLINE_RC=0
run_offline() {
  OFFLINE_OUT="$(HOME="$fake_home" PLAYBOOK_STATE_DIR="$state_dir" \
    bash -c "cd '$proj' && '$OFFLINE' \"\$@\"" -- "$@" 2>&1)" && OFFLINE_RC=0 || OFFLINE_RC=$?
}

echo "-- on with defaults"
rm -rf "$state_dir"
run_offline on
[ "$OFFLINE_RC" -eq 0 ] && echo "PASS: on exits 0" || { echo "FAIL: on rc=$OFFLINE_RC [$OFFLINE_OUT]"; fail=1; }
[ -f "$flag" ] && echo "PASS: the flag file is written" || { echo "FAIL: no flag file at $flag"; fail=1; }
grep -qx 'window=10' "$flag" && echo "PASS: default window is 10" \
  || { echo "FAIL: default window wrong [$(cat "$flag" 2>/dev/null)]"; fail=1; }
grep -qx 'wait=a' "$flag" && echo "PASS: default wait is a" \
  || { echo "FAIL: default wait wrong [$(cat "$flag" 2>/dev/null)]"; fail=1; }
since_val="$(awk -F= '/^since=/{print $2}' "$flag" 2>/dev/null)"
case "$since_val" in
  ''|*[!0-9]*) echo "FAIL: since is not an integer [$since_val]"; fail=1 ;;
  *) echo "PASS: since is an integer epoch" ;;
esac
echo "$OFFLINE_OUT" | grep -qF "$log_file" \
  && echo "PASS: the confirmation line names the log path" \
  || { echo "FAIL: confirmation missing log path [$OFFLINE_OUT]"; fail=1; }

echo "-- on with explicit window and wait"
run_offline on --window 25 --wait b
[ "$OFFLINE_RC" -eq 0 ] && echo "PASS: on --window --wait exits 0" || { echo "FAIL: rc=$OFFLINE_RC"; fail=1; }
grep -qx 'window=25' "$flag" && echo "PASS: --window 25 is honoured" \
  || { echo "FAIL: window not 25 [$(cat "$flag")]"; fail=1; }
grep -qx 'wait=b' "$flag" && echo "PASS: --wait b is honoured" \
  || { echo "FAIL: wait not b [$(cat "$flag")]"; fail=1; }

echo "-- validation"
run_offline on --window abc
[ "$OFFLINE_RC" -eq 64 ] && echo "PASS: non-numeric --window yields usage exit 64" \
  || { echo "FAIL: non-numeric window rc=$OFFLINE_RC"; fail=1; }
run_offline on --window 0
[ "$OFFLINE_RC" -eq 64 ] && echo "PASS: --window 0 yields usage exit 64" \
  || { echo "FAIL: zero window rc=$OFFLINE_RC"; fail=1; }
run_offline on --wait c
[ "$OFFLINE_RC" -eq 64 ] && echo "PASS: an invalid --wait value yields usage exit 64" \
  || { echo "FAIL: bad wait rc=$OFFLINE_RC"; fail=1; }

echo "-- off removes the flag"
run_offline on
[ -f "$flag" ] || { echo "FAIL: setup for off test failed"; fail=1; }
run_offline off
[ "$OFFLINE_RC" -eq 0 ] && echo "PASS: off exits 0" || { echo "FAIL: off rc=$OFFLINE_RC"; fail=1; }
[ ! -f "$flag" ] && echo "PASS: the flag file is removed" || { echo "FAIL: flag file still present"; fail=1; }

echo "-- status reflects on and off"
run_offline status
[ "$OFFLINE_RC" -eq 0 ] && [ "$OFFLINE_OUT" = "off" ] \
  && echo "PASS: status reports off when the flag is absent" \
  || { echo "FAIL: status when off was [$OFFLINE_OUT] rc=$OFFLINE_RC"; fail=1; }
run_offline on --window 15 --wait a
run_offline status
{ [ "$OFFLINE_RC" -eq 0 ] && printf '%s\n' "$OFFLINE_OUT" | grep -qx 'on' \
    && printf '%s\n' "$OFFLINE_OUT" | grep -qx 'window=15' \
    && printf '%s\n' "$OFFLINE_OUT" | grep -q 'log lines: '; } \
  && echo "PASS: status reports on, the flag contents, and a log line count" \
  || { echo "FAIL: status when on was [$OFFLINE_OUT]"; fail=1; }

echo "-- log appends a JSON object with ts added"
rm -f "$log_file"
run_offline log '{"event":"decision","summary":"x"}'
[ "$OFFLINE_RC" -eq 0 ] && echo "PASS: log exits 0" || { echo "FAIL: log rc=$OFFLINE_RC [$OFFLINE_OUT]"; fail=1; }
[ -z "$OFFLINE_OUT" ] && echo "PASS: log prints nothing on success" \
  || { echo "FAIL: log printed output [$OFFLINE_OUT]"; fail=1; }
last="$(tail -n1 "$log_file")"
jq -e '.event == "decision" and .summary == "x" and (.ts|type) == "number"' >/dev/null 2>&1 <<<"$last" \
  && echo "PASS: the logged line carries the given fields plus ts" \
  || { echo "FAIL: logged line malformed [$last]"; fail=1; }

echo "-- log defaults the event field when absent"
run_offline log '{"summary":"y"}'
last="$(tail -n1 "$log_file")"
jq -e '.event == "decision" and .summary == "y"' >/dev/null 2>&1 <<<"$last" \
  && echo "PASS: a missing event field defaults to decision" \
  || { echo "FAIL: default event missing [$last]"; fail=1; }

echo "-- log rejects invalid JSON"
run_offline log 'not json'
[ "$OFFLINE_RC" -eq 64 ] && echo "PASS: invalid JSON to log yields usage exit 64" \
  || { echo "FAIL: invalid JSON rc=$OFFLINE_RC"; fail=1; }

echo "-- no transcript for this directory"
noproj="$sandbox/noproj"
mkdir -p "$noproj"
OFFLINE_OUT="$(HOME="$sandbox/empty-home" PLAYBOOK_STATE_DIR="$state_dir" \
  bash -c "cd '$noproj' && '$OFFLINE' status" 2>&1)" && OFFLINE_RC=0 || OFFLINE_RC=$?
[ "$OFFLINE_RC" -eq 3 ] && echo "PASS: no transcript for the directory yields exit 3" \
  || { echo "FAIL: no-transcript rc=$OFFLINE_RC [$OFFLINE_OUT]"; fail=1; }

echo "-- usage"
run_offline
[ "$OFFLINE_RC" -eq 64 ] && echo "PASS: no args yields usage exit 64" \
  || { echo "FAIL: no-args rc=$OFFLINE_RC"; fail=1; }
run_offline --help
[ "$OFFLINE_RC" -eq 64 ] && echo "PASS: --help yields usage exit 64" \
  || { echo "FAIL: --help rc=$OFFLINE_RC"; fail=1; }
run_offline bogus
[ "$OFFLINE_RC" -eq 64 ] && echo "PASS: an unknown subcommand yields usage exit 64" \
  || { echo "FAIL: unknown subcommand rc=$OFFLINE_RC"; fail=1; }

exit $fail
