#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
P="$root/plan-a-design.md"
fail=0
chk() { if eval "$1" >/dev/null 2>&1; then echo "PASS: $2"; else echo "FAIL: $2"; fail=1; fi; }
chk "! grep -qi 'uncertainty' '$P'" "concept renamed to unease everywhere including Appendix A"
chk "! grep -qE '\.playbook/[A-Za-z._-]' '$P'" "no .playbook/ path references"
chk "! grep -qi 'uncertainty-ledger\\|pinned anchor file' '$P'" "section 6 no longer file-based"
chk "! grep -qiE 'unease ledger|the unease ledger' '$P'" "plan-a no surviving ledger-mechanism phrasing"
chk "grep -q 'ntfy' '$P'" "tenet 5 ntfy adaptation preserved"
chk "grep -qi '65% context\\|65 percent context\\|sixty-five percent' '$P'" "tenet 7 context adaptation preserved"
chk "grep -qi 'external manager' '$P'" "tenet 3 external-manager adaptation preserved"
chk "perl -CSD -ne 'exit 1 if /\\x{2014}|\\x{2013}/' '$P'" "no long dashes (perl -CSD is sound and host-portable; grep -P is absent on BSD grep)"
exit $fail
