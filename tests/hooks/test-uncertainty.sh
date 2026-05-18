#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
H="$root/hooks/uncertainty"
# Deterministically select the Claude Code platform branch of
# playbook_emit_context (the decided Stop channel is its hookSpecificOutput
# form). Without this the test is non-deterministic: a bare environment hits
# the else/bare-additionalContext branch and assertion (b) fails. Same
# correctness fix accepted for test-take-a-beat.sh in Task 7.
export CLAUDE_PLUGIN_ROOT="$root"
unset CURSOR_PLUGIN_ROOT COPILOT_CLI 2>/dev/null || true
out="$(echo '{"hook_event_name":"Stop"}' | bash "$H")"
# (a) The confidant gate prompt is present (verbatim VB-style sentence).
grep -qi "would a competent colleague bother flagging" <<<"$out" && echo "PASS: gate question present" || { echo FAIL gate; exit 1; }
# (b) Channel shape per docs/playbook/decisions/2026-05-16-stop-channel.md
#     (e.g. jq -e '.hookSpecificOutput.additionalContext' OR the decided carrier).
jq -e '.hookSpecificOutput.additionalContext' <<<"$out" >/dev/null && echo "PASS: decided channel shape" || { echo FAIL channel; exit 1; }
# (c) Termination guard (regression for review finding C1): the hook MUST NOT
#     emit an unconditional decision:block, which would trap every turn in
#     infinite continuation. design.md §4 forbids the hook computing anything,
#     so a conditional block is also impossible here -> assert no block at all.
jq -e '(.decision // "") != "block"' <<<"$out" >/dev/null && echo "PASS: turn can terminate (no forced block)" || { echo "FAIL: hook would force infinite continuation"; exit 1; }
# (d) Hook prompts only: design.md §4 says the uncertainty hook performs no
#     computation and holds no score, it only prompts. The verbatim prompt
#     legitimately NAMES the five band slugs as instruction to the agent, so
#     grepping the output for slug words cannot distinguish "hook editorialised
#     a band" from "prompt lists the valid slugs" and is unsatisfiable for the
#     correct hook. The genuine property is that the hook authors NO ledger
#     entry: running it must not create the uncertainty ledger file.
d_tmp="$(mktemp -d)"
printf '{"hook_event_name":"Stop","cwd":"%s"}' "$d_tmp" | bash "$H" >/dev/null 2>&1 || true
if [ -e "$d_tmp/.playbook/uncertainty-ledger.md" ]; then
  rm -rf "$d_tmp"; echo "FAIL: hook wrote the ledger (must only prompt)"; exit 1
fi
rm -rf "$d_tmp"
echo "PASS: hook prompts only (authored no ledger entry)"
