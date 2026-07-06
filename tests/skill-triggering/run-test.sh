#!/usr/bin/env bash
# Skill-trigger integration check: drives the real claude CLI against the
# plugin tree and asserts the prompt invoked the named skill. Requires the CLI
# and a live auth. When the CLI is absent or unauthenticated the check prints
# SKIP and exits 0 so a clean local or CI run shows SKIP, never a misleading
# FAIL. A genuine invocation error (bad flags, usage error) FAILs loudly, as
# does the meaningful regression: CLI ran, skill did not trigger.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
skill="$1"; prompt_file="$2"; max="${3:-6}"
prompt="$(cat "$root/tests/skill-triggering/prompts/$prompt_file")"

if ! command -v claude >/dev/null 2>&1; then
  echo "SKIP: '$prompt_file' (claude CLI not on PATH)"; exit 0
fi

err="$(mktemp)"
set +e
# stream-json requires --verbose on the CLI; without it the CLI errors out and
# every run would masquerade as a SKIP. Capture stderr separately so an auth
# failure can SKIP while a genuine usage error FAILs.
out="$(claude -p "$prompt" --plugin-dir "$root" --dangerously-skip-permissions \
  --max-turns "$max" --output-format stream-json --verbose 2>"$err")"
ec=$?
set -e
errtxt="$(cat "$err" 2>/dev/null || true)"; rm -f "$err"

# Classify from the captured stream, not the exit code: hitting --max-turns
# exits non-zero yet still yields a valid stream we can score.
if [ -z "$out" ]; then
  if grep -qiE 'auth|login|credit|balance|rate limit|overloaded|api error|unavailable' <<<"$errtxt"; then
    echo "SKIP: '$prompt_file' (claude CLI unauthenticated or unavailable)"; exit 0
  fi
  echo "FAIL: '$prompt_file' produced no output (ec=$ec): ${errtxt:-<empty stderr>}"; exit 1
fi

if grep -qE "\"(skill|name)\":\"(playbook:)?${skill}\"" <<<"$out"; then
  echo "PASS: '$prompt_file' triggered $skill"
else
  echo "FAIL: '$prompt_file' did not trigger $skill"; exit 1
fi
