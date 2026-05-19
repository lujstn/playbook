#!/usr/bin/env bash
# Regression lock for the canonical spec, DESIGN.md. It is the source of
# truth (build constraint, section 13) yet had no direct test coverage.
# DESIGN.md legitimately names the options it rejects (the rejected ledger,
# the word "uncertainty" inside the naming directive), so this checks
# positive load-bearing invariants plus only the negatives that genuinely
# hold, not the blanket word bans that suit the skill text.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
D="$root/DESIGN.md"
fail=0
chk() { if eval "$1" >/dev/null 2>&1; then echo "PASS: $2"; else echo "FAIL: $2"; fail=1; fi; }

# No state file in the user's tree; no stale .playbook/ path or lowercase name.
chk "! grep -qE '\\.playbook/[A-Za-z._-]' '$D'" "no .playbook/ path reference"
chk "! grep -qE '(^|[^-])design\\.md' '$D'" "no bare lowercase design.md self-reference"
chk "grep -qi 'Playbook writes no file into the user' '$D'" "no-file model stated"

# Unease naming directive (the single sanctioned change to Appendix A).
chk "grep -qi 'the concept is .unease., never .uncertainty. or .anxiety.' '$D'" "unease naming directive present"

# The sanctioned tenet adaptations (build constraint, section 13).
chk "grep -q 'ntfy' '$D'" "tenet 5 ntfy adaptation preserved"
chk "grep -qiE 'sixty-five percent|65 percent' '$D'" "tenet 7 context adaptation preserved"
chk "grep -qi 'external manager' '$D'" "tenet 3 external-manager adaptation preserved"

# Appendix A canonical clause.
chk "grep -q 'Appendix A' '$D' && grep -qi 'canonical' '$D'" "Appendix A marked canonical"

# The shipped subagent and window mechanism must not silently drift from the
# code: these are the load-bearing claims this work made true.
chk "grep -q 'SubagentStart' '$D'" "SubagentStart overlay carrier documented"
chk "grep -q 'playbook-northstar' '$D'" "project North Star dispatch line documented"
chk "grep -qi 'self-healing notice' '$D'" "self-healing undeclared-window notice documented"
chk "grep -qi 'role-anchored' '$D'" "role-anchored window parse documented"
chk "grep -qi 'SubagentStop' '$D'" "the SubagentStop unease limitation stated plainly"

exit $fail
