#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/payloads.sh"

# --- channel: route ---------------------------------------------------------
iso; d="$(sd r)"
chan r 'playbook route lone-wolf single coherent change'
eq "route is approved" allow "$(decision_of)"
eq "the first route says the session has started, as its output" '📚 Playbook session started · building with 🐺 lone-wolf' "$(ran_of)"
eq "route mode stored" lone-wolf "$(st "$d" route_mode)"
eq "route reason stored" "single coherent change" "$(st "$d" route_reason)"
chan r 'playbook route Interns parallel lanes'
eq "a mode is canonicalised" interns "$(st "$d" route_mode)"
chan r 'playbook route bogus nothing'
eq "an unknown mode is denied" deny "$(decision_of)"
has "the denial carries the usage line" "usage: playbook status | route"
chan r 'playbook route interns go; rm -rf /'
eq "a chained command is never approved: Claude Code's own permission check decides it" "" "$(decision_of)"
eq "and the route is still recorded" "go" "$(st "$d" route_reason)"
chan r 'playbook route interns $(whoami)'
eq "an expansion never reaches the shell: only Playbook's own printf runs" '📚 Playbook route changed · building with 🐜 interns' "$(ran_of)"
eq "and a later route is named as a change of route" "whoami" "$(st "$d" route_reason)"
chan r ': playbook route interns older spelling'
eq "the older spelling with a leading colon is read the same" "older spelling" "$(st "$d" route_reason)"
eq "and approved" allow "$(decision_of)"
chan r 'playbook frobnicate'
silent "an unknown word is never refused: Playbook's own command answers it"
OUT="$(bash "$root/bin/playbook" frobnicate 2>&1)"; RC=$?
eq "with a failing exit" 1 "$RC"
has "naming the word and the help" "playbook: unknown command 'frobnicate'. Run \`playbook help\` for the usage."
chan r 'ls -la'
silent "a plain Bash command gets no output"
eq "a plain Bash command exits 0" 0 "$RC"

# --- channel: helpers may not route ----------------------------------------
for sub in 'done' 'interface /tmp/x' 'route interns x' 'goal interns x' 'unease uneasy x' 'decision "x"' 'rethink x'; do
  chan r "playbook $sub" helper1
  eq "a helper's '$sub' is denied" deny "$(decision_of)"
done
has "the helper denial says why" "helpers don't route; your brief is your task"

# --- channel: teammate declarations ----------------------------------------
iso; d="$(sd t)"
chan t 'playbook part-done backend' helper1
eq "part-done is approved from a helper" allow "$(decision_of)"
eq "part-done is recorded for the named teammate" part-done "$(st "$(playbook_team_dir '{"session_id":"t"}' backend)" declared)"
chan t 'playbook waiting web on backend the API shape' helper2
eq "waiting is approved from a helper" allow "$(decision_of)"
td="$(playbook_team_dir '{"session_id":"t"}' web)"
eq "waiting is recorded" waiting "$(st "$td" declared)"
eq "waiting names the colleague and the thing" "backend the API shape" "$(st "$td" waiting_on)"
chan t 'playbook waiting web backend' helper2
eq "waiting without 'on' is denied" deny "$(decision_of)"
post t PostToolUse SendMessage '{"to":"web","message":"BLOCKING: interface change"}' '{}' helper1
eq "a SendMessage clears the recipient's waiting mark" "" "$(st "$td" declared)"
eq "and the stale waiting_on" "" "$(st "$td" waiting_on)"
post t PostToolUse SendMessage '{"to":"backend","message":"hi"}' '{}'
eq "a message to a part-done teammate keeps its mark" part-done "$(st "$(playbook_team_dir '{"session_id":"t"}' backend)" declared)"

# --- channel: decision ------------------------------------------------------
iso; d="$(sd dc)"
chan dc 'playbook decision "merge at high confidence"'
eq "a decision with words the user never said is denied" deny "$(decision_of)"
has "the denial names the problem" "these words are not in the user's own messages"
say dc "Please merge at high confidence only, and tell me first."
chan dc 'playbook decision "merge at high confidence"'
eq "a decision quoting the user's words is approved" allow "$(decision_of)"
eq "and stored verbatim" "1. \"merge at high confidence\"" "$(playbook_decisions_text "$d")"
chan dc 'playbook decision "MERGE at   high confidence"'
eq "matching ignores case and spacing" allow "$(decision_of)"
chan dc 'playbook decision merge at high confidence'
eq "an unquoted decision is denied" deny "$(decision_of)"
chan dc 'playbook decision "merge $(date)"'
eq "an expansion inside a decision is denied" deny "$(decision_of)"

# --- channel: unease, rethink, done, interface -----------------------------
iso; d="$(sd u)"
chan u 'playbook unease uneasy the plan keeps growing'
eq "unease is approved" allow "$(decision_of)"
eq "an uneasy self-report floors the score at 5.0" 50 "$(score_of "$d")"
eq "and sets the rethink gate" rethink "$(playbook_gate "$d")"
has "the rethink instruction rides along as context" "playbook rethink"
eq "unease shows the user the line" '🌡️ Playbook · unease: uneasy · the plan keeps growing' "$(ran_of)"
chan u 'playbook unease panicked x'
eq "an unknown level is denied" deny "$(decision_of)"
chan u 'playbook unease alarmed too deep'
eq "alarmed sets the ask gate" ask "$(playbook_gate "$d")"
eq "and the score drops back to 5.0 once the user is asked" 50 "$(score_of "$d")"
playbook_state_put "$d" score10=120 level=2
chan u 'playbook unease uneasy lower'
eq "a self-report never lowers the score" 120 "$(score_of "$d")"

iso; d="$(sd rt)"
chan rt 'playbook unease uneasy drifting'
pre_edit rt /tmp/a.txt
eq "a rethink gate blocks a main-thread edit" deny "$(decision_of)"
has "the block says how to clear it" 'playbook rethink <what changes>'
chan rt 'playbook rethink'
eq "rethink needs text" deny "$(decision_of)"
chan rt 'playbook rethink drop the second parser'
eq "rethink is approved" allow "$(decision_of)"
eq "rethink clears the gate" "" "$(playbook_gate "$d")"
pre_edit rt /tmp/a.txt
silent "the edit is then allowed"
pre_edit rt /tmp/a.txt helper1
silent "a helper is never held by the main thread's gate"

iso; d="$(sd dn)"
playbook_ns_confirm "$d" "ship the thing" lone-wolf picker
chan dn 'playbook done'
eq "done is approved" allow "$(decision_of)"
eq "done marks the North Star complete" done "$(playbook_ns_state "$d")"

iso; d="$(sd if)"; f="$d/interface/api.md"; mkdir -p "$d/interface"; echo v1 > "$f"
chan if "playbook interface api.txt"
eq "interface is approved" allow "$(decision_of)"
eq "interface is kept in Playbook's state, named after its argument" "$f" "$(st "$d" iface_path)"
eq "interface stores the hash" "$(shasum "$f" | cut -d' ' -f1)" "$(st "$d" iface_hash)"
eq "interface starts at version 1" 1 "$(st "$d" iface_ver)"
eq "its draft is made beside it from what is there" v1 "$(cat "$d/interface/api.draft.md")"
chan if "playbook interface api"
eq "declaring it again keeps the version" 1 "$(st "$d" iface_ver)"
eq "and the content" v1 "$(cat "$f")"
chan if "playbook interface"
eq "a bare declaration names it interface" "$d/interface/interface.md" "$(st "$d" iface_path)"

