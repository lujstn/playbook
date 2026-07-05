#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
H="$root/hooks/take-a-beat"
export CLAUDE_PLUGIN_ROOT="$root"
unset CURSOR_PLUGIN_ROOT COPILOT_CLI 2>/dev/null || true
source "$root/hooks/lib/playbook-common.sh"
B="$root/tests/hooks/fixtures/transcript-basic.jsonl"          # used 10020
T="$root/tests/hooks/fixtures/transcript-beat.jsonl"           # used 700020
AC="$root/tests/hooks/fixtures/transcript-assumed-calm.jsonl"  # used 170000
SB="$root/tests/hooks/fixtures/transcript-subagent-beat.jsonl" # used 700020

# Each case gets its own state root so throttle state never leaks between cases.
iso() { export PLAYBOOK_STATE_DIR="$(mktemp -d)"; }
sd()  { playbook_state_dir "{\"session_id\":\"$1\"}"; }

# PreCompact is a dead seam: additionalContext is never injected, so take-a-beat must be silent.
iso
out="$(printf '{"hook_event_name":"PreCompact","session_id":"pc","transcript_path":"%s"}' "$B" | bash "$H")"
[ -z "$out" ] && echo "PASS: PreCompact is silent (dead seam, no output)" || { echo "FAIL: PreCompact produced output: [$out]"; exit 1; }
rm -rf "$PLAYBOOK_STATE_DIR"

# PostToolUse is no longer wired to take-a-beat: it must be silent.
iso
out="$(printf '{"hook_event_name":"PostToolUse","session_id":"ptu","transcript_path":"%s"}' "$T" | PLAYBOOK_WINDOW=1000000 bash "$H")"
[ -z "$out" ] && echo "PASS: PostToolUse is now silent (unwired)" || { echo "FAIL: PostToolUse produced output: [$out]"; exit 1; }
rm -rf "$PLAYBOOK_STATE_DIR"

# Post-compaction re-anchor: SessionStart with source=compact is the real seam,
# and the window-declaration sentence is gone.
iso
out="$(printf '{"hook_event_name":"SessionStart","source":"compact","session_id":"cp","transcript_path":"%s"}' "$B" | bash "$H")"
grep -q "Build me a widget that does X. Original request text." <<<"$out" \
  && ! grep -qi "Re-state your context window" <<<"$out" \
  && echo "PASS: SessionStart/compact recovers original request, no window sentence" || { echo "FAIL reanchor: [$out]"; exit 1; }
rm -rf "$PLAYBOOK_STATE_DIR"

# Below threshold on a seeded state: silent (basic fixture is ~5% of the assumed 200k window).
iso
d="$(sd low)"; playbook_state_reset "$d" 10020
out="$(printf '{"hook_event_name":"PostToolBatch","session_id":"low","transcript_path":"%s"}' "$B" | bash "$H")"
[ -z "$out" ] && echo "PASS: no beat under threshold" || { echo "FAIL spurious: [$out]"; exit 1; }
rm -rf "$PLAYBOOK_STATE_DIR"

# Main-thread calm beat on PostToolBatch with a proven (env) window: calm wording,
# anchor re-injected labelled as original request. Baseline seeded equal to usage
# so only the calm branch (not the pulse) can fire.
iso
d="$(sd calm)"; playbook_state_reset "$d" 700020
out="$(printf '{"hook_event_name":"PostToolBatch","session_id":"calm","transcript_path":"%s"}' "$T" | PLAYBOOK_WINDOW=1000000 PLAYBOOK_CALM_PCT=70 bash "$H")"
{ grep -qi "auto-compact is seamless" <<<"$out" \
  && grep -q "about 70 percent of your 1000000-token window" <<<"$out" \
  && grep -q "Original request, verbatim:" <<<"$out" \
  && ! grep -q "Overall goal" <<<"$out"; } \
  && echo "PASS: main-thread calm beat on PostToolBatch, proven window, original-request label" \
  || { echo "FAIL nobeat/mislabel: [$out]"; exit 1; }
