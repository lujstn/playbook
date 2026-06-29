#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
H="$root/hooks/take-a-beat"
export CLAUDE_PLUGIN_ROOT="$root"
unset CURSOR_PLUGIN_ROOT COPILOT_CLI 2>/dev/null || true
B="$root/tests/hooks/fixtures/transcript-basic.jsonl"
T="$root/tests/hooks/fixtures/transcript-beat.jsonl"

# PreCompact: steer that names the carried items, no file read.
out="$(printf '{"hook_event_name":"PreCompact","transcript_path":"%s"}' "$B" | bash "$H")"
jq -e '.hookSpecificOutput.additionalContext | test("Compact Instructions")' <<<"$out" >/dev/null \
  && echo "PASS: precompact steers" || { echo FAIL precompact; exit 1; }
grep -q "Lessons and wrong turns" <<<"$out" && echo "PASS: lessons named" || { echo FAIL lessons; exit 1; }
grep -q "playbook-window" <<<"$out" && echo "PASS: declared window carried" || { echo FAIL window; exit 1; }

# Post-compaction: original request recovered from the transcript with primacy.
out="$(printf '{"hook_event_name":"PostCompact","transcript_path":"%s"}' "$B" | bash "$H")"
grep -q "Build me a widget that does X. Original request text." <<<"$out" \
  && echo "PASS: original request re-injected from transcript" || { echo FAIL reanchor; exit 1; }
out="$(printf '{"hook_event_name":"SessionStart","source":"compact","transcript_path":"%s"}' "$B" | bash "$H")"
grep -q "Build me a widget that does X. Original request text." <<<"$out" \
  && echo "PASS: SessionStart/compact also recovers" || { echo FAIL reanchor2; exit 1; }

# Below threshold: silent (basic fixture is ~1 percent of 1,000,000 vs 80% default).
out="$(printf '{"hook_event_name":"PostToolUse","transcript_path":"%s"}' "$B" | bash "$H")"
[ -z "$out" ] && echo "PASS: no beat under 80 percent" || { echo FAIL spurious; exit 1; }

# Undeclared window with real usage: one self-healing notice, not silence,
# and not a (false) beat.
NW="$root/tests/hooks/fixtures/transcript-no-window.jsonl"
out="$(printf '{"hook_event_name":"PostToolUse","transcript_path":"%s"}' "$NW" | bash "$H")"
{ grep -q "Playbook context meter is off" <<<"$out" \
  && ! grep -qi "taking a beat" <<<"$out"; } \
  && echo "PASS: self-healing notice on undeclared window" \
  || { echo "FAIL notice: [$out]"; exit 1; }

# Notice already carried in the transcript: stay silent (once per session).
NWN="$root/tests/hooks/fixtures/transcript-no-window-noticed.jsonl"
out="$(printf '{"hook_event_name":"PostToolUse","transcript_path":"%s"}' "$NWN" | bash "$H")"
[ -z "$out" ] && echo "PASS: notice not repeated once carried" \
  || { echo "FAIL notice repeated: [$out]"; exit 1; }

# At/over threshold on the main thread: calm beat fires with calm wording,
# anchor re-injected labelled as original request.
# PLAYBOOK_CALM_PCT=70 aligns the threshold with the fixture (70% used).
out="$(PLAYBOOK_CALM_PCT=70 printf '{"hook_event_name":"PostToolUse","transcript_path":"%s"}' "$T" | PLAYBOOK_CALM_PCT=70 bash "$H")"
{ grep -qi "auto-compact is seamless" <<<"$out" \
  && grep -q "Original request, verbatim:" <<<"$out" \
  && ! grep -q "Overall goal" <<<"$out"; } \
  && echo "PASS: main-thread calm beat at 70 percent, original-request label" \
  || { echo "FAIL nobeat/mislabel: [$out]"; exit 1; }