# --- offline goal -----------------------------------------------------------
iso; d="$(sd g)"
chan g 'playbook goal interns build the thing'
eq "goal is denied online" deny "$(decision_of)"
: > "$d/offline"
chan g 'playbook goal interns build the thing'
eq "goal is approved offline" allow "$(decision_of)"
eq "goal confirms the North Star" "build the thing" "$(playbook_ns_goal "$d")"
eq "with the chosen mode" interns "$(st "$d" ns_mode)"
eq "sourced as offline" offline "$(st "$d" ns_source)"
eq "and logs one decision line" 1 "$(wc -l < "$d/offline-log.jsonl" | tr -d ' ')"
eq "the log line is a decision event" decision "$(jq -r .event "$d/offline-log.jsonl")"
has "the log line names the goal" "build the thing"

# --- gates ------------------------------------------------------------------
iso; d="$(sd gt)"
playbook_gate_set "$d" judge
pre_edit gt /tmp/a.txt
eq "a judge gate blocks edits" deny "$(decision_of)"
has "and says to dispatch a judge" "judge:"
playbook_state_put "$d" score10=100
post gt PostToolUse Agent '{"description":"Judge: is this sound","prompt":"x","subagent_type":"general-purpose"}' '{"content":"ok"}'
eq "a judge's return clears the judge gate" "" "$(playbook_gate "$d")"
eq "and halves the score" 50 "$(score_of "$d")"
has "and queues a one-line event" "the judge has returned"

iso; d="$(sd gt2)"
playbook_gate_set "$d" judge; playbook_state_put "$d" score10=100
post gt2 PostToolUse Agent '{"description":"look around","prompt":"x"}' '{}'
eq "an ordinary Agent return does not clear a judge gate" judge "$(playbook_gate "$d")"
post gt2 PostToolUse Agent '{"description":"x","prompt":"y","subagent_type":"codex:codex-rescue"}' '{}'
eq "codex:codex-rescue counts as a judge" "" "$(playbook_gate "$d")"
playbook_gate_set "$d" judge
post gt2 PostToolUse Agent '{"description":"judge: bg","prompt":"y","run_in_background":true}' '{}'
eq "a background judge does not clear the gate" judge "$(playbook_gate "$d")"

iso; d="$(sd ga)"
playbook_gate_set "$d" ask
pre_edit ga /tmp/a.txt
eq "an ask gate blocks edits" deny "$(decision_of)"
has "online it sends Claude to a judge first" "consult a judge before more edits"
has "and lets it ask the user if they are here" "you may ask them in AskUserQuestion instead"
: > "$d/offline"
pre_edit ga /tmp/a.txt
has "offline it says to use an outside judge" "outside judge"
say ga "carry on with the plan"
eq "the user's reply clears an ask gate" "" "$(playbook_gate "$d")"

# --- signals ----------------------------------------------------------------
iso; d="$(sd sg)"
bash_post sg 'npm test' 1 'FAIL x'
eq "a failing test adds 2.0" 20 "$(score_of "$d")"
bash_post sg 'npm test' 1 'FAIL x'
eq "the same test failing again adds 4.0" 60 "$(score_of "$d")"
bash_post sg 'npm test' 0 'ok'
eq "a pass after failing subtracts 3.0" 30 "$(score_of "$d")"

iso; d="$(sd sg2)"
post sg2 PostToolUse Bash '{"command":"go test ./..."}' '{"stdout":"x","stderr":"","exit_code":2}'
eq "a non-zero exit_code in a success payload is a failure" 20 "$(score_of "$d")"
iso; d="$(sd sg3)"
post sg3 PostToolUse Bash '{"command":"pytest"}' '{"stdout":"","stderr":"Exit code 1\nboom","interrupted":false}'
eq "stderr starting 'Exit code 1' is a failure" 20 "$(score_of "$d")"

iso; d="$(sd sg4)"
bash_post sg4 'sed -n 1,20p tests/x_test.go' 0 '--- FAIL: TestThing (0.00s)
FAIL'
eq "printing source that contains '--- FAIL' counts for nothing" 0 "$(score_of "$d")"
bash_post sg4 'go test ./... | tail -5' 0 '--- FAIL: TestThing'
eq "test output piped through tail (exit 0) is not a failure" 0 "$(score_of "$d")"
eq "and records no failed test" 0 "$(st "$d" failed_since_pass)"

iso; d="$(sd sg5)"
for i in 1 2 3; do bash_post sg5 'grep -r nothing .' 1 ''; done
eq "failing benign commands never build a streak" 0 "$(score_of "$d")"
for i in 1 2 3; do bash_post sg5 'git commit -m x' 1 'gpg failed to sign the data'; done
eq "signing failures are excluded" 0 "$(score_of "$d")"
for i in 1 2 3; do bash_post sg5 'make build' 1 'hook error: Blocked by guard'; done
eq "hook blocks are excluded" 0 "$(score_of "$d")"
for i in 1 2 3; do bash_post sg5 'make build' 1 'compile error'; done
eq "three plain failures in a row add 1.0" 10 "$(score_of "$d")"
bash_post sg5 'git commit -m done' 0 ''
eq "a commit subtracts 2.0" 0 "$(score_of "$d")"

iso; d="$(sd sg6)"
bash_post sg6 'playbook rethink go test everything' 0 ''
eq "a channel command is never scored as a test" 0 "$(score_of "$d")"
eq "or as a pass" "" "$(st "$d" failed_since_pass)"

# --- edits ------------------------------------------------------------------
iso; d="$(sd ed)"
pre_edit ed /tmp/refused.txt
eq "a PreToolUse edit alone (a refused edit) counts for nothing" "" "$( [ -f "$d/edits" ] && cat "$d/edits")"
post ed PostToolUse Edit '{"file_path":"/tmp/real.txt"}' '{}'
eq "a successful edit is logged" "/tmp/real.txt" "$(cat "$d/edits")"
post ed PostToolUseFailure Edit '{"file_path":"/tmp/failed.txt"}' '"old_string not found"'
eq "a failed edit is not logged" 1 "$(wc -l < "$d/edits" | tr -d ' ')"
playbook_state_put "$d" failed_since_pass=1
for i in 1 2 3; do post ed PostToolUse Write '{"file_path":"/tmp/churn.txt"}' '{}'; done
eq "the third edit of one file while tests fail adds 1.0 (a weak signal, full weight while the user is away)" 10 "$(score_of "$d")"

