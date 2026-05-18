#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
H="$root/hooks/session-start"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
source "$root/hooks/lib/playbook-common.sh"

# No anchor yet: still injects the self-contained digest, valid JSON.
out="$(printf '{"cwd":"%s","hook_event_name":"SessionStart","source":"startup"}' "$tmp" | bash "$H")"
ctx="$(jq -r '.hookSpecificOutput.additionalContext // .additional_context // .additionalContext' <<<"$out")"
[ -n "$ctx" ] && echo "PASS: overlay injected" || { echo FAIL; exit 1; }
grep -q "PLAYBOOK_OVERLAY" <<<"$ctx" && echo "PASS: distinct sentinel tag (m2)" || { echo "FAIL: tag"; exit 1; }
# M4: digest is self-contained, all nine tenets enumerated, not a skill pointer.
n=$(grep -cE '^[1-9]\. ' <<<"$ctx"); [ "$n" -eq 9 ] && echo "PASS: all nine tenets present" || { echo "FAIL: only $n tenets"; exit 1; }
grep -q "stop and ask the user before proceeding, regardless of the uncertainty ledger or the mode" <<<"$ctx" \
  && echo "PASS: standing override verbatim (VB-1)" || { echo "FAIL: VB-1 missing"; exit 1; }

# Anchor present: re-injected with primacy.
playbook_anchor_init "ORIG-REQ-Z" "WHAT-MATTERS-Z" "$(printf '{"cwd":"%s"}' "$tmp")"
out="$(printf '{"cwd":"%s","hook_event_name":"SessionStart","source":"compact"}' "$tmp" | bash "$H")"
grep -q "ORIG-REQ-Z" <<<"$out" && echo "PASS: anchor re-injected after compact" || { echo FAIL; exit 1; }
jq -e . <<<"$out" >/dev/null && echo "PASS: valid JSON" || { echo "FAIL invalid JSON"; exit 1; }
