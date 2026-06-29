#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
H="$root/hooks/unease"
export CLAUDE_PLUGIN_ROOT="$root"
unset CURSOR_PLUGIN_ROOT COPILOT_CLI 2>/dev/null || true
out="$(printf '{"hook_event_name":"Stop"}' | bash "$H")"

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

for bad in '' 'not json at all' '{"hook_event_name":"Stop"' 'true'; do
  if bo="$(printf '%s' "$bad" | bash "$H" 2>/dev/null)"; then :; else
    echo "FAIL: stdin [$bad] aborted the hook (exit non-zero)"; exit 1; fi
  jq -e '.hookSpecificOutput.additionalContext' <<<"$bo" >/dev/null \
    && jq -e '.hookSpecificOutput.hookEventName == "Stop"' <<<"$bo" >/dev/null \
    || { echo "FAIL: stdin [$bad] did not yield a valid Stop envelope"; exit 1; }
done
echo "PASS: empty and non-JSON stdin still yield a valid Stop envelope"

d_tmp="$(mktemp -d)"
printf '{"hook_event_name":"Stop","cwd":"%s"}' "$d_tmp" | bash "$H" >/dev/null 2>&1 || true
[ ! -e "$d_tmp/.playbook" ] && echo "PASS: writes no file into the project" \
  || { rm -rf "$d_tmp"; echo "FAIL: hook created .playbook"; exit 1; }
rm -rf "$d_tmp"

# SubagentStop: unease also fires on SubagentStop with the right event name.
sout="$(printf '{"hook_event_name":"SubagentStop","agent_id":"a1"}' | bash "$H")"
jq -e '.hookSpecificOutput.additionalContext' <<<"$sout" >/dev/null \
  && echo "PASS: SubagentStop yields additionalContext channel" \
  || { echo "FAIL: SubagentStop additionalContext missing"; exit 1; }
jq -e '.hookSpecificOutput.hookEventName == "SubagentStop"' <<<"$sout" >/dev/null \
  && echo "PASS: SubagentStop envelope event name" \
  || { echo "FAIL: SubagentStop envelope event name wrong"; exit 1; }
ctx_sa="$(jq -r '.hookSpecificOutput.additionalContext' <<<"$sout")"
grep -q "near_breaking" <<<"$ctx_sa" \
  && echo "PASS: SubagentStop unease prompt content unchanged" \
  || { echo "FAIL: SubagentStop unease prompt content wrong"; exit 1; }
