#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/payloads.sh"
FIX="$root/tests/hooks/fixtures"
B="$FIX/transcript-basic.jsonl"
T="$FIX/transcript-beat.jsonl"
tp() { printf '{"transcript_path":"%s"}' "$1"; }

# --- context meter ----------------------------------------------------------
eq "usage sum is the last assistant input plus cache" 10020 "$(playbook_context_used "$(tp "$B")")"
eq "a big transcript reads its tail" 700020 "$(playbook_context_used "$(tp "$T")")"
eq "a missing transcript is empty" "" "$(playbook_context_used '{"transcript_path":"/no/such/file"}')"
big="$(mktemp).jsonl"
printf '{"type":"user","message":{"role":"user","content":"first"}}\n' > "$big"
printf '{"type":"system","subtype":"noise","content":"%s"}\n' "$(head -c 350000 /dev/zero | tr '\0' 'z')" >> "$big"
printf '{"type":"assistant","message":{"role":"assistant","usage":{"input_tokens":100,"cache_creation_input_tokens":2000,"cache_read_input_tokens":50000,"output_tokens":5},"content":[{"type":"text","text":"done"}]}}\n' >> "$big"
eq "the bounded read finds the final usage past a 300KB filler" 52100 "$(playbook_context_used "$(tp "$big")")"
rm -f "$big"

# --- window and percent ----------------------------------------------------
ws="$(mktemp -d)"
eq "an env window wins" 1000000 "$(PLAYBOOK_WINDOW=1000000 playbook_window "$ws")"
eq "and is proven" proven "$(PLAYBOOK_WINDOW=1000000 playbook_window_provenance "$ws")"
eq "the default is the assumed 200000" 200000 "$(playbook_window "$ws")"
eq "and assumed" assumed "$(playbook_window_provenance "$ws")"
eq "junk falls through" 200000 "$(PLAYBOOK_WINDOW=junk playbook_window "$ws")"
printf 'window_proven=1000000\n' > "$ws/state"
eq "a ratcheted window is sticky" 1000000 "$(playbook_window "$ws")"
rm -rf "$ws"
eq "percent rounds" 70 "$(playbook_percent 700020 1000000)"
eq "percent is empty on junk" "" "$(playbook_percent x 100)"
eq "percent caps at 100" 100 "$(playbook_percent 900 100)"

