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

echo "-- comment markers are keyed to the language, not applied blindly"
allows "C pointer store is not a comment" src/a.c "*out = compute();
return out;"
allows "wrapped multiplication is not a comment" src/a.c "total = a
    * b;"
allows "C decrement statement is not a comment" src/a.c "--count;
process();"
allows "shell flag continuation is not a comment" scripts/notify "    --level)
    shift;;"
allows "bare C# region is not a comment" src/a.cs "#region Helpers
void F(){}"
allows "python floor division is not a comment" app/x.py "result = (a
          // b)"
allows "ruby percent literal is not a comment" app/x.rb "tags = %w[a b]
x = 1"
allows "a JS private field is not a comment" src/a.ts "this.#count = 0;
return this.#count;"
blocks "but SQL really does use -- for comments" db/q.sql "-- select the rows
SELECT * FROM t;"
blocks "and SCSS really does use // for comments" web/a.scss "// the accent colour
\$accent: #f00;"
blocks "and LaTeX really does use % for comments" paper/x.tex "% the abstract
\\begin{abstract}"

echo "-- a symbol-heavy reason is not a banner"
allows "must-hold with array and boolean symbols" src/a.c "// @nonobvious(must-hold) len(head) + len(tail) == len(all)
int a = 1;"
allows "must-hold with comparison operators" src/a.c "// @nonobvious(must-hold) a[i] != b[j] && c[k]
int a = 1;"

echo "-- the ratio rule counts a comment-only edit as all comment, no code"
guard "$(payload Edit src/a.ts '// @nonobvious(means) alpha
// @nonobvious(means) beta
// @nonobvious(means) gamma')"
[ "$GUARD_RC" -eq 2 ] && echo "PASS: three comments against zero code is rejected" \
  || { echo "FAIL: comment-only edit slipped through (rc=$GUARD_RC)"; fail=1; }

echo "-- every line of a comment run is judged, not only the first"
PAD=$'const a = 1;\nconst b = 2;\nconst c = 3;'
blocks "narration after a valid tag" src/a.ts "// @nonobvious(means) a genuine reason for the value
// as requested, we decided to ship this anyway
$PAD"
blocks "a banner after a valid tag" src/a.ts "// @nonobvious(means) a genuine reason for the value
// =====================================
$PAD"
blocks "restatement after a valid tag" src/a.ts "// @nonobvious(means) a genuine reason for the value
// fetch the user profile
const userProfile = await fetchUserProfile(id);
$PAD"

echo "-- trailing comments are refused, but not markers inside strings"
blocks "a trailing line comment" src/a.ts "const a = 1; // just narrating this"
blocks "a trailing block comment" src/a.ts "const a = 1; /* narrating this */"
blocks "a trailing hash comment" app/x.py "x = build()  # narrating this"
allows "a URL inside a string is not a comment" src/a.ts "const u = \"http://example.com/a//b\";
const x = 1;"
allows "a hash inside a string is not a comment" app/x.py "s = 'a # b'
x = 1"
allows "a marker inside a template literal is not a comment" src/a.ts "const u = \`http://\${host}//p\`;
const x = 1"
allows "a trailing lint directive is allowed" src/a.ts "console.log(1); // eslint-disable-line no-console"
allows "a trailing type-ignore is allowed" app/x.py "x = untyped()  # type: ignore"

echo "-- block-form lint directives are allowed"
allows "a single-line eslint block directive" src/a.ts "/* eslint-disable */
const a = 1;"

echo "-- untouched comments already in the file are never held against you"
guard "$(jq -cn '{tool_name:"Edit", tool_input:{file_path:"src/a.ts", old_string:"// legacy note\nfoo();", new_string:"// legacy note\nbar();"}}')"
[ "$GUARD_RC" -eq 0 ] && echo "PASS: an unchanged legacy comment carried as an anchor is ignored" \
  || { echo "FAIL: unchanged comment was judged (rc=$GUARD_RC) [$GUARD_OUT]"; fail=1; }
guard "$(jq -cn '{tool_name:"Edit", tool_input:{file_path:"src/a.ts", old_string:"// legacy note\nfoo();", new_string:"// a reworded note\nbar();"}}')"
[ "$GUARD_RC" -eq 2 ] && echo "PASS: but a reworded comment is judged as new" \
  || { echo "FAIL: reworded comment escaped judgement (rc=$GUARD_RC)"; fail=1; }

echo "-- non-ASCII content never crashes the guard into failing open"
blocks "an untagged comment above a CJK string still blocks" src/a.ts "// explains the greeting
const s = \"$(printf '\xe4\xbd\xa0\xe5\xa5\xbd')\";"
allows "accented code with no comment is accepted" src/a.ts "const nom = \"caf$(printf '\xc3\xa9')\";
const x = 1;"
blocks "a unicode box banner is still a banner" src/a.ts "// @nonobvious(means) $(printf '\xe2\x94\x80\xe2\x94\x80') Events $(printf '\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80')
int a=1;"

echo "-- config and ignore files are left alone"
for f in .gitignore .dockerignore .env .env.local CODEOWNERS; do
  allows "config file $f is not policed" "$f" "# a plain comment
value"
done

exit $fail
