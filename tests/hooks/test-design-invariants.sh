#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
SS="$root/hooks/session-start"
TB="$root/hooks/take-a-beat"
HJ="$root/hooks/hooks.json"
SN="$root/scripts/notify"
SK="$root/skills"
fail=0
chk() { if eval "$1" >/dev/null 2>&1; then echo "PASS: $2"; else echo "FAIL: $2"; fail=1; fi; }

n=$(awk '/The nine tenets, always live:/{t=1; next} t&&/^[1-9]\. /{n++} t&&/^$/{exit} END{print n+0}' "$SK/playbook/SKILL.md" 2>/dev/null)
[ "$n" -eq 9 ] \
  && echo "PASS: nine tenets in the engine skill" \
  || { echo "FAIL: found $n tenets in the tenets block, expected 9"; fail=1; }

chk "grep -q 'execute on Sonnet' '$SS'" "model rule: execute on Sonnet"
chk "grep -q 'plan and review' '$SS'" "model rule: plan and review on Opus"

chk "grep -qi 'auto-compact is seamless' '$TB'" "context-calm: auto-compact is seamless"
chk "grep -q 'Do not wrap up early' '$TB'" "context-calm: do not wrap up early"

chk "grep -qF '**Playbook**' '$SS'" "brand convention: bold Playbook in overlay"

chk "grep -q 'playbook-northstar' '$SS'" "North Star dispatch line in overlay"

chk "jq -e '.hooks.SubagentStart' '$HJ'" "SubagentStart wired in hooks.json (overlay carrier)"

chk "grep -q 'nothing is written into your working tree' '$SS'" "no-file model stated in overlay"

chk "grep -q 'Standing override' '$SS'" "standing override present in overlay"
chk "grep -q 'regardless of the unease level or the mode' '$SS'" "standing override full phrase present in overlay"

chk "grep -qi 'pushover' '$SN'" "Pushover provider in scripts/notify"
chk "grep -qi 'pushover' '$SK/offline-mode/SKILL.md'" "Pushover referenced in offline-mode skill"

chk "grep -qi 'ntfy' '$SN'" "ntfy provider in scripts/notify"
chk "grep -qi 'ntfy' '$SK/offline-mode/SKILL.md'" "ntfy referenced in offline-mode skill"

chk "grep -q 'playbook_competing_context_hook' '$TB'" "competing-hook offer in take-a-beat"
chk "grep -q 'context-calm' '$TB'" "context-calm channel referenced in take-a-beat"

chk "! grep -rqE '\\.playbook/[A-Za-z._-]' '$SS' '$SK'" "no .playbook/ path reference in overlay or skills"
chk "! grep -rq 'DESIGN\\.md' '$SS' '$SK' '$HJ'" "no stale DESIGN.md reference in shipped surface"

exit $fail
