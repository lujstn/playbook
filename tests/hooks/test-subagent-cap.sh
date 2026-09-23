#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
H="$root/hooks/take-a-beat"
export CLAUDE_PLUGIN_ROOT="$root"
unset CURSOR_PLUGIN_ROOT COPILOT_CLI 2>/dev/null || true
source "$root/hooks/lib/playbook-common.sh"
R="$root/tests/hooks/fixtures/transcript-cap-refused.jsonl"
P="$root/tests/hooks/fixtures/transcript-cap-prose.jsonl"

iso() { export PLAYBOOK_STATE_DIR="$(mktemp -d)"; }
sd()  { playbook_state_dir "{\"session_id\":\"$1\"}"; }
beat() { printf '{"hook_event_name":"PostToolBatch","session_id":"%s","transcript_path":"%s"}' "$1" "$2" | bash "$H"; }

iso
d="$(sd cap)"; playbook_state_reset "$d" 0
out="$(beat cap "$R")"
{ grep -q "Playbook subagent cap" <<<"$out" \
  && grep -q "per-process counter" <<<"$out" \
  && grep -q "/rename" <<<"$out" \
  && grep -q "claude -r" <<<"$out" \
  && grep -q "new terminal window" <<<"$out"; } \
  && echo "PASS: interactive refusal tells the user to rename and reopen with claude -r" \
  || { echo "FAIL: interactive guidance missing: [$out]"; exit 1; }
grep -q "nothing is lost" <<<"$out" \
  && echo "PASS: interactive notice reassures that no work needs redoing" \
  || { echo "FAIL: reassurance missing: [$out]"; exit 1; }
grep -qi "do not quietly fall back" <<<"$out" \
  && echo "PASS: interactive notice forbids a silent solo fallback" \
  || { echo "FAIL: solo-fallback ban missing: [$out]"; exit 1; }
rm -rf "$PLAYBOOK_STATE_DIR"

iso
d="$(sd once)"; playbook_state_reset "$d" 0
first="$(beat once "$R")"
[ -n "$first" ] || { echo "FAIL: first batch emitted nothing"; exit 1; }
second="$(beat once "$R")"
! grep -q "Playbook subagent cap" <<<"$second" \
  && echo "PASS: the cap notice is one-shot, not repeated while the refusal sits in the tail" \
  || { echo "FAIL: cap notice repeated: [$second]"; exit 1; }
rm -rf "$PLAYBOOK_STATE_DIR"

iso
d="$(sd off)"; playbook_state_reset "$d" 0; : > "${d}/offline"
out="$(beat off "$R")"
{ grep -q "Playbook subagent cap" <<<"$out" \
  && grep -q "keep going" <<<"$out" \
  && grep -q "Workflow tool draws on a separate pool" <<<"$out"; } \
  && echo "PASS: offline refusal keeps going and routes through the separate Workflow pool" \
  || { echo "FAIL: offline guidance missing: [$out]"; exit 1; }
{ ! grep -q "/rename" <<<"$out" && ! grep -qi "Stop here" <<<"$out"; } \
  && echo "PASS: an offline run is never told to stop and wait for the user" \
  || { echo "FAIL: offline run told to stop: [$out]"; exit 1; }
rm -rf "$PLAYBOOK_STATE_DIR"

iso
d="$(sd prose)"; playbook_state_reset "$d" 0
out="$(beat prose "$P")"
! grep -q "Playbook subagent cap" <<<"$out" \
  && echo "PASS: assistant prose and a non-error tool result naming the refusal do not trip the cap notice" \
  || { echo "FAIL: false positive on prose: [$out]"; exit 1; }
rm -rf "$PLAYBOOK_STATE_DIR"

iso
d="$(sd nofile)"; playbook_state_reset "$d" 0
out="$(printf '{"hook_event_name":"PostToolBatch","session_id":"nofile","transcript_path":"/no/such.jsonl"}' | bash "$H")"
! grep -q "Playbook subagent cap" <<<"$out" \
  && echo "PASS: a missing transcript degrades to silence, never a spurious cap notice" \
  || { echo "FAIL: cap notice without evidence: [$out]"; exit 1; }
rm -rf "$PLAYBOOK_STATE_DIR"
