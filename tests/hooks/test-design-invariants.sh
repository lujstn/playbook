#!/usr/bin/env bash
# Regression lock for the v2 canonical design surface. The source of truth is
# the shipped surface: hooks/session-start (the overlay), hooks/take-a-beat,
# hooks/hooks.json, scripts/notify, and the skills/ tree. docs/ was deleted in
# v2; all assertions now target the live implementation, not documentation.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
SS="$root/hooks/session-start"
TB="$root/hooks/take-a-beat"
HJ="$root/hooks/hooks.json"
SN="$root/scripts/notify"
SK="$root/skills"
fail=0
chk() { if eval "$1" >/dev/null 2>&1; then echo "PASS: $2"; else echo "FAIL: $2"; fail=1; fi; }

# Nine v2 tenets live in the overlay inside hooks/session-start.
n=$(grep -cE '^[1-9]\. ' "$SS" 2>/dev/null || echo 0)
[ "$n" -eq 9 ] \
  && echo "PASS: nine tenets in overlay" \
  || { echo "FAIL: found $n tenets in overlay, expected 9"; fail=1; }

# Model rule.
chk "grep -q 'execute on Sonnet' '$SS'" "model rule: execute on Sonnet"
chk "grep -q 'plan and review' '$SS'" "model rule: plan and review on Opus"

# Context-calm doctrine.
chk "grep -q 'auto-compact is seamless' '$SS'" "context-calm: auto-compact is seamless"
chk "grep -q 'Do not wrap up early' '$SS'" "context-calm: do not wrap up early"

# Marker/brand convention: the Playbook middot brand.
chk "grep -qF 'Playbook · ' '$SS'" "brand convention: Playbook middot in overlay"

# North Star dispatch line.
chk "grep -q 'playbook-northstar' '$SS'" "North Star dispatch line in overlay"

# SubagentStart as the overlay carrier.
chk "jq -e '.hooks.SubagentStart' '$HJ'" "SubagentStart wired in hooks.json (overlay carrier)"

# No-file model.
chk "grep -q 'nothing is written into your working tree' '$SS'" "no-file model stated in overlay"

# Standing North-Star override.
chk "grep -q 'Standing override' '$SS'" "standing override present in overlay"
chk "grep -q 'regardless of the unease level or the mode' '$SS'" "standing override full phrase present in overlay"

# Pushover supported in both scripts/notify and offline-mode skill.
chk "grep -qi 'pushover' '$SN'" "Pushover provider in scripts/notify"
chk "grep -qi 'pushover' '$SK/offline-mode/SKILL.md'" "Pushover referenced in offline-mode skill"

# ntfy supported in both scripts/notify and offline-mode skill.
chk "grep -qi 'ntfy' '$SN'" "ntfy provider in scripts/notify"
chk "grep -qi 'ntfy' '$SK/offline-mode/SKILL.md'" "ntfy referenced in offline-mode skill"

# Context-calm competing-hook offer lives in take-a-beat.
chk "grep -q 'playbook_competing_context_hook' '$TB'" "competing-hook offer in take-a-beat"
chk "grep -q 'context-calm' '$TB'" "context-calm channel referenced in take-a-beat"

# Negative invariants: no stale file-based state paths in the shipped surface.
chk "! grep -rqE '\\.playbook/[A-Za-z._-]' '$SS' '$SK'" "no .playbook/ path reference in overlay or skills"
chk "! grep -rq 'DESIGN\\.md' '$SS' '$SK' '$HJ'" "no stale DESIGN.md reference in shipped surface"

exit $fail
