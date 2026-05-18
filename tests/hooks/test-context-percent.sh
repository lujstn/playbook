#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
source "$root/hooks/lib/playbook-common.sh"

# Fixture represents 700000/1000000 used, encoded GSD-bridge style as
# remaining_percentage=30 (used = 100 - 30 = 70). The fixture deliberately
# carries a WRONG used_pct=99 so a correct implementation must derive used
# from remaining_percentage, not echo a precomputed used field.
export PLAYBOOK_CTX_FIXTURE="$root/tests/hooks/fixtures/ctx-used-70.json"
got="$(playbook_context_percent)"
[ "$got" = "70" ] && echo "PASS: 70% used parsed" || { echo "FAIL: got '$got'"; exit 1; }

# Inversion guard: a GSD-shaped fixture with remaining_percentage=35 MUST
# yield 65 (used), proving used = 100 - remaining is applied. This is the
# regression test for review finding M3.
export PLAYBOOK_CTX_FIXTURE="$root/tests/hooks/fixtures/ctx-remaining-35.json"
got="$(playbook_context_percent)"
[ "$got" = "65" ] && echo "PASS: remaining=35 -> used=65 (no inversion)" || { echo "FAIL inversion: got '$got'"; exit 1; }

# Absent signal must yield empty, never a wrong number. Both signal paths are
# cleared so this is deterministic offline AND when run inside a live Claude
# session (where CLAUDE_CODE_SESSION_ID points at a real, populated bridge
# file). With no fixture and no session id there is no source -> empty.
unset PLAYBOOK_CTX_FIXTURE
unset CLAUDE_CODE_SESSION_ID
[ -z "$(playbook_context_percent)" ] && echo "PASS: silent when unknown" || { echo "FAIL: not silent"; exit 1; }
