#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
H="$root/hooks/unease"
export CLAUDE_PLUGIN_ROOT="$root"
unset CURSOR_PLUGIN_ROOT COPILOT_CLI 2>/dev/null || true
out="$(echo '{"hook_event_name":"Stop"}' | bash "$H")"

jq -e '.hookSpecificOutput.additionalContext' <<<"$out" >/dev/null \
  && echo "PASS: model-visible additionalContext channel" || { echo FAIL channel; exit 1; }
jq -e '.hookSpecificOutput.hookEventName == "Stop"' <<<"$out" >/dev/null \
  && echo "PASS: hookEventName Stop" || { echo FAIL eventname; exit 1; }
jq -e '(.decision // "") != "block"' <<<"$out" >/dev/null \
  && echo "PASS: no forced block, turn can terminate" || { echo FAIL block; exit 1; }
jq -e '(.continue // true) == true' <<<"$out" >/dev/null \
  && echo "PASS: continue not disabled" || { echo FAIL continue; exit 1; }
ctx="$(jq -r '.hookSpecificOutput.additionalContext' <<<"$out")"
grep -q "near_breaking" <<<"$ctx" && grep -q "sharply_reduced" <<<"$ctx" \
  && echo "PASS: level and movement enums present in the constant prompt" \
  || { echo "FAIL: enums missing from prompt"; exit 1; }
grep -qi "only if it changed" <<<"$ctx" \
  && echo "PASS: silence-is-no-update instruction present" || { echo FAIL noupdate; exit 1; }
grep -q "regardless of the unease level or the mode" <<<"$ctx" \
  && echo "PASS: standing North-Star override verbatim, no ledger" || { echo FAIL override; exit 1; }
! grep -qi "ledger" <<<"$ctx" \
  && echo "PASS: no ledger vocabulary" || { echo "FAIL: ledger word present"; exit 1; }

d_tmp="$(mktemp -d)"
printf '{"hook_event_name":"Stop","cwd":"%s"}' "$d_tmp" | bash "$H" >/dev/null 2>&1 || true
[ ! -e "$d_tmp/.playbook" ] && echo "PASS: writes no file into the project" \
  || { rm -rf "$d_tmp"; echo "FAIL: hook created .playbook"; exit 1; }
rm -rf "$d_tmp"
