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

# Window inference: env override wins; the ratcheted state window is sticky; the
# assumed 200000 is the default; an invalid env value falls through; provenance
# is proven for env/ratchet and assumed for the default.
ws="$(mktemp -d)"
[ "$(PLAYBOOK_WINDOW=1000000 playbook_window "$ws")" = "1000000" ] \
  && echo "PASS: playbook_window env override wins" || { echo "FAIL: env window"; exit 1; }
[ "$(PLAYBOOK_WINDOW=1000000 playbook_window_provenance "$ws")" = "proven" ] \
  && echo "PASS: env window provenance is proven" || { echo "FAIL: env provenance"; exit 1; }
[ "$(playbook_window "$ws")" = "200000" ] \
  && echo "PASS: playbook_window defaults to the assumed 200000" || { echo "FAIL: default window"; exit 1; }
[ "$(playbook_window_provenance "$ws")" = "assumed" ] \
  && echo "PASS: default window provenance is assumed" || { echo "FAIL: default provenance"; exit 1; }
[ "$(PLAYBOOK_WINDOW=notanumber playbook_window "$ws")" = "200000" ] \
  && echo "PASS: invalid env window falls through to the default" || { echo "FAIL: invalid env"; exit 1; }
printf 'v=1\nwindow_proven=1000000\n' > "$ws/state"
[ "$(playbook_window "$ws")" = "1000000" ] \
  && echo "PASS: playbook_window is sticky from a proven state" || { echo "FAIL: sticky window"; exit 1; }
[ "$(playbook_window_provenance "$ws")" = "proven" ] \
  && echo "PASS: ratcheted state window provenance is proven" || { echo "FAIL: sticky provenance"; exit 1; }
rm -rf "$ws"

# The single beat formula: round(100 * used / window).
pct="$(playbook_percent 700020 1000000)"
[ "$pct" = "70" ] && echo "PASS: playbook_percent = round(100*used/window)" \
  || { echo "FAIL: percent was [$pct], expected 70"; exit 1; }

missing="$(playbook_context_used '{"transcript_path":"/no/such/file"}')"
[ -z "$missing" ] && echo "PASS: silent empty usage on missing transcript" \
  || { echo "FAIL: expected empty, got [$missing]"; exit 1; }

# Bounded reads: a filler record over 300KB must not stop the tail read from
# finding the final usage record, nor the head read from finding the first user
# record.
big="$(mktemp).jsonl"
printf '{"type":"user","message":{"role":"user","content":"the bounded-read first ask"}}\n' > "$big"
filler="$(head -c 350000 /dev/zero | tr '\0' 'z')"
printf '{"type":"system","subtype":"noise","content":"%s"}\n' "$filler" >> "$big"
printf '{"type":"assistant","message":{"role":"assistant","usage":{"input_tokens":100,"cache_creation_input_tokens":2000,"cache_read_input_tokens":50000,"output_tokens":5},"content":[{"type":"text","text":"done"}]}}\n' >> "$big"
bstdin="$(printf '{"transcript_path":"%s"}' "$big")"
bu="$(playbook_context_used "$bstdin")"
[ "$bu" = "52100" ] && echo "PASS: bounded read finds the final usage record past a 300KB filler" \
  || { echo "FAIL bounded used: [$bu]"; rm -f "$big"; exit 1; }
bo="$(playbook_original_request "$bstdin")"
[ "$bo" = "the bounded-read first ask" ] && echo "PASS: bounded read finds the first user record past a 300KB filler" \
  || { echo "FAIL bounded orig: [$bo]"; rm -f "$big"; exit 1; }
rm -f "$big"

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
# A subagent anchor carries the North Star and nothing else. At SubagentStart the
# transcript can only be the dispatching session's, so its first user record is the
# PARENT's request, not this helper's dispatch prompt: quoting it as the helper's
# task hands over a confidently-worded wrong job.
sub_ab="$(playbook_anchor_block "$(printf '{"transcript_path":"%s","agent_id":"a1"}' "$SB")")"
{ grep -q "Overall goal (what success means for the whole project):" <<<"$sub_ab" \
  && grep -q "It does NOT state your task" <<<"$sub_ab" \
  && ! grep -q "verbatim:" <<<"$sub_ab" \
  && ! grep -q "Wave 2 Task 3" <<<"$sub_ab" \
  && ! grep -q "^playbook-northstar:" <<<"$sub_ab"; } \
  && echo "PASS: subagent anchor carries the North Star only, never a quoted task" \
  || { echo "FAIL: subagent anchor was [$sub_ab]"; exit 1; }
nons_ab="$(playbook_anchor_block "$(printf '{"transcript_path":"%s","agent_id":"a1"}' "$T")")"
[ -z "$nons_ab" ] \
  && echo "PASS: subagent with no North Star gets an empty anchor, never a guessed task" \
  || { echo "FAIL: no-NS subagent anchor should be empty, was [$nons_ab]"; exit 1; }

removed=0
for fn in playbook_dir playbook_anchor playbook_ledger playbook_ensure_dir \
          playbook_anchor_init playbook_ledger_append playbook_anchor_read \
          playbook_emit_stop_nudge playbook_declared_window playbook_context_percent; do
  if declare -F "$fn" >/dev/null 2>&1; then echo "FAIL: $fn still defined"; removed=1; fi
done
[ "$removed" -eq 0 ] && echo "PASS: rejected file, Stop-channel, and declared-window helpers removed" || exit 1
