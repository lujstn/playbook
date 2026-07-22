#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
H="$root/hooks/comment-guard"
export CLAUDE_PLUGIN_ROOT="$root"

fail=0
GUARD_OUT=""
GUARD_RC=0

guard() { GUARD_OUT="$(printf '%s' "$1" | bash "$H" 2>&1)" && GUARD_RC=0 || GUARD_RC=$?; }

payload() { # tool, path, inserted-text
  jq -cn --arg t "$1" --arg p "$2" --arg s "$3" \
    'if $t == "Write"
     then {tool_name:$t, tool_input:{file_path:$p, content:$s}}
     else {tool_name:$t, tool_input:{file_path:$p, old_string:"PLACEHOLDER", new_string:$s}} end'
}

blocks() { # label, path, text
  guard "$(payload Write "$2" "$3")"
  if [ "$GUARD_RC" -eq 2 ]; then echo "PASS: $1"; else echo "FAIL: $1 (rc=$GUARD_RC)"; fail=1; fi
}

allows() { # label, path, text
  guard "$(payload Write "$2" "$3")"
  if [ "$GUARD_RC" -eq 0 ]; then echo "PASS: $1"; else echo "FAIL: $1 (rc=$GUARD_RC) [$GUARD_OUT]"; fail=1; fi
}

TAGGED='// @nonobvious(forced-by) QStash redelivers on any 5xx so this write stays idempotent'
CODE=$'const a = 1;\nconst b = 2;\nconst c = 3;'

echo "-- the tag is mandatory"
blocks "untagged one-line comment is rejected" src/a.ts "// helper for the thing
const a = 1;"
blocks "untagged run is rejected whatever its length" src/a.ts "// one
// two
const a = 1;"
blocks "untagged block comment is rejected" src/a.ts "/**
 * Builds the thing.
 */
function f() {}"
allows "a tagged comment is accepted" src/a.ts "$TAGGED
$CODE"
allows "code carrying no comments is accepted" src/a.ts "$CODE"

echo "-- categories are a closed set"
for c in forced-by mirrors must-hold deliberately-missing means; do
  allows "category $c is accepted" src/a.ts "// @nonobvious($c) the vendor returns 200 with an error body
$CODE"
done
blocks "a category outside the set is rejected" src/a.ts "// @nonobvious(hazard) something happens here
$CODE"
guard "$(payload Write src/a.ts '// @nonobvious(hazard) something happens here
const a = 1;')"
grep -q 'unknown category "hazard"' <<<"$GUARD_OUT" \
  && echo "PASS: the message names the rejected category" \
  || { echo "FAIL: message did not name the category [$GUARD_OUT]"; fail=1; }
blocks "a tag with no reason is rejected" src/a.ts "// @nonobvious(means)
$CODE"
blocks "a tagged run over five lines is rejected" src/a.ts "// @nonobvious(must-hold) the queue depth must never exceed the pool size
// two
// three
// four
// five
// six
$CODE"

echo "-- the tag does not shield a worthless comment"
blocks "separator banner" src/a.ts "// @nonobvious(means) =========================
$CODE"
blocks "unicode box banner" src/a.ts "// @nonobvious(means) ── Events ──────────────
$CODE"
blocks "plan-step label" src/a.ts "// @nonobvious(must-hold) Step 2: build the payload
$CODE"
blocks "work narration" src/a.ts "// @nonobvious(must-hold) as requested, the retry budget is fixed
$CODE"
blocks "restating the code below" src/a.ts "// @nonobvious(means) fetch the user profile
const userProfile = await fetchUserProfile(id);
const b = 2;"

echo "-- an edit may not be more comment than code"
guard "$(payload Edit src/a.ts '// @nonobvious(must-hold) the counter must never go negative
// @nonobvious(means) a null basis is undetermined, not unchanged
// @nonobvious(forced-by) Redis caps a single key at 512MB
const a = 1;')"
[ "$GUARD_RC" -eq 2 ] && echo "PASS: three comment lines against one of code is rejected" \
  || { echo "FAIL: ratio rule did not fire (rc=$GUARD_RC)"; fail=1; }
guard "$(payload Edit src/a.ts "$TAGGED
$CODE")"
[ "$GUARD_RC" -eq 0 ] && echo "PASS: comments outnumbered by code are accepted" \
  || { echo "FAIL: ratio rule misfired [$GUARD_OUT]"; fail=1; }