# --- envelopes --------------------------------------------------------------
eq "Claude Code envelope" "SessionStart" "$(playbook_emit_context SessionStart 'hi "q"' | jq -r .hookSpecificOutput.hookEventName)"
eq "the body survives quoting" 'hi "q"' "$(playbook_emit_context SessionStart 'hi "q"' | jq -r .hookSpecificOutput.additionalContext)"
eq "newlines survive" "a
b" "$(playbook_emit_context UserPromptSubmit 'a
b' | jq -r .hookSpecificOutput.additionalContext)"
eq "Cursor envelope" "x" "$(CURSOR_PLUGIN_ROOT=/c playbook_emit_context SessionStart x | jq -r .additional_context)"
eq "generic envelope" "x" "$(CLAUDE_PLUGIN_ROOT= playbook_emit_context SessionStart x | jq -r .additionalContext)"

# --- project dir and rule paths ---------------------------------------------
eq "the payload cwd names the project" /p "$(playbook_project_dir '{"cwd":"/p"}')"
eq "CLAUDE_PROJECT_DIR is the fallback" /q "$(CLAUDE_PROJECT_DIR=/q playbook_project_dir '{}')"
hm="$(mktemp -d)"; proj="$(mktemp -d)"; mkdir -p "$hm/.claude/rules" "$proj/.claude"
echo > "$hm/.claude/CLAUDE.md"; echo > "$hm/.claude/rules/b.md"; echo > "$proj/CLAUDE.md"; echo > "$proj/.claude/CLAUDE.md"
eq "rule paths list only what exists, global first" "$hm/.claude/CLAUDE.md
$hm/.claude/rules/b.md
$proj/CLAUDE.md
$proj/.claude/CLAUDE.md" "$(HOME="$hm" playbook_rule_paths "$proj")"
rm -rf "$hm" "$proj"

# --- the user's words and decisions ---------------------------------------
iso; d="$(sd w)"
eq "a meta record is not the user's" 1 "$(playbook_is_human_text '<system-reminder>x' && echo 0 || echo 1)"
pasted='```
<pasted_content id="c8e2">
One test for "serious": a finding is serious only if
</pasted_content id="c8e2">
```

I feel like that isn'"'"'t a great definition, take a beat'
eq "a message that quotes pasted text still counts as the user's" 0 "$(playbook_is_human_text "$pasted" && echo 0 || echo 1)"
eq "without the pasted part" "I feel like that isn't a great definition, take a beat" "$(playbook_strip_pasted "$pasted" | sed '/^```$/d;/^$/d')"
eq "so does one that opens with the paste" 0 "$(playbook_is_human_text "$(printf '<pasted_content id="a1">\nsome log\n</pasted_content id="a1">\nwhy does this fail?')" && echo 0 || echo 1)"
eq "a message that is only pasted text is not" 1 "$(playbook_is_human_text "$(printf '<pasted_content id="a1">\nsome log\n</pasted_content id="a1">')" && echo 0 || echo 1)"
eq "a continuation summary is not the user's" 1 "$(playbook_is_human_text 'This session is being continued from x' && echo 0 || echo 1)"
eq "a teammate message is not the user's" 1 "$(playbook_is_human_text 'hi <teammate-message from=a>' && echo 0 || echo 1)"
eq "plain words are" 0 "$(playbook_is_human_text 'build the thing' && echo 0 || echo 1)"
playbook_human_message "$d" "Please keep   the OLD importer." >/dev/null
playbook_human_message "$d" "$pasted" >/dev/null
playbook_words_found "$d" "isn't a great definition" && pass "the user's own words around a paste are kept" || flunk "the words around a paste were dropped"
playbook_words_found "$d" "a finding is serious only if" && flunk "pasted text was kept as the user's words" || pass "the pasted text itself is not"
playbook_words_found "$d" "keep the old importer" && pass "words are found ignoring case and spacing" || flunk "words not found"
playbook_words_found "$d" "delete the importer" && flunk "invented words were found" || pass "invented words are not found"
playbook_human_message "$d" "<task-notification>x" && flunk "a non-human prompt counted" || pass "a non-human prompt returns 1"
big=""; for i in 1 2 3 4 5; do playbook_decision_add "$d" asked "Q$i" "$(head -c 800 /dev/zero | tr '\0' a)" >/dev/null; done
t="$(playbook_decisions_text "$d" 1000)"
OUT="$t"; has "a budgeted decisions text points at the file" "The rest are in"
[ "${#t}" -lt 1300 ] && pass "and respects the budget (${#t})" || flunk "budget ignored (${#t})"

# --- modes, patterns, review names ----------------------------------------
eq "mode canon strips the recommended tag" interns "$(playbook_mode_canon 'Interns (Recommended)')"
eq "and joins lone wolf" lone-wolf "$(playbook_mode_canon 'lone wolf')"
eq "an unknown mode is empty" "" "$(playbook_mode_canon 'bogus')"
eq "a mode has an emoji" 🤝 "$(playbook_mode_emoji hackathon)"
playbook_match test "pnpm run test" && pass "the test pattern" || flunk "test pattern"
playbook_match test "sed -n 1,5p x_test.go" && flunk "sed matched the test pattern" || pass "printing source is not a test"
playbook_match commit "git add ." && pass "stage counts as a commit" || flunk "commit pattern"
playbook_match waitme "I am waiting on your Touch ID" && pass "waitme matches a wait on the user" || flunk "waitme"
eq "review names drop round suffixes" "phase10 review" "$(playbook_review_base 'Phase10 Review (round 3)')"

# --- removed helpers --------------------------------------------------------
gone=0
for fn in playbook_scan_tail playbook_original_request playbook_anchor_block playbook_project_northstar \
          playbook_unease_rank playbook_state_reset playbook_state_healthy playbook_fail_count playbook_fail_append \
          playbook_northstar_excerpt playbook_dir playbook_ledger playbook_emit_stop_nudge; do
  if declare -F "$fn" >/dev/null 2>&1; then flunk "$fn is still defined"; gone=1; fi
done
[ "$gone" -eq 0 ] && pass "the tail scan, original-request recovery, anchor and baseline helpers are gone"

exit $fail
