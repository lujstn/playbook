#!/usr/bin/env bash
set -uo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
H="$root/hooks/take-a-beat"
export CLAUDE_PLUGIN_ROOT="$root"
unset CURSOR_PLUGIN_ROOT COPILOT_CLI 2>/dev/null || true
source "$root/hooks/lib/playbook-common.sh"

GLOBAL_TMP="$(mktemp -d)"; export PLAYBOOK_GLOBAL_DIR="$GLOBAL_TMP"
printf 'checked=2026-07-24\nplugins=none\n' > "$GLOBAL_TMP/setup"
SANDBOX=""
trap 'rm -rf "$GLOBAL_TMP" "$SANDBOX"' EXIT

FIX="$root/tests/hooks/fixtures"
U="$FIX/transcript-unease.jsonl"    # marker uneasy, bash_fail=1, used 11540
R="$FIX/transcript-readfail.jsonl"  # no marker, bash_fail=0, used 10020
B="$FIX/transcript-basic.jsonl"     # quiet: no marker, bash_fail=0, used 10020
U_LEVEL="uneasy"
U_REASON="auth tests still failing"
TESTS_SENTENCE="a test run in this session reported failures"
TOOLS_SENTENCE="several tool calls have failed in a row without a clean batch between them"

fail=0
pass()  { echo "PASS: $1"; }
flunk() { echo "FAIL: $1"; fail=1; }
has()   { if grep -qF -- "$2" <<<"$CTX"; then pass "$1"; else flunk "$1"; fi }
hasnt() { if grep -qF -- "$2" <<<"$CTX"; then flunk "$1"; else pass "$1"; fi }
eq()    { if [ "$2" = "$3" ]; then pass "$1"; else flunk "$1 (expected [$2], got [$3])"; fi }

iso() {
  if [ -n "$SANDBOX" ]; then rm -rf "$SANDBOX"; fi
  SANDBOX="$(mktemp -d)"; export PLAYBOOK_STATE_DIR="$SANDBOX"
}
sd() { playbook_state_dir "{\"session_id\":\"$1\"}"; }
st() { playbook_state_get "$1" "$2"; }

fire() {  # event, session, transcript
  OUT="$(printf '{"hook_event_name":"%s","session_id":"%s","transcript_path":"%s"}' "$1" "$2" "$3" | bash "$H")"
  CTX="$(jq -r '.hookSpecificOutput.additionalContext // empty' <<<"$OUT" 2>/dev/null)"
}
seed() { playbook_state_reset "$1" 0; }

# --- 1. Detector 2 trips a failing-tests floor at concerned ------------------
iso
d="$(sd d2)"; seed "$d"
fire PostToolBatch d2 "$U"
has "the failing-tests detector asserts a floor" "Playbook unease floor: $TESTS_SENTENCE."
has "the assertion names the level" "Your unease floor is now concerned."
has "the assertion asks for an acknowledgement or an argument" "argue it down by printing a lower level"
eq "the floor level is stored" "concerned" "$(st "$d" floor_level)"
eq "the floor reason is stored" "failing-tests" "$(st "$d" floor_reason)"
eq "the trip zeroes the clean streak" "0" "$(st "$d" floor_clean_streak)"

# --- 2. No trip when the tail carries no Bash failure ------------------------
iso
d="$(sd rf)"; seed "$d"
fire PostToolBatch rf "$R"
eq "a Read result carrying FAIL text emits nothing" "" "$OUT"
eq "a Read result carrying FAIL text sets no floor" "" "$(st "$d" floor_level)"

# --- 3. Raise-only in both directions ----------------------------------------
iso
d="$(sd ro)"; seed "$d"
playbook_state_put "$d" "floor_level=concerned" "floor_reason=failing-tests"
fire PostToolUseFailure ro "$B"
fire PostToolUseFailure ro "$B"
fire PostToolUseFailure ro "$B"
eq "a lower detector level does not re-emit over a higher floor" "" "$OUT"
eq "a lower detector level does not lower the floor" "concerned" "$(st "$d" floor_level)"
eq "a lower detector level does not rewrite the floor reason" "failing-tests" "$(st "$d" floor_reason)"

iso
d="$(sd ro2)"; seed "$d"
playbook_state_put "$d" "floor_level=uneasy" "floor_reason=tool-failures" \
  "unease_level=$U_LEVEL" "unease_reason=$U_REASON"
