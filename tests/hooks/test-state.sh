#!/usr/bin/env bash
# Throttle-state lifecycle for take-a-beat. Every case runs against an isolated
# PLAYBOOK_STATE_DIR so nothing leaks between cases or into the real state root.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
H="$root/hooks/take-a-beat"
SS="$root/hooks/session-start"
export CLAUDE_PLUGIN_ROOT="$root"
unset CURSOR_PLUGIN_ROOT COPILOT_CLI 2>/dev/null || true
# Isolate the global marker dir so the first-run doorbell never touches real HOME.
GLOBAL_TMP="$(mktemp -d)"; export PLAYBOOK_GLOBAL_DIR="$GLOBAL_TMP"
trap 'rm -rf "$GLOBAL_TMP"' EXIT
source "$root/hooks/lib/playbook-common.sh"

B="$root/tests/hooks/fixtures/transcript-basic.jsonl"          # used 10020
T="$root/tests/hooks/fixtures/transcript-beat.jsonl"           # used 700020
AC="$root/tests/hooks/fixtures/transcript-assumed-calm.jsonl"  # used 170000

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; exit 1; }
sd()   { playbook_state_dir "{\"session_id\":\"$1\"}"; }        # state dir for a session id

# --- 1. State lifecycle at SessionStart -------------------------------------
export PLAYBOOK_STATE_DIR="$(mktemp -d)"
printf '{"hook_event_name":"SessionStart","source":"startup","session_id":"life","transcript_path":"%s"}' "$B" | bash "$H" >/dev/null
d="$(sd life)"
[ -f "$d/state" ] || fail "SessionStart did not create a state file"
[ "$(playbook_state_int "$d" last_anchor_used 999)" = "10020" ] || fail "baseline not seeded to current usage at SessionStart"
[ "$(playbook_state_int "$d" calm_fired 9)" = "0" ] || fail "calm_fired not zeroed at SessionStart"
[ "$(playbook_state_int "$d" fail_snapshot 9)" = "0" ] || fail "fail_snapshot not zeroed at SessionStart"
pass "SessionStart seeds the state lifecycle (baseline=used, calm/snapshot zeroed)"
rm -rf "$PLAYBOOK_STATE_DIR"

# --- 2. Pulse fires at delta then throttles ---------------------------------
export PLAYBOOK_STATE_DIR="$(mktemp -d)"
d="$(sd pulse)"; playbook_state_reset "$d" 600000
out="$(printf '{"hook_event_name":"PostToolBatch","session_id":"pulse","transcript_path":"%s"}' "$T" | PLAYBOOK_WINDOW=1000000 bash "$H")"
grep -q "Playbook pulse" <<<"$out" || fail "pulse did not fire once the delta exceeded the threshold"
out="$(printf '{"hook_event_name":"PostToolBatch","session_id":"pulse","transcript_path":"%s"}' "$T" | PLAYBOOK_WINDOW=1000000 bash "$H")"
[ -z "$out" ] || fail "pulse repeated instead of throttling: [$out]"
pass "pulse fires once at the token delta then throttles"
rm -rf "$PLAYBOOK_STATE_DIR"

# --- 3. Spike at 3 failures (first two silent, consumed, fourth silent) ------
export PLAYBOOK_STATE_DIR="$(mktemp -d)"
d="$(sd spike)"; playbook_state_reset "$d" 0
for i in 1 2; do
  out="$(printf '{"hook_event_name":"PostToolUseFailure","session_id":"spike","transcript_path":"%s"}' "$T" | bash "$H")"
  [ -z "$out" ] || fail "failure $i fired before the threshold: [$out]"
done
[ "$(playbook_fail_count "$d")" = "2" ] || fail "failures not counted (expected 2)"
out="$(printf '{"hook_event_name":"PostToolUseFailure","session_id":"spike","transcript_path":"%s"}' "$T" | bash "$H")"
grep -q "Playbook unease spike" <<<"$out" || fail "spike did not fire at the third failure"
[ "$(playbook_fail_count "$d")" = "0" ] || fail "failures not consumed after the spike"
out="$(printf '{"hook_event_name":"PostToolUseFailure","session_id":"spike","transcript_path":"%s"}' "$T" | bash "$H")"
[ -z "$out" ] || fail "fourth failure fired a spike: failures should have been consumed"
pass "spike at 3 failures: first two silent, failures consumed, fourth silent"
rm -rf "$PLAYBOOK_STATE_DIR"

# --- 4. Clean-batch reset breaks the streak ---------------------------------
export PLAYBOOK_STATE_DIR="$(mktemp -d)"
d="$(sd clean)"; playbook_state_reset "$d" 100
printf '{"hook_event_name":"PostToolUseFailure","session_id":"clean","transcript_path":"%s"}' "$T" | bash "$H" >/dev/null
printf '{"hook_event_name":"PostToolUseFailure","session_id":"clean","transcript_path":"%s"}' "$T" | bash "$H" >/dev/null
printf '{"hook_event_name":"PostToolBatch","session_id":"clean","transcript_path":"%s"}' "$B" | bash "$H" >/dev/null
[ "$(playbook_state_int "$d" fail_snapshot 9)" = "2" ] || fail "first batch did not record the failure snapshot"
printf '{"hook_event_name":"PostToolBatch","session_id":"clean","transcript_path":"%s"}' "$B" | bash "$H" >/dev/null
[ "$(playbook_fail_count "$d")" = "0" ] || fail "a clean batch did not truncate the failures file"
[ "$(playbook_state_int "$d" fail_snapshot 9)" = "0" ] || fail "a clean batch did not zero the snapshot"
out="$(printf '{"hook_event_name":"PostToolUseFailure","session_id":"clean","transcript_path":"%s"}' "$T" | bash "$H")"
[ -z "$out" ] || fail "streak not broken: one failure after a clean batch fired a spike"
pass "a clean batch between failures breaks the streak"
rm -rf "$PLAYBOOK_STATE_DIR"

