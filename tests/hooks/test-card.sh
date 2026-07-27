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
B="$FIX/transcript-basic.jsonl"   # used 10020
T="$FIX/transcript-beat.jsonl"    # used 700020
MISSING="/no/such/transcript.jsonl"
NS_BASIC="Build me a widget that does X. Original request text."
ANCHOR="Playbook anchor: a long stretch has passed since the last anchor"
LEVELS='clear|settled|attentive|watchful|faintly_uneasy|uneasy|concerned|strained|troubled|alarmed|near_breaking'

fail=0
pass()  { echo "PASS: $1"; }
flunk() { echo "FAIL: $1"; fail=1; }
chk()   { if eval "$1" >/dev/null 2>&1; then pass "$2"; else flunk "$2"; fi }
has()   { if grep -qF -- "$2" <<<"$CTX"; then pass "$1"; else flunk "$1"; fi }
hasnt() { if grep -qF -- "$2" <<<"$CTX"; then flunk "$1"; else pass "$1"; fi }

iso() {
  if [ -n "$SANDBOX" ]; then rm -rf "$SANDBOX"; fi
  SANDBOX="$(mktemp -d)"; export PLAYBOOK_STATE_DIR="$SANDBOX"
}
sd() { playbook_state_dir "{\"session_id\":\"$1\"}"; }

run() {
  OUT="$(printf '{"hook_event_name":"UserPromptSubmit","session_id":"%s","transcript_path":"%s"}' "$1" "$2" | bash "$H")"
  RC=$?
  CTX="$(jq -r '.hookSpecificOutput.additionalContext // empty' <<<"$OUT" 2>/dev/null)"
}

# --- 1. First prompt of a fresh session: the card still lands -----------------
iso
run first "$MISSING"
chk '[ "$RC" = 0 ]' "first prompt exits 0"
has "card header on the first prompt" "📚 **Playbook** card"
has "no transcript yet: North Star reads as not captured" "North Star: (not yet captured)"
has "no state yet: unease reads as none stated, no floor" "Unease: none stated yet; no floor."
has "bullet: routing, verbatim" \
  "- Route non-trivial work before starting it: 🐺 lone-wolf, 🐜 interns, 🤝 hackathon, ⚙️ workflows, 🏗️ gsd. Announce as <emoji> **Playbook** \`<mode>\` *<reason>*; depth in the /playbook:* skills."
has "bullet: dispatch line and model split, verbatim" \
  "- Every dispatch carries \`playbook-northstar: <line>\` and an explicit model: Sonnet executes, Opus plans and reviews."
has "bullet: time estimate, verbatim" \
  "- Divide your felt time estimate by ten; never divide external waits or observed durations."
has "bullet: compaction is safe, verbatim" \
  "- Compaction is safe: never wrap up early. If your unease has changed, print the 🌡️ **Playbook** \`unease: <level>\` *<reason>* line."

# --- 2. Lazy excerpt: recovered from the transcript and cached ----------------
iso
run lazy "$B"
d="$(sd lazy)"
has "excerpt recovered lazily when the state cache is empty" "North Star: $NS_BASIC"
chk '[ "$(playbook_state_get "$d" northstar_excerpt)" = "$NS_BASIC" ]' "the lazy excerpt is written back to state"

# --- 3. A stated unease renders ----------------------------------------------
iso
d="$(sd unease)"; playbook_state_reset "$d" 0
playbook_state_put "$d" "unease_level=watchful" "unease_reason=flaky auth tests"
run unease "$MISSING"
has "a stated unease renders with its reason" "Unease: watchful *flaky auth tests*; no floor."

# --- 4. A floor renders with its call to action ------------------------------
iso
d="$(sd floor)"; playbook_state_reset "$d" 0
playbook_state_put "$d" "floor_level=uneasy" "floor_reason=tool-failures"
run floor "$MISSING"
has "the floor renders with its level and reason" "floor: uneasy (tool-failures)"
has "the floor carries the acknowledge-or-argue instruction" "acknowledge it or argue it down"

# --- 5. The card never renders a concrete unease marker ----------------------
iso
d="$(sd marker)"; playbook_state_reset "$d" 0
playbook_state_put "$d" "unease_level=concerned" "unease_reason=nothing lines up" \
  "floor_level=strained" "floor_reason=three failures in a row"
run marker "$MISSING"
chk '! grep -qE "🌡️ \*\*Playbook\*\* \`unease: ($LEVELS)\`" <<<"$CTX"' \
    "the card never renders the concrete marker form the detector parses"
has "the card's own example keeps the placeholder level" "unease: <level>"

# --- 6. Below threshold: card emitted, baseline untouched, no pulse suffix ----
iso
d="$(sd thr)"; playbook_state_reset "$d" 1000
run thr "$B"
has "below-threshold prompt still emits a card" "📚 **Playbook** card"
hasnt "below-threshold prompt carries no pulse suffix" "long stretch"
chk '[ "$(playbook_state_int "$d" last_anchor_used 9)" = "1000" ]' "a silent pulse does not touch the baseline"

iso
d="$(sd heal)"; playbook_state_reset "$d" 500000
run heal "$B"
has "the card survives the negative-delta heal" "📚 **Playbook** card"
hasnt "the heal costs the pulse suffix only" "long stretch"
chk '[ "$(playbook_state_int "$d" last_anchor_used 9)" = "10020" ]' "the heal rebaselines to current usage"