# --- subagent cap -----------------------------------------------------------
iso; d="$(sd cap)"
post cap PostToolUseFailure Agent '{"description":"x","prompt":"y"}' '"Subagent spawn limit reached for this session"'
has "the cap refusal queues a notice" "Playbook subagent cap"
has "the online notice recommends a fresh session with a handover" "fresh session with a short handover"
has "and claude -r second" "claude -r <label>"
post cap PostToolUseFailure Agent '{"description":"x","prompt":"y"}' '"Subagent spawn limit reached for this session"'
hasnt "the cap notice is one-shot" "Playbook subagent cap"
iso; d="$(sd cap2)"; : > "$d/offline"
post cap2 PostToolUseFailure Agent '{"description":"x","prompt":"y"}' '"Subagent spawn limit reached"'
has "offline the notice routes through the Workflow pool" "Workflow tool draws on a separate pool"
iso; d="$(sd cap3)"
post cap3 PostToolUse Agent '{"description":"x","prompt":"y"}' '{"content":"I read that Subagent spawn limit reached is a message"}'
silent "a successful return that merely mentions the refusal is silent"

# --- AskUserQuestion --------------------------------------------------------
iso; d="$(sd ask)"
say ask "Build me the exporter, CSV only please."
Q='{"questions":[{"question":"Goal: Ship the CSV exporter · Mode: ?","options":[{"label":"lone-wolf (Recommended)"},{"label":"interns"}]},{"question":"Run live checks?","options":[{"label":"Yes"},{"label":"No"}]}]}'
post ask PostToolUse AskUserQuestion "$Q" '{"answers":{"Goal: Ship the CSV exporter · Mode: ?":"lone-wolf (Recommended)","Run live checks?":"Run, capped at $40"}}'
eq "the picker confirms the North Star" confirmed "$(playbook_ns_state "$d")"
eq "with the goal line, mode text stripped" "Ship the CSV exporter" "$(playbook_ns_goal "$d")"
eq "and the chosen mode" lone-wolf "$(st "$d" ns_mode)"
eq "sourced as the picker" picker "$(st "$d" ns_source)"
eq "the user's words are saved verbatim" "Build me the exporter, CSV only please." "$(playbook_ns_words_text "$d")"
dt="$(playbook_decisions_text "$d")"
OUT="$dt"; has "the picker answer is recorded as a decision" 'Answer: "lone-wolf (Recommended)"'
has "with its question" "Asked: Goal: Ship the CSV exporter"
has "every other answer is recorded verbatim" 'Answer: "Run, capped at $40"'
has "with its question too" "Asked: Run live checks?"

iso; d="$(sd ask2)"
post ask2 PostToolUse AskUserQuestion '{"questions":[{"question":"Which?","options":[]}],"answers":{"Which?":"B"}}' '{}'
OUT="$(playbook_decisions_text "$d")"; has "answers in tool_input.answers are read too" 'Answer: "B"'
iso; d="$(sd ask3)"
post ask3 PostToolUse AskUserQuestion '{"questions":[{"question":"Which?"}]}' '"User has answered your questions: \"Which?\"=\"Option C\". You can now continue."'
OUT="$(playbook_decisions_text "$d")"; has "an answer string is parsed" 'Answer: "Option C"'
iso; d="$(sd ask4)"
post ask4 PostToolUse AskUserQuestion '{"questions":[{"question":"Goal: x"}]}' '{"answers":{"Goal: x":"no idea"}}'
eq "a picker answer that names no mode confirms nothing" "" "$(playbook_ns_state "$d")"

# --- hackathon regroup ------------------------------------------------------
iso; d="$(sd rg)"; f="$d/interface/PROTOCOL.md"; mkdir -p "$d/interface"; echo v1 > "$f"
crew() { playbook_team_declare '{"session_id":"rg"}' "$1" ""; }
open_() { st "$d" rg_open; }
chan rg 'playbook route hackathon interface crew'
chan rg "playbook interface $f"
echo v1b > "$f"; post rg PostToolUse Edit "{\"file_path\":\"$f\"}" '{}'
eq "the lead drafting the interface before anyone is dispatched calls no regroup" "" "$(open_)"
crew server; crew client
pre_edit rg "$SANDBOX/server.js" server
silent "outside a regroup a teammate edits its own files without reading the interface"
echo v2 > "$f"; post rg PostToolUse Edit "{\"file_path\":\"$f\"}" '{}' server
eq "a teammate's change to the interface calls a regroup" "1" "$(open_)"
OUT="$(ctx_of)"; has "the caller is told it called one" "calls everyone to regroup"
has "and to message every colleague once" "REGROUP: <what changed and why>"
post rg PostToolUse Bash '{"command":"ls"}' '{"stdout":"","exit_code":0}' client
OUT="$(ctx_of)"; has "a colleague hears of it in its next step's result, not an error" "a colleague has called everyone to regroup"
has "and that waiting is fine" "Waiting with nothing to do is fine"
post rg PostToolUse Bash '{"command":"ls"}' '{"stdout":"","exit_code":0}' client
OUT="$(ctx_of)"; hasnt "only once" "called everyone to regroup"
pre_edit rg "$SANDBOX/client.js" client
eq "a teammate's own edits are held" deny "$(decision_of)"
OUT="$(reason_of)"; has "with the way out named" "playbook aligned <your name>"
pre_edit rg "$SANDBOX/lead.md"
eq "so are the lead's" deny "$(decision_of)"
pre_edit rg "$f" server
eq "once teammates are on the crew the interface itself is never edited directly" deny "$(decision_of)"
OUT="$(reason_of)"; has "the refusal names the draft and publish" "Make your change in its draft, $d/interface/PROTOCOL.draft.md, then run \`playbook publish <what changed>\`"
pre_edit rg "$d/interface/PROTOCOL.draft.md" server
eq "the draft can be written during the regroup, for the agreed version" allow "$(decision_of)"
shell() { sig "$(jq -cn --arg c "$1" --arg a "${2:-}" '{hook_event_name:"PreToolUse",session_id:"rg",tool_name:"Bash",tool_input:{command:$c}} + (if $a != "" then {agent_id:$a} else {} end)')"; }
shell "cd /x && python3 - <<'EOF'
open('client.js','w').write('x')
EOF" client
eq "a change made through the shell is held too" deny "$(decision_of)"
OUT="$(reason_of)"; has "and says so" "through the shell as much as the Edit tool"
shell "sed -i '' s/a/b/ client.js" client
eq "so is sed -i" deny "$(decision_of)"
shell "playbook aligned client; sed -i '' s/a/b/ client.js" client
eq "and an edit chained after a playbook line" deny "$(decision_of)"
OUT="$(reason_of)"; has "with the regroup named" "the crew is regrouping"
shell "cat client.js > copy.js" client
eq "and a redirect into a file" deny "$(decision_of)"
shell "npm install left-pad"
eq "and the lead's installs" deny "$(decision_of)"
shell "cd /x && cat server.js | grep -n ws 2>&1; sed -n 1,20p a.js; ls -la >/dev/null; git diff --stat" client
silent "reading through the shell still runs"
shell "node --test server/test/*.test.js 2>&1 | tail -5" server
silent "and so do the tests"
shell 'cd /x/public && until [ -f app.js ]; do sleep 2; done; echo "app.js landed"; ls' server
silent "a wait loop, as a Monitor runs, still runs"
shell 'while true; do rm -f a.js; sleep 1; done' server
eq "but an edit inside a loop is held" deny "$(decision_of)"
shell 'if [ -f a.js ]; then cp a.js b.js; fi' server
eq "and so is one inside an if" deny "$(decision_of)"
shell "cp PROTOCOL.md PROTOCOL.draft.md" server
silent "a shell command that writes the draft is allowed"
shell "sed -i '' s/v/w/ PROTOCOL.md" server
eq "but one that writes the interface itself is held" deny "$(decision_of)"
chan rg "playbook aligned client" client
eq "approval is refused before reading the latest version" deny "$(decision_of)"
OUT="$(reason_of)"; has "and says how to read it" "the Read tool, or cat in the shell"
chan rg "playbook aligned bogus" client
eq "a name not on the crew is refused" deny "$(decision_of)"
post rg PostToolUse Bash "{\"command\":\"cat $f\"}" '{"stdout":"v2","exit_code":0}' client
chan rg "playbook aligned client" client
eq "after reading, approval is accepted" allow "$(decision_of)"
has_ran() { case "$(ran_of)" in *"$2"*) pass "$1" ;; *) flunk "$1 (shown: $(ran_of))" ;; esac; }
has_ran "and names who is still to align" "still to align: server, lead"
chan rg "playbook aligned server" server
has_ran "the caller, who wrote the latest version, may approve" "still to align: lead"
echo v3 > "$f"; post rg PostToolUse Edit "{\"file_path\":\"$f\"}" '{}' server
eq "a change while aligning clears every approval" "" "$(st "$d" rg_ok)"
OUT="$(ctx_of)"; has "and the writer is told so" "every approval so far is cleared"
eq "the regroup stays open" "1" "$(open_)"
chan rg "playbook aligned client" client
eq "an approval of an older version no longer counts" deny "$(decision_of)"
post rg PostToolUse Read "{\"file_path\":\"$f\"}" '{}' client
chan rg "playbook aligned client" client
chan rg "playbook aligned server" server
post rg PostToolUse Read "{\"file_path\":\"$f\"}" '{}'
chan rg "playbook aligned lead"
has_ran "the last approval closes the regroup" "regroup closed: everyone aligned on version"
eq "and lifts the hold" "" "$(open_)"
OUT="$(ctx_of)"; has "the last to align is told to message everyone RESUME" "RESUME: interface v"
pre_edit rg "$SANDBOX/client.js" client
silent "after the regroup edits go through again"
shell "sed -i '' s/a/b/ client.js" client
silent "and so do shell changes"
shell "git log | grep -c playbook; ls" client
silent "a command that only uses the word playbook as an argument runs"
shell "grep -n 'playbook aligned' skills/hackathon-team/SKILL.md" client
silent "a command that only mentions a channel line inside quotes runs"
chan rg "playbook aligned client" client
has_ran "aligning with no regroup open is harmless" "no regroup is open"

