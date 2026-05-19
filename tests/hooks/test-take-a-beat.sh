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

# Below threshold: silent (basic fixture is ~1 percent of 1,000,000).
out="$(printf '{"hook_event_name":"PostToolUse","transcript_path":"%s"}' "$B" | bash "$H")"
[ -z "$out" ] && echo "PASS: no beat under 65 percent" || { echo FAIL spurious; exit 1; }

# At/over threshold: announces the beat (beat fixture is 70 percent).
out="$(printf '{"hook_event_name":"PostToolUse","transcript_path":"%s"}' "$T" | bash "$H")"
grep -qi "taking a beat" <<<"$out" && echo "PASS: beat at 70 percent" || { echo FAIL nobeat; exit 1; }

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