# --- 7. Pulse fold-in at the token delta -------------------------------------
iso
d="$(sd pulse)"; playbook_state_reset "$d" 0
run pulse "$T"
has "the pulse rides along as a suffix once the delta is passed" "$ANCHOR"
has "the pulse suffix rides on the card, not instead of it" "📚 **Playbook** card"
chk '[ "$(playbook_state_int "$d" last_anchor_used 9)" = "700020" ]' "a fired pulse advances the baseline"

# --- 8. One envelope, one injected context -----------------------------------
iso
d="$(sd env)"; playbook_state_reset "$d" 0
run env "$T"
chk 'jq -e . <<<"$OUT"' "the envelope is valid JSON"
chk '[ "$(jq -s "length" <<<"$OUT")" = "1" ]' "stdout carries exactly one JSON object"
chk '[ "$(jq -s "[.. | objects | select(has(\"additionalContext\"))] | length" <<<"$OUT")" = "1" ]' \
    "the envelope carries exactly one additionalContext"

# --- 9. Byte ceiling on the card body ----------------------------------------
iso
d="$(sd size)"; playbook_state_reset "$d" 0
long="$SANDBOX/long.jsonl"
jq -cn '{type:"user", message:{role:"user", content:("Rebuild the reliability layer end to end " + ("x" * 200))}}' > "$long"
playbook_state_put "$d" "unease_level=near_breaking" "unease_reason=the approach itself looks wrong" \
  "floor_level=near_breaking" "floor_reason=three tool failures with no clean batch"
run size "$long"
bytes=$(printf '%s' "$CTX" | wc -c | tr -d ' ')
hasnt "the measured card carries no pulse suffix" "long stretch"
chk '[ "$bytes" -gt 0 ] && [ "$bytes" -lt 1400 ]' "card body is $bytes bytes, under the 1400-byte ceiling"

# --- 10. /clear wipes the conversation-scoped state --------------------------
iso
d="$(sd clr)"; playbook_state_reset "$d" 0
playbook_state_put "$d" "northstar_excerpt=a stale request from the last conversation" \
  "unease_level=troubled" "unease_reason=stale" "floor_level=strained" "floor_reason=stale"
chk '[ "$(playbook_state_get "$d" unease_level)" = "troubled" ]' "the stale conversation state is seeded before the /clear"
CH="$(mktemp -d)"
printf '{"hook_event_name":"SessionStart","source":"clear","session_id":"clr","cwd":"%s","transcript_path":"%s"}' "$CH" "$MISSING" \
  | HOME="$CH" bash "$H" >/dev/null 2>&1
run clr "$MISSING"
has "/clear drops the cached excerpt" "North Star: (not yet captured)"
has "/clear drops the unease and the floor" "Unease: none stated yet; no floor."
rm -rf "$CH"

# --- 11. Compaction preserves it ---------------------------------------------
iso
d="$(sd cmp)"; playbook_state_reset "$d" 0
playbook_state_put "$d" "northstar_excerpt=Ship the reliability redesign" \
  "unease_level=concerned" "unease_reason=slow tests"
printf '{"hook_event_name":"SessionStart","source":"compact","session_id":"cmp","transcript_path":"%s"}' "$MISSING" \
  | bash "$H" >/dev/null 2>&1
run cmp "$MISSING"
has "compaction preserves the stated unease" "Unease: concerned *slow tests*; no floor."
has "compaction preserves the cached excerpt" "North Star: Ship the reliability redesign"

echo "-- a visible restatement updates the card with the restated label"
U="$FIX/transcript-unease.jsonl"
iso
d="$(sd rst)"; playbook_state_reset "$d" 0
playbook_state_put "$d" "northstar_excerpt=condense this chat log into one message"
run rst "$U"
has "a restatement replaces the stale excerpt" "North Star (restated): evidence-backed addresses for every org"
chk '[ "$(playbook_state_get "$d" northstar_restated)" = "1" ]' "the restated flag is set in state"
run rst "$U"
has "an unchanged restatement keeps the restated label" "North Star (restated): evidence-backed addresses for every org"

echo "-- a task-only line never overwrites the excerpt"
iso
d="$(sd tno)"; playbook_state_reset "$d" 0
playbook_state_put "$d" "northstar_excerpt=the real project goal"
NONE_T="$SANDBOX/none.jsonl"
jq -cn '{type:"user", message:{role:"user", content:"start"}}' > "$NONE_T"
jq -cn '{type:"assistant", message:{role:"assistant", model:"m",
  usage:{input_tokens:10, cache_creation_input_tokens:100, cache_read_input_tokens:400},
  content:[{type:"text", text:"Dispatching the chore.\nplaybook-northstar: none (task-only)"}]}}' >> "$NONE_T"
run tno "$NONE_T"
has "a task-only line leaves the excerpt alone" "North Star: the real project goal"
chk '[ -z "$(playbook_state_get "$d" northstar_restated)" ]' "a task-only line sets no restated flag"

echo "-- /clear wipes the restated flag"
iso
d="$(sd rcl)"; playbook_state_reset "$d" 0
playbook_state_put "$d" "northstar_excerpt=old goal" "northstar_restated=1"
CH="$(mktemp -d)"
printf '{"hook_event_name":"SessionStart","source":"clear","session_id":"rcl","cwd":"%s","transcript_path":"%s"}' "$CH" "$MISSING" \
  | HOME="$CH" bash "$H" >/dev/null 2>&1
run rcl "$MISSING"
has "/clear returns the plain North Star label" "North Star: (not yet captured)"
chk '[ -z "$(playbook_state_get "$d" northstar_restated)" ]' "/clear wipes the restated flag"
rm -rf "$CH"

exit $fail