echo v4 > "$f"; post rg PostToolUse Edit "{\"file_path\":\"$f\"}" '{}' client
eq "any crew member can call a regroup" "1" "$(open_)"
chan rg "playbook part-done server" server
eq "part-done is refused during a regroup" deny "$(decision_of)"
OUT="$(reason_of)"; has "and one who has not aligned is told to align" "playbook aligned server"
chan rg "playbook aligned client" client
chan rg "playbook part-done client" client
eq "part-done is refused after aligning too" deny "$(decision_of)"
OUT="$(reason_of)"; has "but one who has aligned is told to wait for the RESUME" "you have aligned, so wait for the RESUME"
chan rg "playbook resume server is unresponsive" server
eq "a teammate cannot end a regroup" deny "$(decision_of)"
chan rg "playbook resume server is unresponsive"
has_ran "the lead can end a stuck regroup" "regroup ended by the lead: server is unresponsive"
eq "which lifts the hold" "" "$(open_)"
grep -q 'regroup ended by the lead' "$d/team-log.jsonl" && pass "and is logged" || flunk "not logged"
OUT="$(ctx_of)"; has "and the lead is told to message everyone" "RESUME: interface v"
playbook_team_declare '{"session_id":"rg"}' client part-done
echo v5 > "$f"; post rg PostToolUse Edit "{\"file_path\":\"$f\"}" '{}' server
chan rg "playbook aligned server" server
post rg PostToolUse Read "{\"file_path\":\"$f\"}" '{}'
chan rg "playbook aligned lead"
has_ran "a teammate that declared part-done is not counted" "regroup closed"
eq "crew messages are not counted before anyone sends one" "" "$(st "$d" crew_msgs)"
post rg PostToolUse SendMessage '{"to":"client-dev","message":"REGROUP: v5"}' '{}' aserver-1f0a9c
eq "a teammate's message to a colleague is counted for the status line" "1" "$(st "$d" crew_msgs)"
eq "with the sender named from its agent id" "server>client-dev" "$(st "$d" crew_last)"
post rg PostToolUse SendMessage '{"to":"server","message":"ok"}' '{}'
eq "a message from the lead is not counted" "1" "$(st "$d" crew_msgs)"
post rg PostToolUse SendMessage '{"to":"team-lead","message":"done"}' '{}' aserver-1f0a9c
eq "nor one to the lead, as team-lead" "1" "$(st "$d" crew_msgs)"
post rg PostToolUse SendMessage '{"to":"lead","message":"done"}' '{}' aclient-3c4d
eq "or as lead" "1" "$(st "$d" crew_msgs)"
post rg PostToolUse SendMessage '{"to":"*","message":"heads up"}' '{}' aclient-3c4d
eq "a teammate's message to everyone counts once" "2" "$(st "$d" crew_msgs)"
post rg PostToolUse SendMessage '{"to":"*","message":"all hands"}' '{}'
eq "but the lead's message to everyone does not" "2" "$(st "$d" crew_msgs)"
post rg PostToolUse SendMessage '{"to":"server","message":"hi"}' '{}' mystery-agent
eq "an agent id that names no crew member reads as a teammate and counts" "teammate>server" "$(st "$d" crew_last)"
post rg PostToolUse SendMessage '{"to":"client-dev","message":"x"}' '{}' aserver-1f0a9c
eq "and only a send that succeeded counts" "4" "$(st "$d" crew_msgs)"
post rg PostToolUseFailure SendMessage '{"to":"client-dev","message":"x"}' '"boom"' aserver-1f0a9c
eq "a failed send is not counted" "4" "$(st "$d" crew_msgs)"
chan rg 'playbook route lone-wolf one last fix'
post rg PostToolUse SendMessage '{"to":"server","message":"later"}' '{}' aclient-3c4d
eq "outside a hackathon messages are not counted" "4" "$(st "$d" crew_msgs)"
eq "leaving hackathon clears any regroup" "" "$(open_)"

