#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
source "$root/hooks/lib/playbook-common.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
in="{\"cwd\":\"$tmp\"}"

playbook_anchor_init "Build X without breaking Y" "Ship X; never regress Y" "$in"
test -f "$tmp/.playbook/anchor.md" && echo "PASS: anchor created" || { echo FAIL; exit 1; }
grep -qF "Build X without breaking Y" "$tmp/.playbook/anchor.md" && echo "PASS: original request verbatim" || { echo FAIL; exit 1; }
# M8: playbook_ensure_dir must NOT have touched the project .gitignore.
[ ! -e "$tmp/.gitignore" ] && echo "PASS: no unsolicited .gitignore mutation" || { echo "FAIL: hook mutated .gitignore"; exit 1; }

playbook_ledger_append "really-unsure" "less sure I am still delivering X, because schema Y changed" "$in"
tail -1 "$tmp/.playbook/uncertainty-ledger.md" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T.*\| really-unsure \|' \
  && echo "PASS: ledger line shape" || { echo FAIL; exit 1; }
