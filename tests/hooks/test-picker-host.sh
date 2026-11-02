#!/usr/bin/env bash
set -uo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
H="$root/tests/routing-shape/picker-host.py"
fail=0
pass()  { echo "PASS: $1"; }
flunk() { echo "FAIL: $1"; fail=1; }
eq()    { if [ "$2" = "$3" ]; then pass "$1"; else flunk "$1 (expected [$2], got [$3])"; fi }
command -v python3 >/dev/null || { echo "SKIP: python3 not installed"; exit 0; }
command -v jq      >/dev/null || { echo "SKIP: jq not installed"; exit 0; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
call() { printf '{"jsonrpc":"2.0","id":9,"method":"tools/call","params":{"name":"answer","arguments":%s}}\n' "$1"; }
OUT="$( { printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18"}}\n'
          printf '{"jsonrpc":"2.0","method":"notifications/initialized"}\n'
          printf '{"jsonrpc":"2.0","id":2,"method":"tools/list"}\n'
          call '{"tool_name":"AskUserQuestion","input":{"questions":[{"question":"Goal: Ship it · Mode: which fits?","options":[{"label":"lone-wolf"},{"label":"interns (Recommended)"}]},{"question":"Tests?","options":[{"label":"Yes"},{"label":"No"}]}]}}'
          call '{"tool_name":"Bash","input":{"command":"rm -rf /"}}'
          printf '{"jsonrpc":"2.0","id":7,"method":"resources/list"}\n'
        } | PICKER_HOST_LOG="$T/log" python3 -I "$H")"
eq "it answers initialize, list, two calls and an unknown method, and stays silent on the notification" "5" "$(grep -c . <<<"$OUT")"
eq "it echoes the protocol version" "2025-06-18" "$(sed -n 1p <<<"$OUT" | jq -r '.result.protocolVersion')"
eq "it offers one tool named answer" "answer" "$(sed -n 2p <<<"$OUT" | jq -r '.result.tools | map(.name) | join(",")')"
ask="$(sed -n 3p <<<"$OUT" | jq -r '.result.content[0].text')"
eq "the picker is allowed" "allow" "$(jq -r '.behavior' <<<"$ask")"
eq "with the option marked (Recommended)" "interns (Recommended)" "$(jq -r '.updatedInput.answers["Goal: Ship it · Mode: which fits?"]' <<<"$ask")"
eq "a question with no recommendation gets its first option" "Yes" "$(jq -r '.updatedInput.answers["Tests?"]' <<<"$ask")"
eq "the questions are echoed back unchanged" "2" "$(jq -r '.updatedInput.questions | length' <<<"$ask")"
eq "every other permission request is refused" "deny" "$(sed -n 4p <<<"$OUT" | jq -r '.result.content[0].text' | jq -r '.behavior')"
eq "an unknown method is an error, not silence" "-32601" "$(sed -n 5p <<<"$OUT" | jq -r '.error.code')"
eq "each call is logged" "2" "$(grep -c . "$T/log")"
exit $fail