# --- Stop and Notification -------------------------------------------------
iso; d="$(sd stp)"
sig '{"hook_event_name":"Stop","session_id":"stp","last_assistant_message":"Staged. Waiting on your Touch ID to commit."}'
eq "a final reply waiting on the user sets away" 1 "$(st "$d" away)"
silent "Stop never speaks"
iso; d="$(sd stp2)"
sig '{"hook_event_name":"Stop","session_id":"stp2","last_assistant_message":"All done, tests pass."}'
eq "an ordinary final reply leaves away alone" "" "$(st "$d" away)"
sig '{"hook_event_name":"Stop","session_id":"stp2","agent_id":"h1","last_assistant_message":"waiting on your approval"}'
eq "a helper's Stop is ignored" "" "$(st "$d" away)"
iso; d="$(sd ntf)"
sig '{"hook_event_name":"Notification","session_id":"ntf","notification_type":"permission_prompt","message":"x"}'
eq "a permission prompt sets away" 1 "$(st "$d" away)"
iso; d="$(sd ntf2)"
sig '{"hook_event_name":"Notification","session_id":"ntf2","notification_type":"idle_prompt"}'
eq "an idle prompt sets away" 1 "$(st "$d" away)"
iso; d="$(sd ntf3)"
sig '{"hook_event_name":"Notification","session_id":"ntf3","notification_type":"auth_success"}'
eq "other notifications leave away alone" "" "$(st "$d" away)"

# --- silence ---------------------------------------------------------------
iso
for ev in SessionStart UserPromptSubmit PostToolBatch PreCompact SubagentStop; do
  sig "$(jq -cn --arg e "$ev" '{hook_event_name:$e,session_id:"quiet"}')"
  silent "silent on unwired $ev"; eq "exits 0 on $ev" 0 "$RC"
done
sig '{"hook_event_name":"PostToolUse","session_id":"quiet"}'; silent "silent on a PostToolUse with no tool"
sig 'not json'; silent "silent on garbage"; eq "exits 0 on garbage" 0 "$RC"
sig ''; silent "silent on empty input"


# --- several parts in one command -----------------------------------------
iso; d="$(sd ml)"; say ml "Ship it on Friday. Keep the old API."
chan ml 'playbook decision "Ship it on Friday" && playbook decision "Keep the old API"'
eq "two lines in one command are both recorded" "2" "$(grep -c 'Ship it on Friday\|Keep the old API' "$d/decisions.txt")"
eq "and approved, since nothing else runs" allow "$(decision_of)"
upd() { jq -r '.hookSpecificOutput.updatedInput.command // empty' <<<"$OUT"; }
OUT="$(upd)"; has "the shell prints each line" "decision recorded: Ship it on Friday"; has "both of them" "decision recorded: Keep the old API"
chan ml 'playbook help 2>&1 | head -60; echo ---; npm view ws version'
silent "asking playbook for help is never refused, and the rest of the command runs"
for h in 'playbook --help' 'playbook -h' 'playbook' ': playbook help' 'playbook version'; do chan ml "$h"; silent "nor is: $h"; done
OUT="$(bash "$root/bin/playbook" help)"; has "Playbook's own command answers help with the usage" "usage: playbook status | route"
OUT="$(bash "$root/bin/playbook" --help)"; has "and --help" "usage: playbook status | route"
OUT="$(bash "$root/bin/playbook" route lone-wolf x)"; silent "a line it is given does nothing"
chan ml 'ls -la && playbook route lone-wolf small fix'
eq "a line after another command is recorded" "lone-wolf" "$(st "$d" route_mode)"
eq "and left to Claude Code's own permission check, since other commands run" "" "$(decision_of)"
OUT="$(shown_of)"; has "and shown to the user" "📚 Playbook session started · building with 🐺 lone-wolf"
chan ml 'playbook part-done server 2>&1 | tail -3' aserver-1a2b
OUT="$(ctx_of)"; has "Claude is told a chained line was recorded, since Playbook's own command prints nothing" "Playbook recorded: 🏁 Playbook server says its part is done"
chan ml 'cd /x && : playbook unease uneasy the plan keeps growing'
OUT="$(shown_of)"; has "the older spelling with a leading colon is recorded there too" "unease: uneasy"
chan ml "npm test
playbook rethink split the module"
OUT="$(shown_of)"; has "so is a line on a later line" "rethink: split the module"
chan ml 'echo "x; playbook done" && grep -n "playbook aligned" notes.md'
silent "a playbook line inside quotes is only a mention"
chan ml "cat <<'EOF' > notes.md
playbook done
EOF"
silent "and so is one inside a heredoc"
eq "neither ends the goal" "" "$(st "$d" ns_state | grep -x done)"
chan ml 'playbook decision "Ship it on Friday" && playbook route bogus nothing && npm test'
eq "a wrong line refuses the whole command" deny "$(decision_of)"
OUT="$(reason_of)"; has "naming the line" 'Playbook refused `playbook route bogus nothing`'
has "and saying nothing ran" "Nothing in this command ran."
has "and which lines before it were recorded" "The lines before it were recorded, so leave them out when you run it again: 📌 Playbook decision recorded: Ship it on Friday."
hasnt "ending in one full stop" "Friday.."
playbook_team_declare '{"session_id":"ml"}' server ""
chan ml 'playbook part-done server 2>&1 | tail -3' aserver-1a2b
eq "a redirection after a line is the shell's business: part-done is recorded for its own name" part-done "$(st "$SANDBOX/ml/team/server" declared)"
[ ! -d "$SANDBOX/ml/team/server2" ] && pass "and never as a crew member called server2" || flunk "server2 phantom from 2>&1"
chan ml 'playbook waiting server on client the reply >/dev/null 2>&1' aserver-1a2b
eq "so is waiting, with the redirections dropped" "client the reply" "$(st "$SANDBOX/ml/team/server" waiting_on)"
chan ml 'playbook part-done sever' aserver-1a2b
eq "part-done with a name not on the crew is refused" deny "$(decision_of)"
OUT="$(reason_of)"; has "with the crew's names" "sever is not on this crew. Use your own name, one of: server"
chan ml 'playbook waiting sever on client x' aserver-1a2b
eq "so is waiting" deny "$(decision_of)"
chan ml 'playbook status 2>&1 | head -20; playbook part-done server' aserver-1a2b
OUT="$(shown_of)"; has "status is a command, so it never refuses what follows it" "Playbook status · lone-wolf · no regroup open · you (server): waiting"
chan ml 'playbook status'
eq "on its own it is approved" allow "$(decision_of)"
case "$(ran_of)" in "📚 Playbook status · lone-wolf · no regroup open") pass "and prints what Playbook knows" ;; *) flunk "status output: $(ran_of)" ;; esac
chan ml 'playbook frobnicate 2>&1; playbook rethink keep going'
OUT="$(shown_of)"; has "an unknown word beside a real line leaves the real line recorded" "rethink: keep going"
b="$(score_of "$d")"
bash_post ml 'playbook rethink tighten the parser && npm test' 1 "1 failing"
[ "$(score_of "$d")" -gt "$b" ] && pass "a failing test chained after a playbook line is still scored" || flunk "chained test failure not scored"
b="$(score_of "$d")"
bash_post ml 'playbook rethink once more' 1 ""
eq "a command of playbook lines alone is never scored" "$b" "$(score_of "$d")"

# --- the playbook command on the shell's path -------------------------------
B="$root/bin/playbook"
[ -x "$B" ] && pass "the plugin ships an executable bin/playbook" || flunk "bin/playbook missing or not executable"
OUT="$(bash "$B" route lone-wolf x 2>&1)"; RC=$?
eq "it exits 0, so a line the hooks never saw is not an error" 0 "$RC"
silent "and says nothing, so a chained line the hook recorded is not contradicted"

