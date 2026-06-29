#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")" && pwd)"
fail=0
echo "== bash -n lint ==";   for f in "$root"/../hooks/session-start "$root"/../hooks/take-a-beat "$root"/../hooks/unease "$root"/../hooks/lib/playbook-common.sh; do bash -n "$f" && echo "ok $f" || fail=1; done
echo "== manifests ==";      bash "$root/manifests.sh" || fail=1
echo "== hooks ==";          for t in "$root"/hooks/test-*.sh; do bash "$t" || fail=1; done
echo "== long-dash sweep =="
sweep_targets=("$root/../skills" "$root/../hooks" "$root/../scripts" "$root/../.claude-plugin")
for opt in "$root/../DESIGN.md" "$root/../README.md" "$root/../docs"; do
  [ -e "$opt" ] && sweep_targets+=("$opt")
done
if LC_ALL=C grep -rln $'\xe2\x80\x94' "${sweep_targets[@]}" 2>/dev/null \
   || LC_ALL=C grep -rln $'\xe2\x80\x93' "${sweep_targets[@]}" 2>/dev/null; then
  echo "FAIL: long dash (U+2014 or U+2013) found in shipped/spec surface"; fail=1
else
  echo "ok: no long dashes"
fi
echo "== skill triggering (needs claude CLI + auth; SKIP otherwise) =="
bash "$root/skill-triggering/run-test.sh" playbook non-trivial-work.txt || fail=1
bash "$root/skill-triggering/run-test.sh" fix-mode fix-mode.txt || fail=1
bash "$root/skill-triggering/run-test.sh" debug-mode debug-mode.txt || fail=1
bash "$root/skill-triggering/run-test.sh" brainstorming brainstorming.txt || fail=1
exit $fail