# Second consecutive batch shares the state dir: calm is throttled, so silent.
out2="$(printf '{"hook_event_name":"PostToolBatch","session_id":"calm","transcript_path":"%s"}' "$T" | PLAYBOOK_WINDOW=1000000 PLAYBOOK_CALM_PCT=70 bash "$H")"
[ -z "$out2" ] && echo "PASS: calm beat not repeated on the next batch (state throttle)" \
  || { echo "FAIL throttle: beat repeated [$out2]"; exit 1; }
rm -rf "$PLAYBOOK_STATE_DIR"

# Assumed-window calm: no env, usage under 200k, so the wording states tokens used
# and never asserts a percentage against a window it cannot prove.
iso
d="$(sd assumed)"; playbook_state_reset "$d" 170000
out="$(printf '{"hook_event_name":"PostToolBatch","session_id":"assumed","transcript_path":"%s"}' "$AC" | bash "$H")"
{ grep -q "standard 200000-token window" <<<"$out" \
  && grep -q "about 170000 tokens are in use" <<<"$out" \
  && ! grep -qE '[0-9]+ percent' <<<"$out"; } \
  && echo "PASS: assumed-window calm states tokens, no borrowed percentage" \
  || { echo "FAIL assumed calm: [$out]"; exit 1; }
rm -rf "$PLAYBOOK_STATE_DIR"

# Subagent calm beat: North Star primary, task relabelled, no "Original request, verbatim:".
iso
da="$(playbook_state_dir '{"session_id":"sub","agent_id":"a1"}')"; playbook_state_reset "$da" 700020
out="$(printf '{"hook_event_name":"PostToolBatch","session_id":"sub","agent_id":"a1","transcript_path":"%s"}' "$SB" | PLAYBOOK_WINDOW=1000000 PLAYBOOK_CALM_PCT=70 bash "$H")"
{ grep -qi "auto-compact is seamless" <<<"$out" \
  && grep -q "Overall goal (what success means for the whole project):" <<<"$out" \
  && grep -q "Ship a zero-dependency context anchor" <<<"$out" \
  && grep -q "Your part of it, verbatim:" <<<"$out" \
  && ! grep -q "Original request, verbatim:" <<<"$out"; } \
  && echo "PASS: subagent calm beat with North Star primacy and task label" \
  || { echo "FAIL subagent beat: [$out]"; exit 1; }
rm -rf "$PLAYBOOK_STATE_DIR"

# SessionStart startup: competing hook detected, no context-calm marker -> OFFER fires once.
iso
csl_home="$(mktemp -d)"
csl_proj="$(mktemp -d)"
mkdir -p "$csl_home/.claude" "$csl_proj/.claude/playbook"
printf '{"hooks":{"PostToolUse":[{"hooks":[{"command":"gsd-context-monitor"}]}]}}' \
  > "$csl_home/.claude/settings.json"
out="$(HOME="$csl_home" printf '{"hook_event_name":"SessionStart","source":"startup","session_id":"off","cwd":"%s"}' "$csl_proj" \
  | HOME="$csl_home" bash "$H")"
grep -q "context-calm offer" <<<"$out" \
  && echo "PASS: context-calm offer fires when competing hook detected" \
  || { echo "FAIL: competing hook offer missing in [$out]"; rm -rf "$csl_home" "$csl_proj" "$PLAYBOOK_STATE_DIR"; exit 1; }

# SessionStart startup: context-calm marker present -> offer is SILENT.
printf 'owned\n' > "$csl_proj/.claude/playbook/context-calm"
out2="$(HOME="$csl_home" printf '{"hook_event_name":"SessionStart","source":"startup","session_id":"off","cwd":"%s"}' "$csl_proj" \
  | HOME="$csl_home" bash "$H")"
