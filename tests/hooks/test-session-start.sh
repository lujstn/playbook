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
jq -e . <<<"$out" >/dev/null && echo "PASS: valid JSON" || { echo FAIL json; exit 1; }