fire PostToolBatch ro2 "$U"
has "a higher detector level raises the floor and says so" "Your unease floor is now concerned."
eq "the raised floor is stored" "concerned" "$(st "$d" floor_level)"
eq "the raised floor carries the new reason" "failing-tests" "$(st "$d" floor_reason)"

# --- 4. Acknowledge: a statement at or above the floor retires it -------------
iso
d="$(sd ack)"; seed "$d"
playbook_state_put "$d" "floor_level=uneasy" "floor_reason=failing-tests" "floor_clean_streak=2"
fire UserPromptSubmit ack "$U"
eq "an acknowledgement clears the floor level" "" "$(st "$d" floor_level)"
eq "an acknowledgement clears the floor reason" "" "$(st "$d" floor_reason)"
eq "an acknowledgement clears the clean streak" "" "$(st "$d" floor_clean_streak)"
eq "an acknowledgement is not an argument" "" "$(st "$d" argue_downs)"
eq "the stated level is recorded" "$U_LEVEL" "$(st "$d" unease_level)"
eq "the stated reason is recorded" "$U_REASON" "$(st "$d" unease_reason)"
has "the card reflects the retired floor immediately" "Unease: uneasy *$U_REASON*; no floor."

# --- 5. Argue down: a statement below the floor retires it and is counted -----
iso
d="$(sd arg)"; seed "$d"
playbook_state_put "$d" "floor_level=alarmed" "floor_reason=tool-failures"
fire UserPromptSubmit arg "$U"
eq "an argument down is counted" "1" "$(st "$d" argue_downs)"
eq "an argument down still retires the floor" "" "$(st "$d" floor_level)"

# --- 6. Decay: three clean batches retire a floor silently --------------------
iso
d="$(sd dec)"; seed "$d"
playbook_state_put "$d" "floor_level=concerned" "floor_reason=failing-tests"
fire PostToolBatch dec "$B"
eq "one clean batch counts towards the decay" "1" "$(st "$d" floor_clean_streak)"
fire PostToolBatch dec "$B"
eq "two clean batches do not retire the floor" "concerned" "$(st "$d" floor_level)"
eq "two clean batches count towards the decay" "2" "$(st "$d" floor_clean_streak)"
fire PostToolBatch dec "$B"
eq "three clean batches retire the floor" "" "$(st "$d" floor_level)"
eq "the retired floor takes its streak with it" "" "$(st "$d" floor_clean_streak)"
eq "the decay is silent" "" "$OUT"

# --- 7. Compaction preserves the floor; /clear wipes it ----------------------
iso
d="$(sd life)"; seed "$d"
playbook_state_put "$d" "floor_level=concerned" "floor_reason=failing-tests" \
  "floor_clean_streak=1" "floor_settled=tool-failures" "argue_downs=2" "unease_level=watchful"
printf '{"hook_event_name":"SessionStart","source":"compact","session_id":"life","transcript_path":"%s"}' "$B" \
  | bash "$H" >/dev/null 2>&1
eq "compaction preserves the floor level" "concerned" "$(st "$d" floor_level)"
eq "compaction preserves the floor reason" "failing-tests" "$(st "$d" floor_reason)"
eq "compaction preserves the argument count" "2" "$(st "$d" argue_downs)"
CH="$(mktemp -d)"
printf '{"hook_event_name":"SessionStart","source":"clear","session_id":"life","cwd":"%s","transcript_path":"/no/such.jsonl"}' "$CH" \
  | HOME="$CH" bash "$H" >/dev/null 2>&1
eq "/clear wipes the floor level" "" "$(st "$d" floor_level)"
eq "/clear wipes the floor reason" "" "$(st "$d" floor_reason)"
eq "/clear wipes the clean streak" "" "$(st "$d" floor_clean_streak)"
eq "/clear wipes the settled detector" "" "$(st "$d" floor_settled)"
eq "/clear wipes the argument count" "" "$(st "$d" argue_downs)"
eq "/clear wipes the stated unease" "" "$(st "$d" unease_level)"
rm -rf "$CH"

# --- 8. Two things to say, still one envelope --------------------------------
iso
d="$(sd env)"; seed "$d"
playbook_state_put "$d" "unease_level=$U_LEVEL" "unease_reason=$U_REASON"
big="$SANDBOX/big.jsonl"
cat "$U" > "$big"
jq -cn '{type:"assistant", message:{role:"assistant", model:"m",
  usage:{input_tokens:40, cache_creation_input_tokens:200000, cache_read_input_tokens:499960},
  content:[{type:"text", text:"Continuing the work."}]}}' >> "$big"