# Beat gated once per window: a second PostToolUse with the same transcript
# stays silent because "Playbook context calm" is now in the output (sentinel).
# We simulate this by appending the sentinel to a temp transcript.
tmp_t="$(mktemp).jsonl"
cat "$T" > "$tmp_t"
printf '%s\n' '{"type":"system","subtype":"hook","content":"Playbook context calm: context is at 70 percent used. Auto-compact is seamless."}' >> "$tmp_t"
out2="$(PLAYBOOK_CALM_PCT=70 printf '{"hook_event_name":"PostToolUse","transcript_path":"%s"}' "$tmp_t" | PLAYBOOK_CALM_PCT=70 bash "$H")"
[ -z "$out2" ] && echo "PASS: calm beat not repeated when sentinel is in transcript" \
  || { echo "FAIL sentinel: beat repeated [$out2]"; rm "$tmp_t"; exit 1; }
rm "$tmp_t"

# Subagent beat: context calm fires, North Star primary, task relabelled,
# no "Original request, verbatim:". Use PLAYBOOK_CALM_PCT=70 to match fixture.
SB="$root/tests/hooks/fixtures/transcript-subagent-beat.jsonl"
out="$(PLAYBOOK_CALM_PCT=70 printf '{"hook_event_name":"PostToolUse","transcript_path":"%s","agent_id":"a1"}' "$SB" | PLAYBOOK_CALM_PCT=70 bash "$H")"
{ grep -qi "auto-compact is seamless" <<<"$out" \
  && grep -q "Overall goal (what success means for the whole project):" <<<"$out" \
  && grep -q "Ship a zero-dependency context anchor" <<<"$out" \
  && grep -q "Your part of it, verbatim:" <<<"$out" \
  && ! grep -q "Original request, verbatim:" <<<"$out"; } \
  && echo "PASS: subagent calm beat with North Star primacy and task label" \
  || { echo "FAIL subagent beat: [$out]"; exit 1; }

# SessionStart startup: competing hook detected, no context-calm marker ->
# OFFER fires once.
csl_home="$(mktemp -d)"
csl_proj="$(mktemp -d)"
mkdir -p "$csl_home/.claude" "$csl_proj/.claude/playbook"
printf '{"hooks":{"PostToolUse":[{"hooks":[{"command":"gsd-context-monitor"}]}]}}' \
  > "$csl_home/.claude/settings.json"
out="$(HOME="$csl_home" printf '{"hook_event_name":"SessionStart","source":"startup","cwd":"%s"}' "$csl_proj" \
  | HOME="$csl_home" bash "$H")"
grep -q "context-calm offer" <<<"$out" \
  && echo "PASS: context-calm offer fires when competing hook detected" \
  || { echo "FAIL: competing hook offer missing in [$out]"; rm -rf "$csl_home" "$csl_proj"; exit 1; }

# SessionStart startup: context-calm marker present -> offer is SILENT.
printf 'owned\n' > "$csl_proj/.claude/playbook/context-calm"
out2="$(HOME="$csl_home" printf '{"hook_event_name":"SessionStart","source":"startup","cwd":"%s"}' "$csl_proj" \
  | HOME="$csl_home" bash "$H")"
[ -z "$out2" ] \
  && echo "PASS: offer silent when context-calm marker exists" \
  || { echo "FAIL: offer repeated despite marker [$out2]"; rm -rf "$csl_home" "$csl_proj"; exit 1; }
rm -rf "$csl_home" "$csl_proj"

# Unrelated event: silent.
out="$(printf '{"hook_event_name":"Stop","transcript_path":"%s"}' "$B" | bash "$H")"
[ -z "$out" ] && echo "PASS: silent on non-handled events" || { echo FAIL stop; exit 1; }

# Malformed or empty stdin: silent, no abort, exit 0.
for bad in '' 'not json' '{"hook_event_name":"PostToolUse"'; do
  if mo="$(printf '%s' "$bad" | bash "$H" 2>/dev/null)"; then :; else
    echo "FAIL: stdin [$bad] aborted take-a-beat"; exit 1; fi
  [ -z "$mo" ] || { echo "FAIL: stdin [$bad] was not silent: [$mo]"; exit 1; }
done
echo "PASS: malformed or empty stdin is silent, no abort"

# Never creates a file in the project.
d="$(mktemp -d)"
printf '{"hook_event_name":"PostToolUse","cwd":"%s","transcript_path":"%s"}' "$d" "$T" | bash "$H" >/dev/null 2>&1 || true
[ ! -e "$d/.playbook" ] && echo "PASS: no file written" || { rm -rf "$d"; echo FAIL wrotefile; exit 1; }
rm -rf "$d"
