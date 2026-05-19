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

pct="$(playbook_context_percent "$stdin_t")"
[ "$pct" = "70" ] && echo "PASS: percent = round(100*used/window)" \
  || { echo "FAIL: percent was [$pct], expected 70"; exit 1; }

missing="$(playbook_context_percent '{"transcript_path":"/no/such/file"}')"
[ -z "$missing" ] && echo "PASS: silent empty on missing transcript" \
  || { echo "FAIL: expected empty, got [$missing]"; exit 1; }

removed=0
for fn in playbook_dir playbook_anchor playbook_ledger playbook_ensure_dir \
          playbook_anchor_init playbook_ledger_append playbook_anchor_read \
          playbook_emit_stop_nudge; do
  if declare -F "$fn" >/dev/null 2>&1; then echo "FAIL: $fn still defined"; removed=1; fi
done
[ "$removed" -eq 0 ] && echo "PASS: rejected file and Stop-channel helpers removed" || exit 1