# --- draft, then publish ----------------------------------------------------
iso; d="$(sd pb)"; f="$d/interface/PROTOCOL.md"; dr="$d/interface/PROTOCOL.draft.md"; mkdir -p "$d/interface"; echo v1 > "$f"
crew() { playbook_team_declare '{"session_id":"pb"}' "$1" ""; }
chan pb 'playbook route hackathon chat room'
chan pb "playbook interface $f"
has_ran() { case "$(ran_of)" in *"$2"*) pass "$1" ;; *) flunk "$1 (shown: $(ran_of))" ;; esac; }
has_ran "declaring the interface names where it is kept, outside the project" "kept in Playbook's storage outside the project: $f."
has_ran "and its draft and publish" "edit its draft $dr, then run playbook publish <what changed>."
rm -f "$dr"
chan pb 'playbook publish the first draft'
eq "publish with the draft gone is refused" deny "$(decision_of)"
OUT="$(reason_of)"; has "and says to make the change in the draft" "make the change in the draft first"
eq "and the draft is made again" v1 "$(cat "$dr")"
chan pb 'playbook publish nothing'
OUT="$(reason_of)"; has "a draft that matches the interface has nothing to publish" "nothing to publish"
echo v1b > "$dr"
chan pb 'playbook publish the lead drafting'
has_ran "the lead publishing before anyone is dispatched calls no regroup" "published: the lead drafting"
eq "and holds nobody" "" "$(st "$d" rg_open)"
eq "the interface now holds the draft" v1b "$(cat "$f")"
crew server; crew client
echo v1c > "$dr"
pre_edit pb "$dr" server
eq "a teammate may edit the draft" allow "$(decision_of)"
post pb PostToolUse Edit "{\"file_path\":\"$dr\"}" '{}' server
eq "and editing it never calls a regroup" "" "$(st "$d" rg_open)"
post pb PostToolUse Edit "{\"file_path\":\"$dr\"}" '{}' server
eq "even after the edit lands" "" "$(st "$d" rg_open)"
chan pb 'playbook publish join order wording && ls' aserver-1a2b
eq "publish shares its line with nothing" deny "$(decision_of)"
OUT="$(reason_of)"; has "and says why" "as a Bash call of its own"
eq "and nothing was copied" v1b "$(cat "$f")"
chan pb 'playbook publish join order wording' aserver-1a2b
eq "a teammate's publish is approved" allow "$(decision_of)"
has_ran "and calls everyone to regroup" "This calls everyone to regroup"
has_ran "telling it to message everyone REGROUP" "REGROUP: join order wording"
eq "the regroup is open" 1 "$(st "$d" rg_open)"
eq "the publisher counts as aligned" server "$(st "$d" rg_ok)"
eq "and its caller is recorded by crew name" server "$(st "$d" rg_by)"
eq "the interface holds the published draft" v1c "$(cat "$f")"
post pb PostToolUse Bash '{"command":"ls"}' '{"stdout":"","exit_code":0}' aclient-3c4d
OUT="$(ctx_of)"; has "a colleague is told at its next step" "a colleague has called everyone to regroup"
hasnt "and not that someone changed the interface directly" "was changed directly"
post pb PostToolUse Bash '{"command":"ls"}' '{"stdout":"","exit_code":0}' aserver-1a2b
OUT="$(ctx_of)"; hasnt "the publisher is not told twice" "called everyone to regroup"
echo v1d > "$dr"
chan pb 'playbook publish the agreed version' aserver-1a2b
has_ran "publishing during the regroup clears the approvals" "Every approval so far is cleared"
eq "and the publisher is the only one aligned" server "$(st "$d" rg_ok)"
post pb PostToolUse Bash '{"command":"ls"}' '{"stdout":"","exit_code":0}' aclient-3c4d
OUT="$(ctx_of)"; has "a colleague is told its approval was cleared" "of the interface in place, so every approval so far is cleared"
post pb PostToolUse Bash '{"command":"ls"}' '{"stdout":"","exit_code":0}' aclient-3c4d
OUT="$(ctx_of)"; hasnt "only once" "every approval so far is cleared"
post pb PostToolUse Read "{\"file_path\":\"$f\"}" '{}' aclient-3c4d
chan pb 'playbook aligned client' aclient-3c4d
post pb PostToolUse Read "{\"file_path\":\"$f\"}" '{}'
chan pb 'playbook aligned team-lead'
has_ran "the lead's align closes it" "regroup closed: everyone aligned on version"
post pb PostToolUse Bash '{"command":"ls"}' '{"stdout":"","exit_code":0}' aserver-1a2b
OUT="$(ctx_of)"; has "every crew member is told at its next step that the regroup closed" "The hold is lifted, so edits are free again."
post pb PostToolUse Bash '{"command":"ls"}' '{"stdout":"","exit_code":0}' aserver-1a2b
OUT="$(ctx_of)"; hasnt "only once" "regroup closed"
post pb PostToolUse Bash '{"command":"ls"}' '{"stdout":"","exit_code":0}'
OUT="$(ctx_of)"; hasnt "the one who closed it is not told again" "Playbook regroup closed"
echo v1e > "$f"; post pb PostToolUse Bash "{\"command\":\"echo v1e > PROTOCOL.md\"}" '{"stdout":"","exit_code":0}' aclient-3c4d
eq "a direct shell write to the interface still calls a regroup" 1 "$(st "$d" rg_open)"
OUT="$(ctx_of)"; has "and the writer is told to use the draft next time" "was changed directly, so it counts as published"
post pb PostToolUse Read "{\"file_path\":\"$f\"}" '{}' aserver-1a2b
chan pb 'playbook resume additive notes only'
post pb PostToolUse Bash '{"command":"ls"}' '{"stdout":"","exit_code":0}' aserver-1a2b
OUT="$(ctx_of)"; has "the lead's resume is told to every crew member too" "Playbook regroup closed: the lead ended it at version"
has "with the lead's reason" ": additive notes only. The hold is lifted"
iso; d="$(sd pb2)"; chan pb2 'playbook route lone-wolf small fix'
chan pb2 'playbook publish x'
OUT="$(reason_of)"; has "publish with no interface declared is refused" "no interface is declared"

# --- a ; inside a reason -----------------------------------------------------
iso; d="$(sd sc)"
chan sc 'playbook rethink split the module; client aligned; lead aligned three times'
eq "words after a ; that are not a command refuse the command" deny "$(decision_of)"
OUT="$(reason_of)"; has "and the refusal says why and how to write it" "\`client aligned\` is not a command. A ; ends a \`playbook\` line"
has "and that nothing ran" "Nothing in this command ran."
eq "nothing was recorded" "" "$(st "$d" rethink_last)"
chan sc 'playbook rethink "split the module; client aligned"'
eq "a quoted reason with a ; in it is one reason" allow "$(decision_of)"
chan sc 'playbook part-done server 2>&1 | tail -3; echo done'
hasnt "a real command after a line is never refused" "is not a command"
chan sc 'FOO=1 ls; playbook rethink x; LANG=C ls'
hasnt "an assignment before a real command is read past" "is not a command"
chan sc 'playbook rethink x; ./build.sh'
hasnt "a path is left to the shell" "is not a command"

