#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
fail=0

assert() { if eval "$1" >/dev/null 2>&1; then echo "PASS: $2"; else echo "FAIL: $2"; fail=1; fi; }

assert "jq -e '.name == \"playbook\"' '$root/.claude-plugin/plugin.json'" "plugin.json name is playbook"
assert "jq -e '.version and .description and .license' '$root/.claude-plugin/plugin.json'" "plugin.json has core metadata"
assert "jq -e 'has(\"skills\") | not' '$root/.claude-plugin/plugin.json'" "plugin.json does NOT list skills (directory discovery)"
assert "jq -e '.plugins[0].name == \"playbook\" and .plugins[0].source == \"./\"' '$root/.claude-plugin/marketplace.json'" "marketplace lists playbook at ./"
assert "[ \"\$(jq -r '.version' '$root/.claude-plugin/plugin.json')\" = \"\$(jq -r '.plugins[0].version' '$root/.claude-plugin/marketplace.json')\" ]" "plugin.json and marketplace.json versions match"

assert "jq -e '.hooks.Stop[0].hooks[] | select(.command|test(\"unease\"))' '$root/hooks/hooks.json'" "Stop wired to unease"
assert "jq -e '.hooks.SubagentStop[0].hooks[] | select(.command|test(\"unease\"))' '$root/hooks/hooks.json'" "SubagentStop wired to unease"
assert "jq -e '.hooks.PostToolUse[0].hooks | map(.command) | any(test(\"take-a-beat\"))' '$root/hooks/hooks.json'" "PostToolUse wired to take-a-beat"
assert "! jq -e '.hooks.PostToolUse[0].hooks | map(.command) | any(test(\"unease\"))' '$root/hooks/hooks.json'" "PostToolUse not wired to unease"
assert "jq -e '.hooks.PreCompact and .hooks.PostCompact' '$root/hooks/hooks.json'" "PreCompact and PostCompact wired"
assert "! grep -q 'uncertainty' '$root/hooks/hooks.json'" "no uncertainty reference in hooks.json"
assert "[ -d '$root/commands' ]" "commands/ directory exists"
assert "[ -f '$root/commands/pb-fix.md' ]" "commands/pb-fix.md present (dual-name command)"
assert "[ -f '$root/commands/fix.md' ]" "commands/fix.md present (dual-name command)"

exit $fail
