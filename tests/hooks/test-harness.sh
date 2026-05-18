#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
bash -n "$root/hooks/run-hook.cmd" 2>/dev/null && echo "PASS: run-hook.cmd parses as bash" || { echo "FAIL: run-hook.cmd"; exit 1; }
jq -e '.hooks | type == "object"' "$root/hooks/hooks.json" >/dev/null && echo "PASS: hooks.json valid" || { echo "FAIL: hooks.json"; exit 1; }
bash -n "$root/hooks/lib/playbook-common.sh" && echo "PASS: playbook-common.sh parses" || { echo "FAIL: lib"; exit 1; }
