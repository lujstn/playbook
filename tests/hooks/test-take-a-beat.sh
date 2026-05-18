#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
H="$root/hooks/take-a-beat"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
# Exercise the Claude Code platform path: the harness always sets
# CLAUDE_PLUGIN_ROOT for plugin hooks (mirrors Superpowers session-start
# lines 49-50; see playbook-common.sh playbook_emit_context). The assertions
# below test the Claude shape (.hookSpecificOutput.additionalContext), so the
# Claude platform branch must be selected; clear the other platforms' markers
# so selection is deterministic regardless of the ambient shell.
export CLAUDE_PLUGIN_ROOT="$root"
unset CURSOR_PLUGIN_ROOT COPILOT_CLI 2>/dev/null || true
source "$root/hooks/lib/playbook-common.sh"
printf '{"cwd":"%s"}' "$tmp" > "$tmp/in.json"
playbook_anchor_init "ORIG-REQ" "WHAT-MATTERS" "$(cat "$tmp/in.json")"

# PreCompact: must inject compact instructions naming the lessons ledger.
out="$(jq -c '. + {hook_event_name:"PreCompact"}' "$tmp/in.json" | bash "$H")"
jq -e '.hookSpecificOutput.additionalContext | test("Compact Instructions")' <<<"$out" >/dev/null \
  && echo "PASS: precompact steers" || { echo "FAIL precompact"; exit 1; }
grep -q "Lessons and wrong turns" <<<"$out" && echo "PASS: lessons preserved" || { echo "FAIL lessons"; exit 1; }

# Post-compaction: anchor re-injected with primacy.
out="$(jq -c '. + {hook_event_name:"SessionStart",source:"compact"}' "$tmp/in.json" | bash "$H")"
grep -q "ORIG-REQ" <<<"$out" && echo "PASS: anchor re-injected" || { echo "FAIL reanchor"; exit 1; }

# Monitor below threshold: silent.
# NB: a `VAR=val name=$(...)` line is an assignment, not a simple command, so
# the env prefix is NOT exported into the command-substitution subshell (POSIX
# applies the prefix only to simple commands). The fixture must reach the hook
# subprocess for this to be a real test, so export it on its own statement and
# unset it after to keep each block hermetic.
export PLAYBOOK_CTX_FIXTURE="$root/tests/hooks/fixtures/ctx-used-40.json"
out="$(jq -c '. + {hook_event_name:"PostToolUse"}' "$tmp/in.json" | bash "$H")"
[ -z "$out" ] || [ "$(jq -r '.hookSpecificOutput.additionalContext // ""' <<<"$out")" = "" ] \
  && echo "PASS: no beat under 65%" || { echo "FAIL spurious beat"; exit 1; }
unset PLAYBOOK_CTX_FIXTURE

# Monitor at/over threshold: announces the beat.
export PLAYBOOK_CTX_FIXTURE="$root/tests/hooks/fixtures/ctx-used-70.json"
out="$(jq -c '. + {hook_event_name:"PostToolUse"}' "$tmp/in.json" | bash "$H")"
grep -qi "taking a beat" <<<"$out" && echo "PASS: beat at 70%" || { echo "FAIL no beat"; exit 1; }
unset PLAYBOOK_CTX_FIXTURE

# Unrelated event (e.g. Stop) must produce nothing (regression for m3).
out="$(jq -c '. + {hook_event_name:"Stop"}' "$tmp/in.json" | bash "$H")"
[ -z "$out" ] && echo "PASS: silent on non-handled events" || { echo "FAIL: spurious output on Stop"; exit 1; }
