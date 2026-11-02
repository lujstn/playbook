#!/usr/bin/env bash
set -uo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
rs="$root/tests/routing-shape"
fail=0
pass() { echo "PASS: $1"; }
flunk() { echo "FAIL: $1"; fail=1; }
eq() { if [ "$2" = "$3" ]; then pass "$1"; else flunk "$1 (expected [$2], got [$3])"; fi }

# row <fixture> <column number>
col() { bash "$rs/classify.sh" "$rs/fixtures/$1.jsonl" 2>/dev/null | cut -f"$2"; }
# decision <fixture> -> marker/source/shortlist
dec() { printf '%s/%s/%s' "$(col "$1" 2)" "$(col "$1" 8)" "$(col "$1" 9)"; }

eq "picker: the Recommended option is the mode, the shortlist is every option" "interns/picker/interns,lone-wolf,workflows" "$(dec picker-interns)"
eq "picker: 'Lone wolf' reads as lone-wolf" "lone-wolf/picker/interns,lone-wolf" "$(dec picker-lonewolf)"
eq "picker: emoji prefixes and a singular Workflow label are read" "interns/picker/interns,lone-wolf,workflows" "$(dec picker-emoji-labels)"
eq "picker: read from the second question of a batched call" "workflows/picker/interns,lone-wolf,workflows" "$(dec picker-second-question)"
eq "picker: no Recommended option is malformed" "malformed/picker/interns,lone-wolf" "$(dec picker-no-recommendation)"
eq "picker: an unrecognised Recommended label is malformed" "malformed/picker/lone-wolf" "$(dec picker-unknown-mode)"
eq "picker: the overlay canary is still required" "no" "$(col picker-void 1)"
eq "picker then a hackathon dispatch maps exact" "exact" "$(col picker-hackathon-then-dispatch 7)"
eq "picker with no dispatch after it has no map to compare" "na" "$(col picker-interns 7)"
eq "picker rows carry no emoji agreement" "na" "$(col picker-interns 3)"
eq "route command: the mode is the route and the whole shortlist" "lone-wolf/route/lone-wolf" "$(dec route-lonewolf)"
eq "route command with no dispatch maps for lone-wolf" "exact" "$(col route-lonewolf 7)"
eq "route command with an unrecognised mode is malformed" "malformed/route/-" "$(dec route-unknown)"
eq "a route line the hooks refused is skipped for the one they accepted" "lone-wolf/route/lone-wolf" "$(dec route-refused-then-accepted)"
eq "and the refused attempt is counted" "1" "$(col route-refused-then-accepted 10)"
eq "a clean route line has no refusals" "0" "$(col route-lonewolf 10)"
eq "a route line printed in reply text is read as printed" "lone-wolf/printed/lone-wolf" "$(dec route-printed)"
eq "a route line without the older leading colon is read the same" "lone-wolf/route/lone-wolf" "$(dec route-plain)"
eq "and printed in reply text too" "lone-wolf/printed/lone-wolf" "$(dec route-printed-plain)"
eq "a chained route line the hook recorded before refusing is the decision" "interns/route/interns" "$(dec route-chained-recorded)"
eq "and is not counted as a refusal" "0" "$(col route-chained-recorded 10)"
eq "the first decision in stream order wins" "interns/route/interns" "$(dec route-before-picker)"
eq "a question without the Goal: prefix is not the picker" "interns/marker/-" "$(dec non-picker-ask-then-marker)"
eq "marker line remains the fallback" "hackathon/marker/-" "$(dec marker-only)"
eq "marker fallback keeps the emoji check" "yes" "$(col marker-only 3)"
eq "an echoed route command is not a route" "censored/none/-" "$(dec bash-not-route)"
eq "a capped run with no decision is censored" "censored/none/-" "$(dec censored)"

settings="$rs/deny-dispatch.settings.json"
eq "deny settings are valid JSON" "0" "$(jq -e . "$settings" >/dev/null 2>&1; echo $?)"
matcher="$(jq -r '.hooks.PreToolUse[0].matcher' "$settings")"
for t in Agent Task Workflow SendMessage TeamCreate; do
  eq "deny settings match $t" "true" "$(jq -nr --arg t "$t" --arg m "$matcher" '$t | test($m)')"
done
for t in Bash Read Edit Skill AskUserQuestion; do
  eq "deny settings leave $t alone" "false" "$(jq -nr --arg t "$t" --arg m "$matcher" '$t | test($m)')"
done
eq "deny hook prints a deny decision" "deny" "$(bash -c "$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$settings")" | jq -r '.hookSpecificOutput.permissionDecision')"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
{
  printf 'prompt\trep\tcanary\tmarker\tagree\tbehaviour\tcost\tsubtype\tmap\tsource\tshortlist\n'
  printf 'interns\t1\tyes\tinterns\tna\tagent\t0.10\tsuccess\texact\tpicker\tinterns,lone-wolf\n'
  printf 'interns\t2\tyes\tlone-wolf\tna\tsolo\t0.10\tsuccess\texact\tpicker\tlone-wolf,workflows\n'
  printf 'lone-wolf\t1\tyes\tlone-wolf\tna\tsolo\t0.05\tsuccess\texact\troute\tlone-wolf\n'
  printf 'boundary-b\t1\tyes\tworkflows\tyes\tworkflow\t0.20\tsuccess\texact\tmarker\t-\n'
  printf 'gsd\t1\tyes\tmalformed\tno\tsolo\t0.05\tsuccess\tna\tpicker\tgsd\n'
  printf 'workflows-feature\t1\tyes\tworkflows\tna\tsolo\t0.30\tsuccess\texact\tpicker\tworkflows,interns,hackathon,lone-wolf\n'
} > "$tmp/results.tsv"
tally="$(awk -F'\t' -v teams=off -f "$rs/tally.awk" "$tmp/results.tsv")"
tally_has() { if grep -qF -- "$2" <<<"$tally"; then pass "$1"; else flunk "$1 (tally: $tally)"; fi }
tally_has "tally counts decision sources" "picker=4 route=1 marker=1 none=0"
tally_has "tally scores the recommendation against the expected set" "recommended/route in expected set    4/5"
tally_has "tally scores the shortlist against the expected set" "shortlist contains an expected mode  3/4"
tally_has "tally keeps the middle-occupancy metric" "middle-occupancy   1/2"
tally_has "tally counts pickers that offer four ranked modes" "pickers offering four ranked modes   1/4"
tally_has "tally has a row for the feature probe" "workflows-feature"

bash "$rs/make-fixture.sh" "$tmp/fixture" >/dev/null 2>&1
eq "the neutral fixture builds" "yes" "$([ -f "$tmp/fixture/lib/store.sh" ] && [ -f "$tmp/fixture/run-tests.sh" ] && echo yes || echo no)"
eq "the neutral fixture carries no Playbook vocabulary" "0" "$(grep -rli 'playbook' "$tmp/fixture" 2>/dev/null | wc -l | tr -d ' ')"

eq "the v6-shortlist doctrine version is listed" "yes" "$(grep -q 'v6-shortlist' "$rs/doctrine-versions/README.md" && echo yes || echo no)"
eq "the harness scripts parse" "0" "$(bash -n "$rs/run.sh" && bash -n "$rs/classify.sh" && bash -n "$rs/make-fixture.sh" && bash -n "$rs/validate-labels.sh"; echo $?)"

exit $fail