# --- the interface lives outside the project ---------------------------------
iso; d="$(sd ip)"; mkdir -p "$SANDBOX/w"
ipath() { sig "$(jq -cn --arg c "$1" --arg w "$SANDBOX/w" '{hook_event_name:"PreToolUse",session_id:"ip",cwd:$w,tool_name:"Bash",tool_input:{command:$c}}')"; }
ipre() { sig "$(jq -cn --arg t "$1" --arg p "$2" '{hook_event_name:"PreToolUse",session_id:"ip",tool_name:$t,tool_input:{file_path:$p}}')"; }
ipath 'playbook route hackathon chat room'
for p in 'PROTOCOL.md' '"PROTOCOL.md"' '$PWD/PROTOCOL.md' 'docs/PROTOCOL.md' '$(echo x)/PROTOCOL.md'; do
  ipath "playbook interface $p"
  case "$(st "$d" iface_path)" in "$d/interface/"*.md) pass "the interface named by $p is kept in Playbook's state" ;; *) flunk "$p put the interface at $(st "$d" iface_path)" ;; esac
done
eq "and nothing is written into the project" "" "$(ls -A "$SANDBOX/w")"
ipath 'playbook interface PROTOCOL.md'; f="$d/interface/PROTOCOL.md"; dr="$d/interface/PROTOCOL.draft.md"
ipre Read "$f"; eq "reading the interface needs no permission prompt" allow "$(decision_of)"
ipre Read "$dr"; eq "nor does reading its draft" allow "$(decision_of)"
ipre Read "$SANDBOX/w/app.js"; silent "any other read is left to Claude Code"
ipre Write "$dr"; eq "writing the draft needs no permission prompt" allow "$(decision_of)"
ipre Edit "$f"; eq "before anyone is on the crew the lead may edit the interface itself" allow "$(decision_of)"
ipre Edit "$SANDBOX/w/app.js"; silent "any other edit is left to Claude Code"
ipath "cat $f"; eq "a shell read of the interface is approved" allow "$(decision_of)"
ipath "diff $f $dr | head -20"; eq "and a diff against its draft" allow "$(decision_of)"
HOME="$SANDBOX" ipath "cat ~${f#"$SANDBOX"}"; eq "including through ~" allow "$(decision_of)"
hm="$(mktemp -d)"; mkdir -p "$hm${f%/*}"; echo secret > "$hm$f"
HOME="$hm" ipath "cat ~$f"; silent "but when Playbook's state is outside the home folder, ~ never stands for it"
rm -rf "$hm"
ipath "cat $f > $SANDBOX/w/copy.md"; silent "but a shell command that writes is left to Claude Code"
ipath "rm $f"; silent "as is one that removes it"
ipath "cat $f && npm install"; silent "or runs anything else"

# --- another playbook on the PATH ---------------------------------------------
iso; d="$(sd op)"; mkdir -p "$SANDBOX/other"; printf '#!/bin/sh\nexit 0\n' > "$SANDBOX/other/playbook"; chmod +x "$SANDBOX/other/playbook"
OUT="$(jq -cn '{hook_event_name:"PreToolUse",session_id:"op",tool_name:"Bash",tool_input:{command:"ls && playbook route lone-wolf small fix"}}' | PATH="$SANDBOX/other:$PATH" bash "$SIG" 2>/dev/null)"
eq "with another playbook on the PATH a mixed command is refused" deny "$(decision_of)"
has "naming it and the way out" "another program called playbook is on the PATH ($SANDBOX/other/playbook)"
eq "and nothing was recorded" "" "$(st "$d" route_mode)"
OUT="$(jq -cn '{hook_event_name:"PreToolUse",session_id:"op",tool_name:"Bash",tool_input:{command:"playbook rethink a && playbook rethink b"}}' | PATH="$SANDBOX/other:$PATH" bash "$SIG" 2>/dev/null)"
eq "a command of playbook lines only is still rewritten to Playbook's own print" allow "$(decision_of)"
OUT="$(jq -cn '{hook_event_name:"PreToolUse",session_id:"op",tool_name:"Bash",tool_input:{command:"ls && playbook route lone-wolf small fix"}}' | PATH="$root/bin:$PATH" bash "$SIG" 2>/dev/null)"
hasnt "Playbook's own command on the PATH is never refused" "another program called playbook"
OUT="$(jq -cn '{hook_event_name:"PreToolUse",session_id:"op",tool_name:"Bash",tool_input:{command:"ls && grep -c x y"}}' | PATH="$SANDBOX/other:$PATH" bash "$SIG" 2>/dev/null)"
silent "a command with no playbook line is untouched"

# --- heredocs ------------------------------------------------------------------
iso; d="$(sd hd)"; mkdir -p "$SANDBOX/w/chat"; echo v1 > "$SANDBOX/w/chat/P.md"
hdc() { sig "$(jq -cn --arg c "$1" --arg w "$SANDBOX/w" '{hook_event_name:"PreToolUse",session_id:"hd",cwd:$w,tool_name:"Bash",tool_input:{command:$c}}')"; }
hdc 'playbook route hackathon chat room'
hdc "cat > chat/P.md <<'EOF'
# Protocol
playbook decision \"only a mention\"
EOF
cd $SANDBOX/w && playbook interface chat/P.md && playbook status"
eq "a line after a heredoc's closing line is read: the interface is declared" "$d/interface/P.md" "$(st "$d" iface_path)"
OUT="$(shown_of)"; has "and the status after it names the interface and its draft" "interface version 1 at $d/interface/P.md, draft at $d/interface/P.draft.md"
eq "a line inside the heredoc body is only data" "" "$(playbook_decisions_text "$d" 2>/dev/null | grep -c 'only a mention' | sed 's/^0$//')"
hdc "cat <<-END | grep x
	playbook rethink inside
	END
playbook rethink after the heredoc"
OUT="$(shown_of)"; has "a <<- heredoc closed by a tab-indented line is skipped too" "rethink: after the heredoc"
hasnt "and its body is not read" "inside"
hdc 'grep -c a <<< "x" && playbook rethink after a here-string'
OUT="$(shown_of)"; has "a here-string is not a heredoc" "rethink: after a here-string"
iso; d="$(sd hd)"
hdc 'playbook route hackathon chat room'
hdc 'playbook status'
case "$(ran_of)" in *"no interface declared"*) pass "status says when no interface is declared" ;; *) flunk "status: $(ran_of)" ;; esac
hdc 'playbook route lone-wolf small fix'
hdc 'playbook status'
case "$(ran_of)" in *interface*) flunk "status names no interface outside hackathon: $(ran_of)" ;; *) pass "outside hackathon status says nothing about an interface" ;; esac

