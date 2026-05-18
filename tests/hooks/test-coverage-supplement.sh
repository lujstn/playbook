#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
# Claude Code platform path: the harness always sets CLAUDE_PLUGIN_ROOT for
# plugin hooks. The assertions below test the Claude shape
# (.hookSpecificOutput.additionalContext), so the Claude platform branch must be
# selected; clear the other platforms' markers so selection is deterministic
# regardless of the ambient shell (mirrors test-take-a-beat.sh / test-uncertainty.sh).
export CLAUDE_PLUGIN_ROOT="$root"
unset CURSOR_PLUGIN_ROOT COPILOT_CLI 2>/dev/null || true
source "$root/hooks/lib/playbook-common.sh"

BEAT="$root/hooks/take-a-beat"
SS="$root/hooks/session-start"

# --- T6a: playbook_anchor_read on an existing anchor returns its content ----
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
in="{\"cwd\":\"$tmp\"}"
playbook_anchor_init "T6a-ORIGINAL-REQUEST" "T6a-what-matters" "$in"
got="$(playbook_anchor_read "$in")"
grep -qF "T6a-ORIGINAL-REQUEST" <<<"$got" \
  && echo "PASS: T6a anchor_read returns existing anchor content" \
  || { echo "FAIL: T6a anchor_read did not return existing anchor content"; exit 1; }

# --- T6b: playbook_anchor_read on a MISSING anchor returns empty and does ---
# --- not abort a set -euo pipefail caller --------------------------------
empty_tmp="$(mktemp -d)"
miss="$(playbook_anchor_read "{\"cwd\":\"$empty_tmp\"}")"
# The line above must not have killed this script under set -e; reaching here
# proves it returned 0. Now assert the output was empty.
if [ -z "$miss" ]; then
  echo "PASS: T6b anchor_read on missing anchor is empty and does not abort the caller"
else
  echo "FAIL: T6b anchor_read on missing anchor was not empty: '$miss'"; exit 1
fi
rm -rf "$empty_tmp"

# --- T6c: playbook_anchor_init no-clobber --------------------------------
clob_tmp="$(mktemp -d)"
clob_in="{\"cwd\":\"$clob_tmp\"}"
playbook_anchor_init "T6c-FIRST-original" "T6c-first-matters" "$clob_in"
playbook_anchor_init "T6c-SECOND-original" "T6c-second-matters" "$clob_in"
clob="$(cat "$clob_tmp/.playbook/anchor.md")"
if grep -qF "T6c-FIRST-original" <<<"$clob" && ! grep -qF "T6c-SECOND-original" <<<"$clob"; then
  echo "PASS: T6c anchor_init does not clobber an existing anchor (first content only)"
else
  echo "FAIL: T6c anchor_init clobbered the existing anchor"; exit 1
fi
rm -rf "$clob_tmp"

# --- T7a: take-a-beat direct PostCompact re-injects the anchor -----------
pc_tmp="$(mktemp -d)"
pc_in="{\"cwd\":\"$pc_tmp\"}"
playbook_anchor_init "T7a-POSTCOMPACT-REQUEST" "T7a-what-matters" "$pc_in"
out="$(printf '{"cwd":"%s","hook_event_name":"PostCompact"}' "$pc_tmp" | bash "$BEAT")"
ctx="$(jq -r '.hookSpecificOutput.additionalContext // ""' <<<"$out")"
grep -qF "T7a-POSTCOMPACT-REQUEST" <<<"$ctx" \
  && echo "PASS: T7a take-a-beat PostCompact re-injects the anchor" \
  || { echo "FAIL: T7a PostCompact did not re-inject the anchor"; exit 1; }
rm -rf "$pc_tmp"

# --- T7b: 65% boundary is inclusive (>=65 fires) -------------------------
b_tmp="$(mktemp -d)"
b_in="{\"cwd\":\"$b_tmp\"}"
playbook_anchor_init "T7b-BOUNDARY-REQUEST" "T7b-what-matters" "$b_in"
# Confirm the fixture yields exactly 65 used before relying on it.
export PLAYBOOK_CTX_FIXTURE="$root/tests/hooks/fixtures/ctx-remaining-35.json"
fix_pct="$(playbook_context_percent)"
[ "$fix_pct" = "65" ] \
  || { echo "FAIL: T7b precondition - ctx-remaining-35.json yields '$fix_pct', expected 65"; exit 1; }
out="$(printf '{"cwd":"%s","hook_event_name":"PostToolUse"}' "$b_tmp" | bash "$BEAT")"
unset PLAYBOOK_CTX_FIXTURE
ctx="$(jq -r '.hookSpecificOutput.additionalContext // ""' <<<"$out")"
if grep -qi "taking a beat" <<<"$ctx" && grep -qF "T7b-BOUNDARY-REQUEST" <<<"$ctx"; then
  echo "PASS: T7b beat fires at exactly 65% used (boundary is inclusive)"
else
  echo "FAIL: T7b beat did not fire at exactly 65% used"; exit 1
fi
rm -rf "$b_tmp"

# --- T14: source=compact SessionStart double-restore (belt-and-braces) ---
# Both session-start and take-a-beat independently restore the anchor on a
# SessionStart/source=compact event. This idempotent double-restore is the
# intentional belt-and-braces design (decision C2), not a bug; this test
# documents and locks that expectation.
dc_tmp="$(mktemp -d)"
dc_in="{\"cwd\":\"$dc_tmp\"}"
playbook_anchor_init "T14-COMPACT-REQUEST" "T14-what-matters" "$dc_in"
dc_stdin="$(printf '{"cwd":"%s","hook_event_name":"SessionStart","source":"compact"}' "$dc_tmp")"

# T14a: session-start emits the overlay AND the anchor.
ss_out="$(printf '%s' "$dc_stdin" | bash "$SS")"
ss_ctx="$(jq -r '.hookSpecificOutput.additionalContext // ""' <<<"$ss_out")"
if grep -qF "PLAYBOOK_OVERLAY" <<<"$ss_ctx" && grep -qF "T14-COMPACT-REQUEST" <<<"$ss_ctx"; then
  echo "PASS: T14a session-start on source=compact emits overlay and anchor"
else
  echo "FAIL: T14a session-start did not emit both overlay and anchor"; exit 1
fi

# T14b: take-a-beat's SessionStart/compact branch also emits the anchor.
beat_out="$(printf '%s' "$dc_stdin" | bash "$BEAT")"
beat_ctx="$(jq -r '.hookSpecificOutput.additionalContext // ""' <<<"$beat_out")"
if grep -qF "T14-COMPACT-REQUEST" <<<"$beat_ctx"; then
  echo "PASS: T14b take-a-beat on source=compact also re-injects the anchor (intentional idempotent double-restore)"
else
  echo "FAIL: T14b take-a-beat did not re-inject the anchor on source=compact"; exit 1
fi
rm -rf "$dc_tmp"