OUT="$(printf '{"hook_event_name":"PostToolBatch","session_id":"env","transcript_path":"%s"}' "$big" \
  | PLAYBOOK_WINDOW=1000000 bash "$H")"
CTX="$(jq -r '.hookSpecificOutput.additionalContext // empty' <<<"$OUT" 2>/dev/null)"
eq "stdout carries exactly one JSON object" "1" "$(jq -s 'length' <<<"$OUT" 2>/dev/null)"
eq "the envelope carries exactly one additionalContext" "1" \
   "$(jq -s '[.. | objects | select(has("additionalContext"))] | length' <<<"$OUT" 2>/dev/null)"
has "the combined body carries the floor assertion" "Playbook unease floor: $TESTS_SENTENCE."
has "the combined body carries the pulse" "Playbook pulse: a long stretch of work has passed"
fl_line="$(grep -n 'Playbook unease floor' <<<"$CTX" | head -n1 | cut -d: -f1)"
pl_line="$(grep -n 'Playbook pulse' <<<"$CTX" | head -n1 | cut -d: -f1)"
if [ -n "$fl_line" ] && [ -n "$pl_line" ] && [ "$fl_line" -lt "$pl_line" ]; then
  pass "the floor assertion leads the combined body"
else
  flunk "the floor assertion does not lead the combined body (floor line $fl_line, pulse line $pl_line)"
fi

# --- 9. The parser records a statement once ----------------------------------
iso
d="$(sd par)"; seed "$d"
fire UserPromptSubmit par "$U"
eq "the parser records the stated level" "$U_LEVEL" "$(st "$d" unease_level)"
eq "the parser records the stated reason" "$U_REASON" "$(st "$d" unease_reason)"
eq "no floor means nothing to argue with" "" "$(st "$d" argue_downs)"
playbook_state_put "$d" "unease_at=0"
fire UserPromptSubmit par "$U"
eq "an unchanged marker is not re-recorded" "0" "$(st "$d" unease_at)"
eq "an unchanged marker adjudicates nothing" "" "$(st "$d" argue_downs)"

# --- 10. An answered detector does not immediately re-assert itself ----------
iso
d="$(sd loop)"; seed "$d"
playbook_state_put "$d" "floor_level=concerned" "floor_reason=failing-tests"
fire PostToolBatch loop "$U"
eq "answering the floor retires it" "" "$(st "$d" floor_level)"
eq "the answered detector is recorded as settled" "failing-tests" "$(st "$d" floor_settled)"
eq "the same batch does not re-assert the answered floor" "" "$OUT"
fire PostToolBatch loop "$U"
eq "a later batch on the same evidence stays quiet" "" "$OUT"
eq "a later batch on the same evidence sets no floor" "" "$(st "$d" floor_level)"
fire PostToolBatch loop "$B"
eq "a clean batch re-arms the settled detector" "" "$(st "$d" floor_settled)"
fire PostToolBatch loop "$U"
has "a re-armed detector asserts the floor again" "Playbook unease floor: $TESTS_SENTENCE."
eq "the re-armed detector restores the floor" "concerned" "$(st "$d" floor_level)"

# --- 11. A verbatim re-statement still answers the floor it was asked for ----
iso
d="$(sd vb)"; seed "$d"
playbook_state_put "$d" "unease_level=$U_LEVEL" "unease_reason=$U_REASON" \
  "floor_level=uneasy" "floor_reason=tool-failures" "floor_at=1" \
  "floor_clean_streak=0" "floor_marker_count=1"
fire UserPromptSubmit vb "$U"
eq "a repeated identical marker retires the floor when the count grew" "" "$(st "$d" floor_level)"
eq "the answered detector is settled" "tool-failures" "$(st "$d" floor_settled)"
eq "an acknowledgement at the floor level is not an argue-down" "" "$(st "$d" argue_downs)"

# --- 12. A stale marker alone answers nothing --------------------------------
iso
d="$(sd stale)"; seed "$d"
playbook_state_put "$d" "unease_level=$U_LEVEL" "unease_reason=$U_REASON" \
  "floor_level=uneasy" "floor_reason=tool-failures" "floor_at=1" \
  "floor_clean_streak=0" "floor_marker_count=2"
fire UserPromptSubmit stale "$U"
eq "a stale marker leaves the floor standing" "uneasy" "$(st "$d" floor_level)"
eq "a stale marker is not an argue-down" "" "$(st "$d" argue_downs)"

exit $fail