# --- what the Test B rerun showed ------------------------------------------------
iso; d="$(sd tb)"; mkdir -p "$SANDBOX/w/chat-room"
tbc() { sig "$(jq -cn --arg c "$1" --arg w "$SANDBOX/w/chat-room" --arg a "${2:-}" '{hook_event_name:"PreToolUse",session_id:"tb",cwd:$w,tool_name:"Bash",tool_input:{command:$c}} + (if $a != "" then {agent_id:$a} else {} end)')"; }
tbc 'playbook route hackathon chat room'
tbc "cd $SANDBOX/w && playbook interface chat-room/P.md"
eq "a cd before the declaration changes nothing, since Playbook keeps the interface" "$d/interface/P.md" "$(st "$d" iface_path)"
playbook_team_declare '{"session_id":"tb"}' server-dev ""
tbc 'playbook interface P.md' aserver-dev-1a2b
OUT="$(reason_of)"; has "a teammate is told only the lead declares the interface" "only the lead declares the shared interface; message the lead if it needs declaring"
tbc 'playbook resume stuck' aserver-dev-1a2b
OUT="$(reason_of)"; has "and only the lead ends a regroup early" "only the lead ends a regroup early"
tbc 'playbook done' aserver-dev-1a2b
OUT="$(reason_of)"; has "and only the lead marks the goal done" "only the lead marks the goal done"
tbc 'playbook interface --help 2>&1 | head -20' aserver-dev-1a2b
hasnt "a verb asked for --help is never refused" "only the lead"
eq "and is left to Playbook's own command" "" "$(decision_of)"
echo v2 > "$d/interface/P.draft.md"
tbc "cd $SANDBOX/w/chat-room && playbook publish the settled shapes" aserver-dev-1a2b
OUT="$(shown_of)"; has "publish may follow a cd" "published: the settled shapes"
eq "and the draft is in place" v2 "$(cat "$d/interface/P.md")"
echo v3 > "$d/interface/P.draft.md"
tbc 'ls && playbook publish more' aserver-dev-1a2b
OUT="$(reason_of)"; has "but not any other command" "as a Bash call of its own (a cd before it is fine)"
eq "and nothing was copied" v2 "$(cat "$d/interface/P.md")"

# --- what the review found ------------------------------------------------------
iso; d="$(sd rv)"; mkdir -p "$SANDBOX/w"
rv() { sig "$(jq -cn --arg c "$1" --arg w "$SANDBOX/w" --arg a "${2:-}" '{hook_event_name:"PreToolUse",session_id:"rv",cwd:$w,tool_name:"Bash",tool_input:{command:$c}} + (if $a != "" then {agent_id:$a} else {} end)')"; }
rv 'playbook route hackathon chat room'; rv 'playbook interface proto'
f="$d/interface/proto.md"; dr="$d/interface/proto.draft.md"; idir="$d/interface"
for c in "cat <(touch $SANDBOX/pwned) $f" "diff $f <(id)" "cat $f =(id)" "sed -Ei '' s/a/b/ $f $SANDBOX/w/x" "sed -n '1w $SANDBOX/w/x' $f" \
         "cat $f $HOME/.ssh/config" "grep -r token $HOME $f" "head $f {a,b}" "cat $f *" "cat $f \"$SANDBOX/w/x\"" "cat $f; rm -rf $SANDBOX/w"; do
  rv "$c"
  [ "$(decision_of)" = allow ] && flunk "a shell read that does more than read the interface was approved: $c" || pass "left to Claude Code: ${c#"$SANDBOX"}"
done
for c in "cat $f" "diff $f $dr | head -20" "tail -n 5 $dr" "wc -l $f $dr" "cd $idir && cat proto.md" "cd $idir/ && diff proto.md proto.draft.md"; do
  rv "$c"; eq "a plain read of the interface is still approved: ${c#"$d/"}" allow "$(decision_of)"
done
rv "cd $SANDBOX/w && cat proto.md"; silent "but a file of the same name elsewhere is not"
playbook_team_declare '{"session_id":"rv"}' server ""; playbook_team_declare '{"session_id":"rv"}' client ""
playbook_state_put "$d" "rg_open=1" "rg_ok=server" "rg_by=server"
for c in 'pytest -q' 'python -m pytest tests' 'go test ./...' 'cargo test' 'pnpm test' 'xcodebuild test -scheme App' 'grep -n "=>" src/app.js'; do
  rv "$c" aclient-1a2b; eq "the regroup hold lets through: $c" "" "$(decision_of)"
done
rv 'echo x > src/app.js' aclient-1a2b; eq "but a write is still held" deny "$(decision_of)"
rv 'npm install left-pad' aclient-1a2b; eq "and so is an install" deny "$(decision_of)"
bpost() { post rv PostToolUse Bash "$(jq -cn --arg c "$1" '{command:$c}')" '{}' "$2"; }
for c in "ls -la $f" "echo proto.md" "cat $SANDBOX/w/proto.md" "cat $dr"; do
  bpost "$c" aclient-1a2b; chan rv 'playbook aligned client' aclient-1a2b
  eq "a command that only names the interface does not count as reading it: ${c#"$SANDBOX/"}" deny "$(decision_of)"
done
bpost "cat $f | head -40" aclient-1a2b; chan rv 'playbook aligned client' aclient-1a2b
eq "a plain read of the interface does" allow "$(decision_of)"
playbook_state_put "$d" "rg_open=1" "rg_ok=server" "rg_by=server" "rg_id=1-3" "rg_noted=1-3" "rg_closed_noted=1-2" "rg_how=everyone aligned" "rg_reset=3" "rg_reset_noted=3" "rg_reset_by=server" "crew_msgs=5" "crew_last=client" "crew_last_at=1" "lead_idle=1"; mkdir -p "$d/mail" "$d/team/client"; echo x > "$d/mail/client"
OUT="$(printf '%s' '{"hook_event_name":"SessionStart","source":"clear","session_id":"rv"}' | bash "$TB" 2>/dev/null)"
eq "/clear closes an open regroup" "" "$(st "$d" rg_open)"
for k in rg_ok rg_by rg_id rg_noted rg_closed_noted rg_how rg_reset rg_reset_noted rg_reset_by crew_last crew_last_at; do
  eq "and clears ${k}" "" "$(st "$d" "$k")"
done
eq "and resets the crew message count" "" "$(st "$d" crew_msgs)"
eq "and the lead's idle mark" "" "$(st "$d" lead_idle)"
[ ! -e "$d/mail" ] && pass "and drops queued priority mail" || flunk "queued mail survived /clear"
[ ! -e "$d/team" ] && pass "and the old crew" || flunk "the crew survived /clear"
chan rv 'playbook route hackathon a new crew'
pre_edit rv "$SANDBOX/w/app.js"; eq "so the lead's next edit is not held, even back in hackathon" "" "$(decision_of)"
chan rv 'playbook interface api'
post rv PostToolUse Bash '{"command":"ls"}' '{"stdout":"","exit_code":0}'
OUT="$(ctx_of)"; hasnt "and no regroup notice from the old conversation reaches the lead" "regroup closed"
playbook_state_put "$d" "rg_open=1" "route_mode=lone-wolf"
pre_edit rv "$SANDBOX/w/app.js"; eq "and a regroup left open never holds edits outside hackathon" "" "$(decision_of)"
iso; d="$(sd ar)"
chan ar $'x=$((1<<2))\nplaybook route lone-wolf fix'
eq "a shift in arithmetic is not a heredoc, so the line after it is read" lone-wolf "$(st "$d" route_mode)"

exit $fail