echo "-- only the inserted text is judged"
guard "$(payload Edit src/a.ts "$CODE")"
[ "$GUARD_RC" -eq 0 ] && echo "PASS: a code-only edit is accepted whatever the file holds" \
  || { echo "FAIL: code-only edit blocked [$GUARD_OUT]"; fail=1; }
guard "$(jq -cn '{tool_name:"Edit", tool_input:{file_path:"src/a.ts", old_string:"// one\n// two\nconst a = 1;", new_string:"const a = 1;"}}')"
[ "$GUARD_RC" -eq 0 ] && echo "PASS: deleting comments is always allowed" \
  || { echo "FAIL: deletion blocked [$GUARD_OUT]"; fail=1; }

echo "-- the policy reaches beyond TypeScript"
blocks "swift doc comments" App/x.swift "/// Returns the user name
func name() -> String { n }"
blocks "python comments" app/x.py "# build the widget list
widgets = build()"
blocks "kotlin comments" app/x.kt "// map the response
val out = map(res)"
blocks "sql comments" db/q.sql "-- select the active rows
SELECT * FROM t WHERE active;"
blocks "css comments" web/a.css "/* the card shadow */
.card { box-shadow: 0 0 1px; }"

echo "-- what it declines to police"
allows "lint directives" src/a.ts "// eslint-disable-next-line no-console -- CLI progress
console.log(1);"
allows "a shebang" tools/x.sh "#!/usr/bin/env bash
set -e"
allows "C preprocessor directives" App/x.m "#import <Foundation/Foundation.h>
int x = 1;"
for f in docs/x.md notes.txt config.yml data.json Cargo.toml app/res.xml ios/App.xcodeproj/project.pbxproj; do
  allows "prose, data and project files ($f)" "$f" "// one
// two
// three"
done
for d in node_modules/x/y.js app/build/gen.kt Pods/A/b.m a/DerivedData/x.swift .venv/lib/x.py target/debug/x.rs; do
  allows "generated and vendored trees ($d)" "$d" "// untagged comment here
const a = 1;"
done

echo "-- it stays out of the way"
guard '{"tool_name":"Bash","tool_input":{"command":"ls"}}'
[ "$GUARD_RC" -eq 0 ] && echo "PASS: tools other than Edit and Write are ignored" \
  || { echo "FAIL: fired on Bash"; fail=1; }
for ev in Stop SubagentStop PostToolUse PreCompact Notification; do
  guard "$(printf '{"hook_event_name":"%s","session_id":"budget"}' "$ev")"
  if [ "$GUARD_RC" -eq 0 ] && [ -z "$GUARD_OUT" ]; then
    echo "PASS: silent on unwired $ev"
  else
    echo "FAIL: spoke on unwired $ev [$GUARD_OUT]"; fail=1
  fi
done
guard '{}'
[ "$GUARD_RC" -eq 0 ] && echo "PASS: an empty payload is survivable" \
  || { echo "FAIL: empty payload errored"; fail=1; }
nojq="$(mktemp -d)"
for tool in awk grep sed; do
  src="$(command -v "$tool")" && ln -s "$src" "$nojq/$tool"
done
bash_bin="$(command -v bash)"
out="$(printf '{"tool_name":"Write","tool_input":{"file_path":"src/a.ts","content":"// x\nconst a = 1;"}}' \
  | PATH="$nojq" "$bash_bin" "$H" 2>&1)" && rc=0 || rc=$?
{ [ "$rc" -eq 0 ] && [ -z "$out" ]; } && echo "PASS: fails open and stays quiet when jq is unavailable" \
  || { echo "FAIL: did not fail open without jq (rc=$rc) [$out]"; fail=1; }
rm -rf "$nojq"

echo "-- the refusal explains itself"
guard "$(payload Write src/a.ts '// helper for the thing
const a = 1;')"
for phrase in "Delete the comments" "one-line fix gets a one-line change" \
              "only comment" "forced-by" "deliberately-missing" \
              "explains what the code does"; do
  grep -qF "$phrase" <<<"$GUARD_OUT" \
    && echo "PASS: refusal carries \"$phrase\"" \
    || { echo "FAIL: refusal missing \"$phrase\""; fail=1; }
done

exit $fail