[ -z "$out2" ] \
  && echo "PASS: offer silent when context-calm marker exists" \
  || { echo "FAIL: offer repeated despite marker [$out2]"; rm -rf "$csl_home" "$csl_proj" "$PLAYBOOK_STATE_DIR"; exit 1; }
rm -rf "$csl_home" "$csl_proj" "$PLAYBOOK_STATE_DIR"

# First-run doorbell: fires once per machine, then never; a setup marker suppresses it.
iso
nh="$(mktemp -d)"; gd="$(mktemp -d)"
out="$(HOME="$nh" PLAYBOOK_GLOBAL_DIR="$gd" printf '{"hook_event_name":"SessionStart","source":"startup","session_id":"nudge1"}' \
  | HOME="$nh" PLAYBOOK_GLOBAL_DIR="$gd" bash "$H")"
{ grep -q "type /playbook:hello" <<<"$out" && [ -f "$gd/setup-nudged" ]; } \
  && echo "PASS: first-run doorbell fires and writes its once-ever marker" \
  || { echo "FAIL doorbell: [$out]"; rm -rf "$nh" "$gd" "$PLAYBOOK_STATE_DIR"; exit 1; }
out2="$(HOME="$nh" PLAYBOOK_GLOBAL_DIR="$gd" printf '{"hook_event_name":"SessionStart","source":"startup","session_id":"nudge1"}' \
  | HOME="$nh" PLAYBOOK_GLOBAL_DIR="$gd" bash "$H")"
[ -z "$out2" ] && echo "PASS: doorbell never repeats once nudged" \
  || { echo "FAIL doorbell repeated: [$out2]"; rm -rf "$nh" "$gd" "$PLAYBOOK_STATE_DIR"; exit 1; }
gd2="$(mktemp -d)"; printf 'checked=2026-07-05\nplugins=a@b\n' > "$gd2/setup"
out3="$(HOME="$nh" PLAYBOOK_GLOBAL_DIR="$gd2" printf '{"hook_event_name":"SessionStart","source":"startup","session_id":"nudge2"}' \
  | HOME="$nh" PLAYBOOK_GLOBAL_DIR="$gd2" bash "$H")"
[ -z "$out3" ] && echo "PASS: doorbell silent when setup has already run" \
  || { echo "FAIL doorbell despite setup marker: [$out3]"; rm -rf "$nh" "$gd" "$gd2" "$PLAYBOOK_STATE_DIR"; exit 1; }
rm -rf "$nh" "$gd" "$gd2" "$PLAYBOOK_STATE_DIR"

# Unrelated event: silent.
iso
out="$(printf '{"hook_event_name":"Stop","session_id":"st","transcript_path":"%s"}' "$B" | bash "$H")"
[ -z "$out" ] && echo "PASS: silent on non-handled events" || { echo FAIL stop; exit 1; }
rm -rf "$PLAYBOOK_STATE_DIR"

# Malformed or empty stdin: silent, no abort, exit 0.
iso
for bad in '' 'not json' '{"hook_event_name":"PostToolBatch"'; do
  if mo="$(printf '%s' "$bad" | bash "$H" 2>/dev/null)"; then :; else
    echo "FAIL: stdin [$bad] aborted take-a-beat"; exit 1; fi
  [ -z "$mo" ] || { echo "FAIL: stdin [$bad] was not silent: [$mo]"; exit 1; }
done
echo "PASS: malformed or empty stdin is silent, no abort"
rm -rf "$PLAYBOOK_STATE_DIR"

# Never creates a file in the project working tree.
iso
d="$(mktemp -d)"
printf '{"hook_event_name":"PostToolBatch","session_id":"nofile","cwd":"%s","transcript_path":"%s"}' "$d" "$T" | bash "$H" >/dev/null 2>&1 || true
[ ! -e "$d/.playbook" ] && echo "PASS: no file written into the project" || { rm -rf "$d" "$PLAYBOOK_STATE_DIR"; echo FAIL wrotefile; exit 1; }
rm -rf "$d" "$PLAYBOOK_STATE_DIR"
