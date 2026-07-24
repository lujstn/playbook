#!/usr/bin/env bash
# The PreToolUse edit recorder and the churn detector it feeds. Every case runs
# against an isolated PLAYBOOK_STATE_DIR.
set -uo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
H="$root/hooks/edit-log"
TB="$root/hooks/take-a-beat"
export CLAUDE_PLUGIN_ROOT="$root"
unset CURSOR_PLUGIN_ROOT COPILOT_CLI 2>/dev/null || true
source "$root/hooks/lib/playbook-common.sh"

GLOBAL_TMP="$(mktemp -d)"; export PLAYBOOK_GLOBAL_DIR="$GLOBAL_TMP"
printf 'checked=2026-07-24\nplugins=none\n' > "$GLOBAL_TMP/setup"
SANDBOX=""
trap 'rm -rf "$GLOBAL_TMP" "$SANDBOX"' EXIT

B="$root/tests/hooks/fixtures/transcript-basic.jsonl"   # quiet: no marker, bash_fail=0
CHURN_SENTENCE="the same file has been rewritten several times in quick succession"

fail=0
pass()  { echo "PASS: $1"; }
flunk() { echo "FAIL: $1"; fail=1; }
eq()    { if [ "$2" = "$3" ]; then pass "$1"; else flunk "$1 (expected [$2], got [$3])"; fi }
has()   { if grep -qF -- "$2" <<<"$CTX"; then pass "$1"; else flunk "$1"; fi }

iso() {
  if [ -n "$SANDBOX" ]; then rm -rf "$SANDBOX"; fi
  SANDBOX="$(mktemp -d)"; export PLAYBOOK_STATE_DIR="$SANDBOX"
}
sd() { playbook_state_dir "{\"session_id\":\"$1\"}"; }
st() { playbook_state_get "$1" "$2"; }

# Record one PreToolUse payload; OUT is stdout, ERR is stderr, RC the exit code.
log_edit() {  # session, tool, path
  OUT="$(jq -cn --arg t "$2" --arg p "$3" --arg s "$1" \
          '{hook_event_name:"PreToolUse", session_id:$s, tool_name:$t, tool_input:{file_path:$p}}' \
        | bash "$H" 2>"$SANDBOX/err")"
  RC=$?
  ERR="$(cat "$SANDBOX/err" 2>/dev/null)"
}
edits_of() { d="$(sd "$1")"; printf '%s' "$d/edits"; }
count_lines() { if [ -f "$1" ]; then wc -l < "$1" | tr -d ' '; else printf '0'; fi }

# --- 1. Edit and Write are both recorded -------------------------------------
iso
log_edit rec Edit /p/one.ts
eq "an Edit exits 0" "0" "$RC"
eq "an Edit prints nothing on stdout" "" "$OUT"
eq "an Edit prints nothing on stderr" "" "$ERR"
log_edit rec Write /p/two.ts
ef="$(edits_of rec)"
eq "both an Edit and a Write are recorded" "2" "$(count_lines "$ef")"
eq "the recorded path is the file path" "/p/one.ts" "$(head -n1 "$ef")"

# --- 2. Other tools and empty paths are ignored ------------------------------
iso
log_edit skip Read /p/three.ts
log_edit skip Bash /p/four.ts
log_edit skip Edit ""
eq "a non-editing tool records nothing" "0" "$(count_lines "$(edits_of skip)")"
eq "ignoring a tool still exits 0" "0" "$RC"

# --- 3. Silent and successful on malformed input -----------------------------
iso
mf=0
for bad in '' 'not json' '{"tool_name":"Edit"' '{"tool_name":"Edit","tool_input":{}}' '[]'; do
  o="$(printf '%s' "$bad" | bash "$H" 2>"$SANDBOX/err2")"; rc=$?
  e="$(cat "$SANDBOX/err2" 2>/dev/null)"
  if [ "$rc" != "0" ] || [ -n "$o" ] || [ -n "$e" ]; then
    flunk "malformed stdin [$bad] was not silent and successful (rc=$rc out=[$o] err=[$e])"; mf=1
  fi
done
[ "$mf" -eq 0 ] && pass "malformed or empty stdin stays silent and exits 0"

