#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
source "$root/hooks/lib/playbook-common.sh"
B="$root/tests/hooks/fixtures/transcript-basic.jsonl"
T="$root/tests/hooks/fixtures/transcript-beat.jsonl"
stdin_b="$(printf '{"transcript_path":"%s"}' "$B")"
stdin_t="$(printf '{"transcript_path":"%s"}' "$T")"

req="$(playbook_original_request "$stdin_b")"
[ "$req" = "Build me a widget that does X. Original request text." ] \
  && echo "PASS: original request recovered, system record skipped" \
  || { echo "FAIL: original request was [$req]"; exit 1; }

M="$root/tests/hooks/fixtures/transcript-multiline.jsonl"
stdin_m="$(printf '{"transcript_path":"%s"}' "$M")"
mreq="$(playbook_original_request "$stdin_m")"
mexp="$(printf 'First paragraph of the ask.\nSecond paragraph with detail.\nThird line.')"
[ "$mreq" = "$mexp" ] \
  && echo "PASS: full multi-line original request recovered verbatim, later turn skipped" \
  || { echo "FAIL: multi-line request was [$mreq]"; exit 1; }

used="$(playbook_context_used "$stdin_b")"
[ "$used" = "10020" ] && echo "PASS: usage sum = last assistant input+cache" \
  || { echo "FAIL: used was [$used], expected 10020"; exit 1; }

win="$(playbook_declared_window "$stdin_b")"
[ "$win" = "1000000" ] && echo "PASS: declared window parsed" \
  || { echo "FAIL: window was [$win]"; exit 1; }

# Regression lock: an assistant declaration of 200000 must win over a
# user-message paste, a tool-result echo of DESIGN.md, and assistant prose
# that quotes playbook-window: 1000000 mid-sentence. The old unanchored
# grep|tail returned 1000000 here; the role-anchored parser must return
# 200000.
D="$root/tests/hooks/fixtures/transcript-window-decoy.jsonl"
dwin="$(playbook_declared_window "$(printf '{"transcript_path":"%s"}' "$D")")"
[ "$dwin" = "200000" ] \
  && echo "PASS: decoy ignored, real assistant declaration wins" \
  || { echo "FAIL: decoy window was [$dwin], expected 200000"; exit 1; }

# Undeclared window: usage exists but no declaration. Window empty, percent
# empty (silent degradation, never a wrong value). The take-a-beat
# self-healing notice path keys off exactly this state.
NW="$root/tests/hooks/fixtures/transcript-no-window.jsonl"
stdin_nw="$(printf '{"transcript_path":"%s"}' "$NW")"
nwin="$(playbook_declared_window "$stdin_nw")"
nused="$(playbook_context_used "$stdin_nw")"
npct="$(playbook_context_percent "$stdin_nw")"
{ [ -z "$nwin" ] && [ -n "$nused" ] && [ -z "$npct" ]; } \
  && echo "PASS: undeclared window is empty/empty-percent with usage present" \
  || { echo "FAIL: nwin=[$nwin] nused=[$nused] npct=[$npct]"; exit 1; }

pct="$(playbook_context_percent "$stdin_t")"
[ "$pct" = "70" ] && echo "PASS: percent = round(100*used/window)" \
  || { echo "FAIL: percent was [$pct], expected 70"; exit 1; }

missing="$(playbook_context_percent '{"transcript_path":"/no/such/file"}')"
[ -z "$missing" ] && echo "PASS: silent empty on missing transcript" \
  || { echo "FAIL: expected empty, got [$missing]"; exit 1; }

# Project North Star recovery and the subagent-aware anchor block.
SB="$root/tests/hooks/fixtures/transcript-subagent-beat.jsonl"
ns="$(playbook_project_northstar "$(printf '{"transcript_path":"%s"}' "$SB")")"
[ "$ns" = "Ship a zero-dependency context anchor that survives compaction without writing to the user tree." ] \
  && echo "PASS: project North Star recovered from dispatch line" \
  || { echo "FAIL: northstar was [$ns]"; exit 1; }
[ -z "$(playbook_project_northstar "$stdin_b")" ] \
  && echo "PASS: no North Star on the main thread (none injected)" \
  || { echo "FAIL: main thread reported a North Star"; exit 1; }

main_ab="$(playbook_anchor_block "$stdin_b")"
case "$main_ab" in
  "Original request, verbatim:"*"Build me a widget that does X."*) echo "PASS: main-thread anchor labelled original request" ;;
  *) echo "FAIL: main anchor was [$main_ab]"; exit 1 ;;
esac
sub_ab="$(playbook_anchor_block "$(printf '{"transcript_path":"%s","agent_id":"a1"}' "$SB")")"
{ grep -q "Overall goal (what success means for the whole project):" <<<"$sub_ab" \
  && grep -q "Your part of it, verbatim:" <<<"$sub_ab" \
  && ! grep -q "Original request, verbatim:" <<<"$sub_ab" \
  && ! grep -q "^playbook-northstar:" <<<"$sub_ab"; } \
  && echo "PASS: subagent anchor relabelled, North Star primary, task de-duped" \
  || { echo "FAIL: subagent anchor was [$sub_ab]"; exit 1; }
nons_ab="$(playbook_anchor_block "$(printf '{"transcript_path":"%s","agent_id":"a1"}' "$T")")"
{ grep -q "Your assigned task, verbatim:" <<<"$nons_ab" \
  && grep -q "No project North Star was provided" <<<"$nons_ab"; } \
  && echo "PASS: subagent without North Star gets honest task label + raise-unease" \
  || { echo "FAIL: no-NS subagent anchor was [$nons_ab]"; exit 1; }

removed=0
for fn in playbook_dir playbook_anchor playbook_ledger playbook_ensure_dir \
          playbook_anchor_init playbook_ledger_append playbook_anchor_read \
          playbook_emit_stop_nudge; do
  if declare -F "$fn" >/dev/null 2>&1; then echo "FAIL: $fn still defined"; removed=1; fi
done
[ "$removed" -eq 0 ] && echo "PASS: rejected file and Stop-channel helpers removed" || exit 1
