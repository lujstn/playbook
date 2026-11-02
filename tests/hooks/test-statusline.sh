#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
S="$root/scripts/statusline"
export PLAYBOOK_STATE_DIR="$(mktemp -d)"
export PLAYBOOK_GLOBAL_DIR="$(mktemp -d)"
unset CLAUDE_PID
. "$root/hooks/lib/playbook-common.sh"
SID=s1
LIVE="$PLAYBOOK_STATE_DIR/$SID"
mkdir -p "$LIVE"
export PLAYBOOK_NOW=1000000

fail=0
run() { OUT="$(printf '%s' "${1:-{\}}" | bash "$S" 2>&1)"; }
PAYLOAD="$(jq -cn --arg s "$SID" '{session_id:$s}')"
eq() { [ "$OUT" = "$2" ] && echo "PASS: $1" || { echo "FAIL: $1 [got: $OUT] [want: $2]"; fail=1; }; }
reset() { rm -rf "${PLAYBOOK_STATE_DIR:?}/${SID:?}" "${PLAYBOOK_GLOBAL_DIR:?}"/*; mkdir -p "$LIVE"; }

echo "-- the bare line"
reset
run "$PAYLOAD"; eq "no state shows nothing" ""
run "{}"; eq "an empty payload is survivable" ""
run ""; eq "empty stdin is survivable" ""

echo "-- the mode, with its emoji, and never the goal"
reset
playbook_ns_confirm "$LIVE" "Ship the login page" interns picker
run "$PAYLOAD"; eq "a confirmed goal shows only its mode" "🐜 interns"
for m in "lone-wolf:🐺 lone-wolf" "hackathon:🤝 hackathon" "workflows:⚙️ workflows (awaiting opt-in)" "gsd:🏗️ gsd"; do
  reset; playbook_ns_confirm "$LIVE" "Goal" "${m%%:*}" picker
  [ "${m%%:*}" = workflows ] && playbook_state_put "$LIVE" "wf_optin=pending"
  run "$PAYLOAD"
  case "${m%%:*}" in hackathon) want="${m#*:} · ❌ no crew messages yet" ;; *) want="${m#*:}" ;; esac
  eq "${m%%:*} shows as ${m#*:}" "$want"
done

echo "-- unease shows only once it reaches a level"
reset
playbook_ns_confirm "$LIVE" "Goal" lone-wolf picker
playbook_state_put "$LIVE" "score10=49"
run "$PAYLOAD"; eq "below uneasy nothing shows" "🐺 lone-wolf"
playbook_state_put "$LIVE" "score10=50"
run "$PAYLOAD"; eq "5 is uneasy" "🐺 lone-wolf · 🟨 uneasy"
playbook_state_put "$LIVE" "score10=100"
run "$PAYLOAD"; eq "10 is concerned" "🐺 lone-wolf · 🟧 concerned"
playbook_state_put "$LIVE" "score10=150"
run "$PAYLOAD"; eq "15 is alarmed" "🐺 lone-wolf · 🟥 alarmed"
playbook_state_put "$LIVE" "score10=50" "gate=ask"
run "$PAYLOAD"; eq "a held alarm shows alarmed though the score dropped to 5" "🐺 lone-wolf · 🟥 alarmed"
playbook_state_put "$LIVE" "score10=0" "gate=judge"
run "$PAYLOAD"; eq "a held judge gate shows concerned" "🐺 lone-wolf · 🟧 concerned"
playbook_state_put "$LIVE" "gate="
run "$PAYLOAD"; eq "a released gate clears it" "🐺 lone-wolf"

echo "-- a live route beats the confirmed mode"
reset
playbook_ns_confirm "$LIVE" "Goal one" interns picker
PLAYBOOK_NOW=1000100 playbook_route_set "$LIVE" lone-wolf "reason"
run "$PAYLOAD"; eq "a route declared after the goal shows its mode" "🐺 lone-wolf"
PLAYBOOK_NOW=1000200 playbook_ns_confirm "$LIVE" "Goal two" workflows picker
run "$PAYLOAD"; eq "a goal confirmed after the route wins, awaiting the workflows opt-in" "⚙️ workflows (awaiting opt-in)"
playbook_state_put "$LIVE" "wf_optin=ok"
run "$PAYLOAD"; eq "once a launch passes the opt-in check, the mode reads workflows" "⚙️ workflows"
PLAYBOOK_NOW=1000300 playbook_route_set "$LIVE" lone-wolf "reason"
run "$PAYLOAD"; eq "a later route to another mode drops the opt-in state" "🐺 lone-wolf"
[ -z "$(playbook_state_get "$LIVE" wf_optin)" ] && echo "PASS: the opt-in state is cleared off a workflows route" || { echo "FAIL: opt-in state left behind"; fail=1; }
reset
PLAYBOOK_NOW=1000100 playbook_route_set "$LIVE" lone-wolf "single option"
run "$PAYLOAD"; eq "a route with no goal still shows its mode" "🐺 lone-wolf"

echo "-- a hackathon shows whether the crew is talking"
reset
playbook_ns_confirm "$LIVE" "Pixel board" hackathon picker
run "$PAYLOAD"; eq "before any message" "🤝 hackathon · ❌ no crew messages yet"
playbook_state_put "$LIVE" "crew_msgs=1"
run "$PAYLOAD"; eq "one message" "🤝 hackathon · 💬 1 crew message"
playbook_state_put "$LIVE" "crew_msgs=14" "score10=60"
run "$PAYLOAD"; eq "many messages, with unease after" "🤝 hackathon · 💬 14 crew messages · 🟨 uneasy"
PLAYBOOK_NOW=1000100 playbook_route_set "$LIVE" lone-wolf "after the crew"
run "$PAYLOAD"; eq "outside a hackathon the crew count is gone" "🐺 lone-wolf · 🟨 uneasy"

echo "-- the state directory is resolved like the library does"
reset
mkdir -p "$PLAYBOOK_STATE_DIR/odd.id"
playbook_ns_confirm "$PLAYBOOK_STATE_DIR/odd.id" "Odd session" gsd picker
OUT="$(printf '%s' '{"session_id":"odd/../id"}' | bash "$S" 2>&1)"
eq "a session id is sanitised the same way" ""
OUT="$(printf '%s' '{"session_id":"odd.id"}' | bash "$S" 2>&1)"
eq "a plain session id is found" "🏗️ gsd"
OUT="$(printf '%s' '{"transcript_path":"/x/y/odd.id.jsonl"}' | bash "$S" 2>&1)"
eq "the transcript name stands in for a missing session id" "🏗️ gsd"
reset
playbook_ns_confirm "$LIVE" "Parent goal" interns picker
mkdir -p "$LIVE/branch-4242"
playbook_ns_confirm "$LIVE/branch-4242" "Branch goal" lone-wolf picker
OUT="$(printf '%s' "$PAYLOAD" | CLAUDE_PID=4242 bash "$S" 2>&1)"; eq "a branch dir is used when CLAUDE_PID owns one" "🐺 lone-wolf"
OUT="$(printf '%s' "$PAYLOAD" | CLAUDE_PID=9999 bash "$S" 2>&1)"; eq "another pid falls back to the session dir" "🐜 interns"

echo "-- the wrapped command"
reset
playbook_ns_confirm "$LIVE" "Wrapped" lone-wolf picker
printf '%s\n' "echo 'base line'" > "$PLAYBOOK_GLOBAL_DIR/statusline-wrapped"
run "$PAYLOAD"; eq "the wrapped output comes first, the suffix follows on its line" "base line · 🐺 lone-wolf"
printf '%s\n' "printf 'one\ntwo\n'" > "$PLAYBOOK_GLOBAL_DIR/statusline-wrapped"
run "$PAYLOAD"; eq "the suffix goes on the last line only" "one
two · 🐺 lone-wolf"
printf '%s\n' "jq -r .session_id" > "$PLAYBOOK_GLOBAL_DIR/statusline-wrapped"
run "$PAYLOAD"; eq "the wrapped command receives the same stdin" "s1 · 🐺 lone-wolf"
printf '%s\n' "exit 3" > "$PLAYBOOK_GLOBAL_DIR/statusline-wrapped"
run "$PAYLOAD"; eq "a failing wrapped command leaves just the suffix" "🐺 lone-wolf"
printf '%s\n' "$PLAYBOOK_GLOBAL_DIR/bin/../../playbook/bin/statusline" > "$PLAYBOOK_GLOBAL_DIR/statusline-wrapped"
run "$PAYLOAD"; eq "a wrapped command that is this script is not run" "🐺 lone-wolf"
printf '%s\n' "echo 'base line'" > "$PLAYBOOK_GLOBAL_DIR/statusline-wrapped"
reset; printf '%s\n' "echo 'base line'" > "$PLAYBOOK_GLOBAL_DIR/statusline-wrapped"
run "$PAYLOAD"; eq "with nothing of Playbook's to show, the wrapped line is left as it is" "base line"
rm -f "$PLAYBOOK_GLOBAL_DIR/statusline-wrapped"

echo "-- it is self-contained and fast"
grep -q 'playbook-common' "$S" && { echo "FAIL: the script sources the library"; fail=1; } || echo "PASS: the script does not source the library"
[ -x "$S" ] && echo "PASS: the script is executable" || { echo "FAIL: not executable"; fail=1; }
n="$(grep -c 'jq ' "$S" || true)"
[ "$n" -le 2 ] && echo "PASS: one jq call at most in the script" || { echo "FAIL: jq calls ($n)"; fail=1; }

t0=$(date +%s)
for i in 1 2 3 4 5 6 7 8 9 10; do printf '%s' "$PAYLOAD" | bash "$S" >/dev/null; done
t1=$(date +%s)
[ $(( t1 - t0 )) -le 5 ] && echo "PASS: ten runs finish within five seconds" || { echo "FAIL: ten runs took $(( t1 - t0 ))s"; fail=1; }

exit $fail