# --- 4. Churn trips a floor and consumes the log -----------------------------
# A fresh state dir makes the first batch silent by the bias-to-silence heal, so
# the baseline is seeded first.
iso
d="$(sd churn)"; playbook_state_reset "$d" 0
ef="$d/edits"
for p in a b c d e f; do printf '/p/%s.ts\n' "$p" >> "$ef"; done
for i in 1 2 3 4; do printf '/p/hot.ts\n' >> "$ef"; done
OUT="$(printf '{"hook_event_name":"PostToolBatch","session_id":"churn","transcript_path":"%s"}' "$B" | bash "$TB")"
CTX="$(jq -r '.hookSpecificOutput.additionalContext // empty' <<<"$OUT" 2>/dev/null)"
has "churn asserts a floor with its own evidence" "Playbook unease floor: $CHURN_SENTENCE."
has "the churn floor is set at uneasy" "Your unease floor is now uneasy."
eq "the churn floor level is stored" "uneasy" "$(st "$d" floor_level)"
eq "the churn floor reason is stored" "edit-churn" "$(st "$d" floor_reason)"
eq "a trip consumes the edit log" "0" "$(count_lines "$ef")"

# --- 5. Below the threshold, nothing trips -----------------------------------
iso
d="$(sd three)"; playbook_state_reset "$d" 0
ef="$d/edits"
for p in a b c d e f g; do printf '/p/%s.ts\n' "$p" >> "$ef"; done
for i in 1 2 3; do printf '/p/hot.ts\n' >> "$ef"; done
OUT="$(printf '{"hook_event_name":"PostToolBatch","session_id":"three","transcript_path":"%s"}' "$B" | bash "$TB")"
eq "three rewrites in the window emit nothing" "" "$OUT"
eq "three rewrites in the window set no floor" "" "$(st "$d" floor_level)"
eq "a quiet window leaves the edit log alone" "10" "$(count_lines "$ef")"

# Four rewrites, but spread outside the ten-edit window.
iso
d="$(sd spread)"; playbook_state_reset "$d" 0
ef="$d/edits"
for i in 1 2 3 4; do printf '/p/hot.ts\n' >> "$ef"; done
for p in a b c d e f g h i j; do printf '/p/%s.ts\n' "$p" >> "$ef"; done
OUT="$(printf '{"hook_event_name":"PostToolBatch","session_id":"spread","transcript_path":"%s"}' "$B" | bash "$TB")"
eq "rewrites older than the window emit nothing" "" "$OUT"
eq "rewrites older than the window set no floor" "" "$(st "$d" floor_level)"

# --- 6. The log is bounded on the batch pass ---------------------------------
iso
d="$(sd bound)"; playbook_state_reset "$d" 0
ef="$d/edits"
i=1
while [ "$i" -le 250 ]; do printf '/p/f%s.ts\n' "$i" >> "$ef"; i=$(( i + 1 )); done
OUT="$(printf '{"hook_event_name":"PostToolBatch","session_id":"bound","transcript_path":"%s"}' "$B" | bash "$TB")"
eq "an over-long log is rewritten to its last hundred" "100" "$(count_lines "$ef")"
eq "the rewrite keeps the newest records" "/p/f250.ts" "$(tail -n1 "$ef")"
eq "bounding the log is silent" "" "$OUT"

# --- 7. End to end: the recorder feeds the detector --------------------------
iso
d="$(sd e2e)"; playbook_state_reset "$d" 0
log_edit e2e Edit /p/churny.ts
log_edit e2e Edit /p/churny.ts
log_edit e2e Write /p/churny.ts
log_edit e2e Edit /p/churny.ts
OUT="$(printf '{"hook_event_name":"PostToolBatch","session_id":"e2e","transcript_path":"%s"}' "$B" | bash "$TB")"
CTX="$(jq -r '.hookSpecificOutput.additionalContext // empty' <<<"$OUT" 2>/dev/null)"
has "recorded edits reach the detector without help" "Playbook unease floor: $CHURN_SENTENCE."
eq "the end-to-end trip stores the churn floor" "edit-churn" "$(st "$d" floor_reason)"
eq "stdout is a single JSON object" "1" "$(jq -s 'length' <<<"$OUT" 2>/dev/null)"

exit $fail
