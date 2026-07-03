#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
H="$root/hooks/session-start"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
out="$(printf '{"cwd":"%s","hook_event_name":"SessionStart","source":"startup"}' "$tmp" | bash "$H")"
ctx="$(jq -r '.hookSpecificOutput.additionalContext // .additional_context // .additionalContext' <<<"$out")"
[ -n "$ctx" ] && echo "PASS: overlay injected" || { echo FAIL; exit 1; }
grep -q "PLAYBOOK_OVERLAY" <<<"$ctx" && echo "PASS: sentinel tag" || { echo FAIL tag; exit 1; }
n=$(grep -cE '^[1-9]\. ' <<<"$ctx"); [ "$n" -eq 9 ] && echo "PASS: nine tenets" || { echo "FAIL: $n tenets"; exit 1; }
grep -q "regardless of the unease level or the mode" <<<"$ctx" \
  && echo "PASS: standing override verbatim, no ledger" || { echo FAIL override; exit 1; }
! grep -q '\.playbook/' <<<"$ctx" && ! grep -qi 'anchor file is the persistence' <<<"$ctx" \
  && echo "PASS: no file-persistence claim" || { echo "FAIL: still claims a file persists"; exit 1; }
! grep -qi 'uncertainty' <<<"$ctx" && echo "PASS: unease naming" || { echo "FAIL: uncertainty word present"; exit 1; }
grep -q 'execute on Sonnet' <<<"$ctx" && grep -q 'plan and review' <<<"$ctx" \
  && echo "PASS: model rule present in overlay" \
  || { echo "FAIL: model rule missing"; exit 1; }
grep -q 'auto-compact is seamless' <<<"$ctx" && grep -q 'Do not wrap up early' <<<"$ctx" \
  && echo "PASS: context-calm doctrine in overlay" \
  || { echo "FAIL: context-calm doctrine missing"; exit 1; }
grep -qF 'Playbook · ' <<<"$ctx" \
  && echo "PASS: Playbook middot brand convention in overlay" \
  || { echo "FAIL: Playbook middot brand missing"; exit 1; }
jq -e . <<<"$out" >/dev/null && echo "PASS: valid JSON" || { echo FAIL json; exit 1; }

# SubagentStart: the same overlay must reach a spawned subagent, and the
# envelope must carry the actual event name so Claude Code routes it (a
# hardcoded "SessionStart" would be ignored for a SubagentStart firing).
export CLAUDE_PLUGIN_ROOT="$root"
unset CURSOR_PLUGIN_ROOT COPILOT_CLI 2>/dev/null || true
sout="$(printf '{"hook_event_name":"SubagentStart","agent_id":"a1","agent_type":"general-purpose"}' | bash "$H")"
sev="$(jq -r '.hookSpecificOutput.hookEventName' <<<"$sout")"
sctx="$(jq -r '.hookSpecificOutput.additionalContext' <<<"$sout")"
[ "$sev" = "SubagentStart" ] && echo "PASS: SubagentStart envelope event name" \
  || { echo "FAIL: envelope event was [$sev]"; exit 1; }
grep -q "PLAYBOOK_OVERLAY" <<<"$sctx" && echo "PASS: overlay reaches subagent" \
  || { echo FAIL subagent overlay; exit 1; }
{ grep -q "playbook-northstar" <<<"$sctx" && grep -qi "sub-goal serving it" <<<"$sctx"; } \
  && echo "PASS: overlay carries the project North Star precedence clause" \
  || { echo FAIL northstar clause; exit 1; }
{ grep -q "Playbook helper report:" <<<"$sctx" && grep -q "attentive or above" <<<"$sctx"; } \
  && echo "PASS: SubagentStart asks for the elevated-only closing unease line" \
  || { echo "FAIL: helper-report block missing from SubagentStart"; exit 1; }
mout="$(printf '{"hook_event_name":"SessionStart","source":"startup"}' | bash "$H")"
[ "$(jq -r '.hookSpecificOutput.hookEventName' <<<"$mout")" = "SessionStart" ] \
  && echo "PASS: SessionStart envelope event name unchanged" \
  || { echo FAIL sessionstart event name; exit 1; }
mctx="$(jq -r '.hookSpecificOutput.additionalContext' <<<"$mout")"
! grep -q "Playbook helper report:" <<<"$mctx" \
  && echo "PASS: the helper-report block is subagent-only, absent on a main SessionStart" \
  || { echo "FAIL: helper-report block leaked into a main SessionStart"; exit 1; }

# Event guard: an unwired event (Stop) yields empty output and exits 0.
if gout="$(printf '{"hook_event_name":"Stop"}' | bash "$H" 2>/dev/null)"; then :; else
  echo "FAIL: Stop payload aborted session-start"; exit 1; fi
[ -z "$gout" ] && echo "PASS: session-start is silent on an unwired event (Stop)" \
  || { echo "FAIL: Stop payload produced output: [$gout]"; exit 1; }
