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

assert "! jq -e '.hooks.Stop' '$root/hooks/hooks.json'" "nothing registered on Stop (the pulse seam is removed)"
assert "! jq -e '.hooks.SubagentStop' '$root/hooks/hooks.json'" "nothing registered on SubagentStop"
assert "! jq -e '.hooks.PostToolUse' '$root/hooks/hooks.json'" "nothing registered on PostToolUse (per-tool cost removed)"
assert "jq -e '.hooks.PostToolBatch[0].hooks | map(.command) | any(test(\"take-a-beat\"))' '$root/hooks/hooks.json'" "PostToolBatch wired to take-a-beat"
assert "jq -e '.hooks.PostToolUseFailure[0].hooks | map(.command) | any(test(\"take-a-beat\"))' '$root/hooks/hooks.json'" "PostToolUseFailure wired to take-a-beat"
assert "jq -e '.hooks.UserPromptSubmit[0].hooks | map(.command) | any(test(\"take-a-beat\"))' '$root/hooks/hooks.json'" "UserPromptSubmit wired to take-a-beat"
assert "! grep -q 'unease' '$root/hooks/hooks.json'" "no unease reference remains in hooks.json"
assert "! jq -e '.hooks.PreCompact or .hooks.PostCompact' '$root/hooks/hooks.json'" "PreCompact and PostCompact not registered (dead seam removed)"
assert "jq -e '.hooks.SessionStart[0].matcher | test(\"compact\")' '$root/hooks/hooks.json'" "SessionStart matcher includes compact (real re-anchor seam)"
assert "! grep -q 'uncertainty' '$root/hooks/hooks.json'" "no uncertainty reference in hooks.json"
assert "[ -d '$root/commands' ]" "commands/ directory exists"
assert "[ -f '$root/commands/fix.md' ]" "commands/fix.md present"
assert "[ -f '$root/commands/workflow.md' ]" "commands/workflow.md present"
assert "[ -f '$root/commands/pb.md' ]" "commands/pb.md present (heartbeat shorthand)"
assert "[ -f '$root/commands/playbook.md' ]" "commands/playbook.md present (heartbeat)"
assert "[ -f '$root/skills/setup/SKILL.md' ]" "setup skill present"
assert "[ -z \"\$(ls '$root'/commands/pb-*.md 2>/dev/null)\" ]" "no pb-* command files remain (plain and playbook: forms only)"
assert "grep -q 'disable-model-invocation: true' '$root/commands/workflow.md'" "workflow.md is user-only (disable-model-invocation: the Workflow-tool opt-in)"

exit $fail
