#!/usr/bin/env bash
set -uo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
source "$root/hooks/lib/playbook-common.sh"
FIX="$root/tests/hooks/fixtures"
fail=0

pass() { echo "PASS: $1"; }
flunk() { echo "FAIL: $1"; fail=1; }
chk() { if eval "$1" >/dev/null 2>&1; then pass "$2"; else flunk "$2"; fi }

stdin_for() { jq -cn --arg t "$1" '{transcript_path: $t}'; }

chk '[ "$(playbook_unease_rank clear)" = 0 ]' "rank: clear is 0"
chk '[ "$(playbook_unease_rank watchful)" = 3 ]' "rank: watchful is 3"
chk '[ "$(playbook_unease_rank concerned)" = 6 ]' "rank: concerned is 6"
chk '[ "$(playbook_unease_rank near_breaking)" = 10 ]' "rank: near_breaking is 10"
chk '[ -z "$(playbook_unease_rank panicking)" ]' "rank: unknown level is empty"
chk '[ -z "$(playbook_unease_rank "")" ]' "rank: empty level is empty"

scan="$(playbook_scan_tail "$(stdin_for "$FIX/transcript-unease.jsonl")")"
chk 'grep -qx "marker_level=uneasy" <<<"$scan"' "scan: last concrete marker wins"
chk 'grep -qx "marker_reason=auth tests still failing" <<<"$scan"' "scan: reason captured from the last marker"
chk '! grep -q "alarmed" <<<"$scan"' "scan: marker inside a user record never parses"
chk '! grep -q "marker_level=<level>" <<<"$scan"' "scan: placeholder level never parses"
chk 'grep -qx "bash_fail=1" <<<"$scan"' "scan: failing Bash test output detected"
chk 'grep -qx "marker_count=2" <<<"$scan"' "scan: marker count tallies every concrete marker"
chk 'grep -qx "northstar=evidence-backed addresses for every org" <<<"$scan"' "scan: the last visible northstar restatement is captured"
chk '! grep -q "the old goal line" <<<"$scan"' "scan: an earlier northstar statement is superseded"
chk '! grep -q "injected goal" <<<"$scan"' "scan: a northstar line in a user record never parses"
chk '! grep -q "northstar=<" <<<"$scan"' "scan: the placeholder northstar form never parses"

readscan="$(playbook_scan_tail "$(stdin_for "$FIX/transcript-readfail.jsonl")")"
chk '! grep -q "^marker_level=" <<<"$readscan"' "scan: no marker line when none stated"
chk 'grep -qx "marker_count=0" <<<"$readscan"' "scan: marker count is zero when none stated"
chk 'grep -qx "bash_fail=0" <<<"$readscan"' "scan: FAIL text in a Read result does not trip"

basescan="$(playbook_scan_tail "$(stdin_for "$FIX/transcript-basic.jsonl")")"
chk 'grep -qx "bash_fail=0" <<<"$basescan"' "scan: quiet transcript reports bash_fail=0"
chk '! grep -q "^northstar=" <<<"$basescan"' "scan: no northstar line when none stated"
chk '[ -z "$(playbook_scan_tail "$(stdin_for /nonexistent/t.jsonl)")" ]' "scan: missing transcript emits nothing"
chk '[ -z "$(playbook_scan_tail "not json")" ]' "scan: malformed stdin emits nothing"

exc="$(playbook_northstar_excerpt "$(stdin_for "$FIX/transcript-basic.jsonl")")"
chk '[ "$exc" = "Build me a widget that does X. Original request text." ]' "excerpt: first line of the original request"

long="$(mktemp)"
jq -cn '{type:"user", message:{role:"user", content:("x" * 300)}}' > "$long"
lexc="$(playbook_northstar_excerpt "$(stdin_for "$long")")"
chk '[ "${#lexc}" -le 140 ]' "excerpt: truncated to at most 140 characters"
rm -f "$long"
chk '[ -z "$(playbook_northstar_excerpt "$(stdin_for /nonexistent/t.jsonl)")" ]' "excerpt: missing transcript is empty"

exit $fail
