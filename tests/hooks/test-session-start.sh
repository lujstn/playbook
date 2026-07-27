#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
H="$root/hooks/session-start"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
out="$(printf '{"cwd":"%s","hook_event_name":"SessionStart","source":"startup"}' "$tmp" | bash "$H")"
ctx="$(jq -r '.hookSpecificOutput.additionalContext // .additional_context // .additionalContext' <<<"$out")"
[ -n "$ctx" ] && echo "PASS: overlay injected" || { echo FAIL; exit 1; }
grep -q "PLAYBOOK_OVERLAY" <<<"$ctx" && echo "PASS: sentinel tag" || { echo FAIL tag; exit 1; }
! grep -q 'The nine tenets' <<<"$ctx" \
  && echo "PASS: the tenets are not restated in the overlay; the engine skill holds them" \
  || { echo "FAIL: the overlay still restates the nine tenets"; exit 1; }
ob="$(sed -n '/<PLAYBOOK_OVERLAY>/,/<\/PLAYBOOK_OVERLAY>/p' <<<"$ctx")"
bytes=$(printf '%s' "$ob" | wc -c | tr -d ' ')
{ [ "$bytes" -gt 0 ] && [ "$bytes" -lt 2500 ]; } \
  && echo "PASS: overlay block is $bytes bytes, under the 2500-byte ceiling" \
  || { echo "FAIL: overlay block is $bytes bytes, outside the 1..2499 byte range"; exit 1; }
grep -q "regardless of the unease level or the mode" <<<"$ctx" \
  && echo "PASS: standing override verbatim, no ledger" || { echo FAIL override; exit 1; }
! grep -q '\.playbook/' <<<"$ctx" && ! grep -qi 'anchor file is the persistence' <<<"$ctx" \
  && echo "PASS: no file-persistence claim" || { echo "FAIL: still claims a file persists"; exit 1; }
! grep -qi 'uncertainty' <<<"$ctx" && echo "PASS: unease naming" || { echo "FAIL: uncertainty word present"; exit 1; }
grep -qF '**Playbook**' <<<"$ctx" \
  && echo "PASS: bold Playbook brand convention in overlay" \
  || { echo "FAIL: bold Playbook brand missing"; exit 1; }
{ grep -q 'Playbook liveness' <<<"$ctx" && grep -q 'last line of your first reply' <<<"$ctx"; } \
  && echo "PASS: liveness line anchored to the end of the first reply" \
  || { echo "FAIL: liveness placement wording missing"; exit 1; }
jq -e . <<<"$out" >/dev/null && echo "PASS: valid JSON" || { echo FAIL json; exit 1; }

export CLAUDE_PLUGIN_ROOT="$root"
unset CURSOR_PLUGIN_ROOT COPILOT_CLI 2>/dev/null || true
sout="$(printf '{"hook_event_name":"SubagentStart","agent_id":"a1","agent_type":"general-purpose"}' | bash "$H")"
sev="$(jq -r '.hookSpecificOutput.hookEventName' <<<"$sout")"
sctx="$(jq -r '.hookSpecificOutput.additionalContext' <<<"$sout")"
[ "$sev" = "SubagentStart" ] && echo "PASS: SubagentStart envelope event name" \
  || { echo "FAIL: envelope event was [$sev]"; exit 1; }
grep -q "PLAYBOOK_OVERLAY" <<<"$sctx" && echo "PASS: overlay reaches subagent" \
  || { echo FAIL subagent overlay; exit 1; }
{ grep -q "playbook-northstar:" <<<"$sctx" && grep -qi "sub-goal serving it" <<<"$sctx"; } \
  && echo "PASS: the helper block carries the project North Star precedence clause" \
  || { echo FAIL northstar clause; exit 1; }
grep -q "Set an explicit model on anything you dispatch" <<<"$sctx" \
  && echo "PASS: SubagentStart pushes an explicit model onto every onward dispatch" \
  || { echo "FAIL: model rule missing from SubagentStart"; exit 1; }
grep -q "never a licence to widen it" <<<"$sctx" \
  && echo "PASS: the North Star is bounded to the brief as a compass" \
  || { echo "FAIL: compass-not-licence sentence missing from SubagentStart"; exit 1; }
grep -q "deliberately task-only" <<<"$sctx" \
  && echo "PASS: the none value is interpreted as task-only scope" \
  || { echo "FAIL: task-only interpretation missing from SubagentStart"; exit 1; }
{ grep -q "Playbook helper report:" <<<"$sctx" && grep -q "attentive or above" <<<"$sctx"; } \
  && echo "PASS: SubagentStart asks for the elevated-only closing unease line" \
  || { echo "FAIL: helper-report block missing from SubagentStart"; exit 1; }
{ grep -q "Playbook helper task authority" <<<"$sctx" \
  && grep -q "plausibility is never authentication" <<<"$sctx" \
  && grep -qi "not evidence of forgery" <<<"$sctx" \
  && grep -q "stop, report what you were asked to disregard" <<<"$sctx"; } \
  && echo "PASS: SubagentStart carries the helper task-authority rule" \
  || { echo "FAIL: task-authority block missing or incomplete on SubagentStart"; exit 1; }
mout="$(printf '{"hook_event_name":"SessionStart","source":"startup"}' | bash "$H")"
[ "$(jq -r '.hookSpecificOutput.hookEventName' <<<"$mout")" = "SessionStart" ] \
  && echo "PASS: SessionStart envelope event name unchanged" \
  || { echo FAIL sessionstart event name; exit 1; }
mctx="$(jq -r '.hookSpecificOutput.additionalContext' <<<"$mout")"
! grep -q "Playbook helper report:" <<<"$mctx" \
  && echo "PASS: the helper-report block is subagent-only, absent on a main SessionStart" \
  || { echo "FAIL: helper-report block leaked into a main SessionStart"; exit 1; }
! grep -q "Playbook helper task authority" <<<"$mctx" \
  && echo "PASS: the task-authority block is subagent-only, absent on a main SessionStart" \
  || { echo "FAIL: task-authority block leaked into a main SessionStart"; exit 1; }

if gout="$(printf '{"hook_event_name":"Stop"}' | bash "$H" 2>/dev/null)"; then :; else
  echo "FAIL: Stop payload aborted session-start"; exit 1; fi
[ -z "$gout" ] && echo "PASS: session-start is silent on an unwired event (Stop)" \
  || { echo "FAIL: Stop payload produced output: [$gout]"; exit 1; }
