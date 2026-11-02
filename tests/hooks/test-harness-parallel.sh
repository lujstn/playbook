#!/usr/bin/env bash
# Proves the routing-shape runner's parallel mode with a stub claude: no CLI, no spend.
set -uo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
RUN="$root/tests/routing-shape/run.sh"
fail=0
pass()  { echo "PASS: $1"; }
flunk() { echo "FAIL: $1"; fail=1; }
eq()    { if [ "$2" = "$3" ]; then pass "$1"; else flunk "$1 (expected [$2], got [$3])"; fi }

command -v rsync >/dev/null || { echo "SKIP: rsync not installed"; exit 0; }
command -v jq    >/dev/null || { echo "SKIP: jq not installed"; exit 0; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin"
SLEEP=4
cat > "$T/bin/claude" <<STUB
#!/usr/bin/env bash
[ "\${1:-}" = "--version" ] && { echo "0.0.0 (stub)"; exit 0; }
pwd >> "\$STUB_LOG"
printf '%s\0' "\$@" > "\$STUB_LOG.args.\$\$"
sleep $SLEEP
echo '{"type":"system","subtype":"init","additional":"PLAYBOOK_OVERLAY present"}'
echo '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"t1","name":"Bash","input":{"command":"playbook route interns stub"}}]}}'
echo '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"t2","name":"Agent","input":{"description":"x","prompt":"y"}}]}}'
echo '{"type":"result","subtype":"success","total_cost_usd":0.01}'
STUB
chmod +x "$T/bin/claude"
export STUB_LOG="$T/pwds"; : > "$STUB_LOG"

s=$SECONDS
OUT="$(PATH="$T/bin:$PATH" JOBS=3 bash "$RUN" 3 4 interns 2>&1)"; rc=$?
wall=$(( SECONDS - s ))

eq "the run exits cleanly" "0" "$rc"
rows="$(grep -E '^  interns +#[0-9]+ +marker=' <<<"$OUT")"
eq "three result rows are printed" "3" "$(grep -c . <<<"$rows")"
eq "the rows are in rep order" "1 2 3" "$(sed -E 's/^ +interns +#([0-9]+).*/\1/' <<<"$rows" | tr '\n' ' ' | sed 's/ $//')"
eq "every row is classified interns via route" "3" "$(grep -c 'marker=interns  *via=route' <<<"$rows")"
eq "every row maps exact" "3" "$(grep -c 'map=exact' <<<"$rows")"
eq "a progress line is printed for each finished probe" "3" "$(grep -cE '^  done interns +#[0-9]+ +[0-9]+s$' <<<"$OUT")"
eq "each probe ran in its own work directory" "3" "$(sort -u "$STUB_LOG" | grep -c .)"
eq "the tally counts all three" "3" "$(grep -c '^interns	' "$(sed -n 's/^results: //p' <<<"$OUT")" 2>/dev/null)"
[ "$wall" -lt $(( SLEEP * 3 )) ] && pass "wall time ${wall}s is below three serial sleeps ($(( SLEEP * 3 ))s)" \
  || flunk "wall time ${wall}s is not below three serial sleeps ($(( SLEEP * 3 ))s)"
args="$(cat "$STUB_LOG".args.* | tr '\0' '\n')"
eq "each probe gets the picker host as its permission host" "3" "$(grep -cx 'mcp__picker__answer' <<<"$args")"
eq "and only that MCP server" "3" "$(grep -cx -- '--strict-mcp-config' <<<"$args")"
cfg="$(grep -A1 -x -- '--mcp-config' <<<"$args" | grep -v -x -- '--mcp-config' | grep -v -x -- '--' | head -1)"
eq "the MCP config launches picker-host.py" "picker-host.py" "$(jq -r '.mcpServers.picker.args[1]' "$cfg" 2>/dev/null | xargs basename 2>/dev/null)"
if grep -q "no one around" <<<"$args"; then flunk "by default the prompt still says nobody is around"; else pass "by default the prompt leaves out the absent-user sentence"; fi
rm -f "$STUB_LOG".args.*
OUT="$(PATH="$T/bin:$PATH" AWAY=1 JOBS=1 bash "$RUN" 1 4 interns 2>&1)"
args="$(cat "$STUB_LOG".args.* | tr '\0' '\n')"
if grep -q "There's no one around to answer questions, so make sensible assumptions and go." <<<"$args"; then pass "AWAY=1 appends the absent-user sentence"; else flunk "AWAY=1 did not append the absent-user sentence"; fi
grep -q 'away=on' <<<"$OUT" && pass "the header reports away=on" || flunk "the header does not report away=on"
for f in "$root"/tests/routing-shape/prompts/*.txt; do
  if grep -q "no one around" "$f"; then flunk "$(basename "$f") still says nobody is around"; fi
done
pass "no prompt file carries the absent-user sentence"
if grep -q 'BUDGET' "$RUN"; then flunk "run.sh still mentions BUDGET"; else pass "run.sh no longer mentions BUDGET"; fi
if grep -q 'max-budget-usd' "$RUN"; then flunk "run.sh still passes --max-budget-usd"; else pass "run.sh no longer passes --max-budget-usd"; fi

exit $fail
