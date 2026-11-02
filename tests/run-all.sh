#!/usr/bin/env bash
# JOBS=<n> sets how many hook test files run at once (default: CPU count); FREE=1 skips the paid skill-triggering section.
set -euo pipefail
root="$(cd "$(dirname "$0")" && pwd)"
fail=0
echo "== bash -n lint ==";   for f in "$root"/../hooks/session-start "$root"/../hooks/take-a-beat "$root"/../hooks/comment-guard "$root"/../hooks/notification "$root"/../hooks/dispatch-guard "$root"/../hooks/signal "$root"/../hooks/team-idle "$root"/../hooks/lib/playbook-common.sh "$root"/../scripts/offline "$root"/../scripts/statusline "$root"/../bin/playbook; do bash -n "$f" && echo "ok $f" || fail=1; done
echo "== manifests ==";      bash "$root/manifests.sh" || fail=1
echo "== hook silence budget =="
budget_fail=0
budget_dir="$(mktemp -d)"
for ev in Stop SubagentStop PostToolUse PreCompact Notification TeammateIdle; do
  for hk in session-start take-a-beat comment-guard notification dispatch-guard signal team-idle; do
    o="$(printf '{"hook_event_name":"%s","session_id":"budget","transcript_path":"/no/such.jsonl"}' "$ev" \
        | PLAYBOOK_STATE_DIR="$budget_dir" CLAUDE_PLUGIN_ROOT="$root/.." bash "$root/../hooks/$hk" 2>/dev/null || true)"
    if [ -n "$o" ]; then echo "FAIL: $hk emitted on unwired $ev: [$o]"; budget_fail=1; fi
  done
done
rm -rf "$budget_dir"
[ "$budget_fail" -eq 0 ] && echo "ok: every hook silent on unwired events" || fail=1
echo "== hooks =="
jobs_n="${JOBS:-$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)}"
case "$jobs_n" in ''|*[!0-9]*|0) jobs_n=1 ;; esac
hk_out="$(mktemp -d)"
trap 'kill $(jobs -p) 2>/dev/null || true; rm -rf "$hk_out"' EXIT
hk_files=("$root"/hooks/test-*.sh)
for t in "${hk_files[@]}"; do
  while [ "$(jobs -rp | wc -l)" -ge "$jobs_n" ]; do sleep 0.1; done
  ( bash "$t" > "$hk_out/$(basename "$t").out" 2>&1; echo $? > "$hk_out/$(basename "$t").rc" ) &
done
wait
for t in "${hk_files[@]}"; do
  cat "$hk_out/$(basename "$t").out"
  [ "$(cat "$hk_out/$(basename "$t").rc")" = 0 ] || fail=1
done
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
if [ -n "${FREE:-}" ]; then
  echo "== skill triggering: skipped (FREE=1, it calls the paid claude CLI) =="
else
  echo "== skill triggering (needs claude CLI + auth; SKIP otherwise) =="
  bash "$root/skill-triggering/run-test.sh" playbook non-trivial-work.txt || fail=1
  bash "$root/skill-triggering/run-test.sh" fix-mode fix-mode.txt || fail=1
  bash "$root/skill-triggering/run-test.sh" debug-mode debug-mode.txt || fail=1
  bash "$root/skill-triggering/run-test.sh" brainstorming brainstorming.txt || fail=1
fi
exit $fail
