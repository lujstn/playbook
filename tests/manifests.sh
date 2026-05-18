#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
fail=0

assert() { if eval "$1" >/dev/null 2>&1; then echo "PASS: $2"; else echo "FAIL: $2"; fail=1; fi; }

assert "jq -e '.name == \"playbook\"' '$root/.claude-plugin/plugin.json'" "plugin.json name is playbook"
assert "jq -e '.version and .description and .license' '$root/.claude-plugin/plugin.json'" "plugin.json has core metadata"
assert "jq -e 'has(\"skills\") | not' '$root/.claude-plugin/plugin.json'" "plugin.json does NOT list skills (directory discovery)"
assert "jq -e '.plugins[0].name == \"playbook\" and .plugins[0].source == \"./\"' '$root/.claude-plugin/marketplace.json'" "marketplace lists playbook at ./"

exit $fail