# --- 5. Compact reset (seed 622000 -> 0, next small batch pulse-silent) ------
export PLAYBOOK_STATE_DIR="$(mktemp -d)"
d="$(sd compact)"; playbook_state_reset "$d" 622000
printf '{"hook_event_name":"SessionStart","source":"compact","session_id":"compact","transcript_path":"%s"}' "$B" | bash "$H" >/dev/null
[ "$(playbook_state_int "$d" last_anchor_used 9)" = "0" ] || fail "compact SessionStart did not reset the baseline to 0"
out="$(printf '{"hook_event_name":"PostToolBatch","session_id":"compact","transcript_path":"%s"}' "$B" | bash "$H")"
[ -z "$out" ] || fail "the first small post-compact batch was not pulse-silent: [$out]"
pass "compact resets the baseline to 0; the first small post-compact batch is pulse-silent"
rm -rf "$PLAYBOOK_STATE_DIR"

# --- 6. Silence on unwired events, both hooks -------------------------------
export PLAYBOOK_STATE_DIR="$(mktemp -d)"
for ev in Stop SubagentStop PostToolUse PreCompact; do
  for hook in "$H" "$SS"; do
    if out="$(printf '{"hook_event_name":"%s","session_id":"unwired","transcript_path":"%s"}' "$ev" "$T" | bash "$hook" 2>/dev/null)"; then :; else
      fail "$ev on $(basename "$hook") exited non-zero"; fi
    [ -z "$out" ] || fail "$ev on $(basename "$hook") produced output: [$out]"
  done
done
pass "unwired events (Stop/SubagentStop/PostToolUse/PreCompact) stay silent and exit 0 on both hooks"
rm -rf "$PLAYBOOK_STATE_DIR"

# --- 7. Corrupt state self-heals silently -----------------------------------
export PLAYBOOK_STATE_DIR="$(mktemp -d)"
d="$(sd corrupt)"; mkdir -p "$d"
printf 'v=1\nlast_anchor_used=NOTANUMBER\ncalm_fired=0\nfail_snapshot=0\n' > "$d/state"
out="$(printf '{"hook_event_name":"PostToolBatch","session_id":"corrupt","transcript_path":"%s"}' "$T" | PLAYBOOK_WINDOW=1000000 bash "$H")"
[ -z "$out" ] || fail "corrupt state did not heal silently: [$out]"
[ "$(playbook_state_int "$d" last_anchor_used 9)" = "700020" ] || fail "corrupt heal did not rebaseline to current usage (bias to silence)"
pass "corrupt state self-heals silently and rebaselines to current usage"
rm -rf "$PLAYBOOK_STATE_DIR"

# --- 8. Main / subagent state isolation via agent_id ------------------------
export PLAYBOOK_STATE_DIR="$(mktemp -d)"
printf '{"hook_event_name":"PostToolUseFailure","session_id":"iso","transcript_path":"%s"}' "$T" | bash "$H" >/dev/null
printf '{"hook_event_name":"PostToolUseFailure","session_id":"iso","agent_id":"helperA","transcript_path":"%s"}' "$T" | bash "$H" >/dev/null
dm="$(sd iso)"
da="$(playbook_state_dir '{"session_id":"iso","agent_id":"helperA"}')"
[ "$dm" != "$da" ] || fail "main and subagent resolved to the same state dir"
[ "$(playbook_fail_count "$dm")" = "1" ] || fail "main failure count wrong (expected 1)"
[ "$(playbook_fail_count "$da")" = "1" ] || fail "subagent failure count wrong (expected 1)"
pass "main and subagent throttle state are isolated by agent_id"
rm -rf "$PLAYBOOK_STATE_DIR"

# --- 9. Ratchet proves the window on usage over 200k ------------------------
export PLAYBOOK_STATE_DIR="$(mktemp -d)"
d="$(sd ratchet)"; playbook_state_reset "$d" 700020
printf '{"hook_event_name":"PostToolBatch","session_id":"ratchet","transcript_path":"%s"}' "$T" | bash "$H" >/dev/null
[ "$(playbook_state_get "$d" window_proven)" = "1000000" ] || fail "ratchet did not write window_proven on usage over 200000"
pass "ratchet writes window_proven=1000000 once usage exceeds 200000"
rm -rf "$PLAYBOOK_STATE_DIR"

# --- 10. Negative-delta self-heal -------------------------------------------
export PLAYBOOK_STATE_DIR="$(mktemp -d)"
d="$(sd neg)"; playbook_state_reset "$d" 500000
out="$(printf '{"hook_event_name":"PostToolBatch","session_id":"neg","transcript_path":"%s"}' "$B" | bash "$H")"
[ -z "$out" ] || fail "a usage figure below the baseline was not silent: [$out]"
[ "$(playbook_state_int "$d" last_anchor_used 9)" = "10020" ] || fail "negative delta did not rebaseline to current usage"
pass "negative delta (a silent compaction) self-heals silently and rebaselines"
rm -rf "$PLAYBOOK_STATE_DIR"

echo "test-state.sh: all cases passed"
