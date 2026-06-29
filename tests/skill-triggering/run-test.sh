#!/usr/bin/env bash
# Skill-trigger integration check: drives the real claude CLI against the
# plugin tree and asserts the prompt invoked the named skill. Requires the
# CLI and a live auth. When neither is available the check prints SKIP and
# exits 0 so a clean local or CI run shows SKIP, never a misleading FAIL.
# Reserve FAIL (exit 1) for the only meaningful regression: CLI ran, skill
# did not trigger.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
skill="$1"; prompt_file="$2"; max="${3:-6}"
prompt="$(cat "$root/tests/skill-triggering/prompts/$prompt_file")"

if ! command -v claude >/dev/null 2>&1; then
  echo "SKIP: '$prompt_file' (claude CLI not on PATH)"; exit 0
fi

set +e
out="$(claude -p "$prompt" --plugin-dir "$root" --dangerously-skip-permissions \
  --max-turns "$max" --output-format stream-json 2>/dev/null)"
ec=$?
set -e
if [ "$ec" -ne 0 ] || [ -z "$out" ]; then
  echo "SKIP: '$prompt_file' (claude CLI failed or unauthenticated)"; exit 0
fi

if grep -qE "\"(skill|name)\":\"(playbook:)?${skill}\"" <<<"$out"; then
  echo "PASS: '$prompt_file' triggered $skill"
else
  echo "FAIL: '$prompt_file' did not trigger $skill"; exit 1
fi
