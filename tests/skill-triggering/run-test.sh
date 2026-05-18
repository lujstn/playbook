#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
skill="$1"; prompt_file="$2"; max="${3:-6}"
prompt="$(cat "$root/tests/skill-triggering/prompts/$prompt_file")"
out="$(claude -p "$prompt" --plugin-dir "$root" --dangerously-skip-permissions \
  --max-turns "$max" --output-format stream-json 2>/dev/null || true)"
if grep -qE "\"(skill|name)\":\"(playbook:)?${skill}\"" <<<"$out"; then
  echo "PASS: '$prompt_file' triggered $skill"
else
  echo "FAIL: '$prompt_file' did not trigger $skill"; exit 1
fi
