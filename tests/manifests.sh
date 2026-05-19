#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
fail=0

assert() { if eval "$1" >/dev/null 2>&1; then echo "PASS: $2"; else echo "FAIL: $2"; fail=1; fi; }

assert "jq -e '.name == \"playbook\"' '$root/.claude-plugin/plugin.json'" "plugin.json name is playbook"
assert "jq -e '.version and .description and .license' '$root/.claude-plugin/plugin.json'" "plugin.json has core metadata"
assert "jq -e 'has(\"skills\") | not' '$root/.claude-plugin/plugin.json'" "plugin.json does NOT list skills (directory discovery)"
assert "jq -e '.plugins[0].name == \"playbook\" and .plugins[0].source == \"./\"' '$root/.claude-plugin/marketplace.json'" "marketplace lists playbook at ./"

assert "jq -e '.hooks.Stop[0].hooks[] | select(.command|test(\"unease\"))' '$root/hooks/hooks.json'" "Stop wired to unease"
assert "jq -e '.hooks.PostToolUse[0].hooks | map(.command) | any(test(\"unease\")) and any(test(\"take-a-beat\"))' '$root/hooks/hooks.json'" "PostToolUse wired to unease and take-a-beat"
assert "jq -e '.hooks.PreCompact and .hooks.PostCompact' '$root/hooks/hooks.json'" "PreCompact and PostCompact wired"
assert "! grep -q 'uncertainty' '$root/hooks/hooks.json'" "no uncertainty reference in hooks.json"

exit $fail
