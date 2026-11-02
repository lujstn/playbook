#!/usr/bin/env bash
set -uo pipefail
export HOME="$(mktemp -d)"
source "$(cd "$(dirname "$0")" && pwd)/payloads.sh"
export PLAYBOOK_NOW=1793116000
TI="$root/hooks/team-idle"

# msg <from agent id or ""> <to> <message>
msg() { post m PostToolUse SendMessage "$(jq -cn --arg t "$2" --arg m "$3" '{to:$t,message:$m}')" '{}' "$1"; }
# step <agent id or "">: any later tool call by that agent
step() { post m PostToolUse Bash '{"command":"ls"}' '{"stdout":"","exit_code":0}' "$1"; }
stop_of() { jq -r 'if .continue == false then .stopReason else empty end' <<<"$OUT" 2>/dev/null; }
idle() { OUT="$(jq -cn --arg n "$1" '{session_id:"m",hook_event_name:"TeammateIdle",teammate_name:$n,team_name:"t"}' | bash "$TI" 2>&1)"; RC=$?; }
crew() { playbook_team_declare '{"session_id":"m"}' "$1" ""; }
fresh() { iso; d="$(sd m)"; chan m 'playbook route hackathon realtime crew'; crew server; crew client; crew bot; }

echo "-- the kinds"
fresh
msg aserver-1a2b client "please look at the ws handler when you can"
step aclient-3c4d
OUT="$(ctx_of)"; hasnt "an untagged message adds nothing" "📨"
msg aserver-1a2b client "SOON: the schema moved to v2"
step aclient-3c4d
OUT="$(ctx_of)"; has "SOON: read it before the next piece of work" "📨 Read server's message before your next piece of work."
step aclient-3c4d
OUT="$(ctx_of)"; hasnt "once only" "📨"
msg aserver-1a2b client "ASAP: you are coding against the old port"
step aclient-3c4d
OUT="$(ctx_of)"; has "ASAP: stop as soon as you reasonably can" "📨 Stop as soon as you reasonably can and read server's message."
eq "ASAP never ends the turn" "" "$(stop_of)"
msg aserver-1a2b client "ASAP: the port moved"
msg abot-5e6f client "URGENT: the bot is writing to prod"
step aclient-3c4d
case "$(stop_of)" in *"stopped you to deliver bot's urgent message; read it first. 📨 Stop as soon as you reasonably can and read server's message."*) pass "an ASAP arriving with an URGENT is kept in the stop reason, since Claude Code shows only that" ;; *) flunk "ASAP lost beside URGENT: $(stop_of)" ;; esac
msg aserver-1a2b client "  URGENT: you are about to drop the users table"
step aclient-3c4d
eq "URGENT ends the receiver's turn with the reason" "📞 Playbook stopped you to deliver server's urgent message; read it first." "$(stop_of)"
grep -q '"event":"urgent","ts":[0-9]*,"from":"server","to":"client","delivered":"URGENT"' "$d/team-log.jsonl" && pass "every URGENT is logged" || flunk "URGENT not logged"
step abot-5e6f
eq "nobody else is stopped" "" "$(stop_of)"
step aserver-1a2b
eq "nor is the sender" "" "$(stop_of)"
msg "" client "RESUME: interface v3 aligned"
step aclient-3c4d
OUT="$(ctx_of)"; hasnt "RESUME adds nothing" "📨"

echo "-- the lead"
fresh
msg aserver-1a2b team-lead "URGENT: the build is red on main"
step ""
eq "the lead is never force-stopped" "" "$(stop_of)"
OUT="$(ctx_of)"; has "an URGENT to the lead arrives as ASAP" "📨 Stop as soon as you reasonably can and read server's message."
eq "and is logged too" "lead ASAP" "$(tail -n1 "$d/team-log.jsonl" | jq -r '.to + " " + .delivered')"
msg "" bot "SOON: I've changed the env names"
step abot-5e6f
OUT="$(ctx_of)"; has "the lead's messages are named as the lead's" "📨 Read lead's message before your next piece of work."
msg "" "*" "SOON: lunch"
step aserver-1a2b; OUT="$(ctx_of)"; has "a message to everyone reaches each teammate" "lead's message"
step aclient-3c4d; OUT="$(ctx_of)"; has "every one of them" "lead's message"
step ""; OUT="$(ctx_of)"; hasnt "but not the sender" "📨"

echo "-- the URGENT cap"
fresh
msg aserver-1a2b client "URGENT: stop the migration"
step aclient-3c4d
PLAYBOOK_NOW=$(( 1793116000 + 300 )) msg aserver-1a2b client "URGENT: and the seed script"
OUT="$(ctx_of)"; has "a second URGENT within ten minutes tells the sender in the send's own result" "you sent client an URGENT 5 minutes ago"
step aclient-3c4d
eq "and arrives as ASAP" "" "$(stop_of)"
OUT="$(ctx_of)"; has "with the ASAP nudge" "Stop as soon as you reasonably can and read server's message."
eq "both are logged" "2" "$(grep -c '"event":"urgent"' "$d/team-log.jsonl")"
eq "the second as delivered ASAP" "ASAP" "$(tail -n1 "$d/team-log.jsonl" | jq -r .delivered)"
PLAYBOOK_NOW=$(( 1793116000 + 601 )) msg aserver-1a2b client "URGENT: the deploy is live"
step aclient-3c4d
eq "after ten minutes an URGENT stops them again" "📞 Playbook stopped you to deliver server's urgent message; read it first." "$(stop_of)"
msg abot-5e6f client "URGENT: the bot token leaked"
step aclient-3c4d
eq "the cap is per sender" "📞 Playbook stopped you to deliver bot's urgent message; read it first." "$(stop_of)"

echo "-- the regroup"
fresh
f="$d/interface/PROTOCOL.md"; mkdir -p "$d/interface"; echo v1 > "$f"; chan m "playbook interface $f"
echo v2 > "$f"; post m PostToolUse Edit "{\"file_path\":\"$f\"}" '{}' aserver-1a2b
eq "the regroup's caller is recorded by crew name, as the REGROUP check expects" "server" "$(st "$d" rg_by)"
DG="$root/hooks/dispatch-guard"
dg() { OUT="$(jq -cn --arg m "$2" --arg a "$1" '{session_id:"m",tool_name:"SendMessage",tool_input:{to:"*",message:$m},agent_id:$a}' | bash "$DG" 2>&1)"; RC=$?; }
dg aserver-1a2b "REGROUP: the cursor event gains a colour"
eq "so the real caller's REGROUP passes the guard" "0" "$RC"
dg aclient-3c4d "REGROUP: me too"
eq "and anyone else's is still refused" "2" "$RC"
msg aserver-1a2b "*" "REGROUP: the cursor event gains a colour"
step aclient-3c4d
OUT="$(ctx_of)"; has "REGROUP nudges with its own words" "📨 Stop as soon as you reasonably can and read server's regroup message."
eq "and never ends the turn" "" "$(stop_of)"
step ""
OUT="$(ctx_of)"; has "the lead hears it too" "server's regroup message"
msg abot-5e6f client "URGENT: the bot is writing to prod"
step aclient-3c4d
eq "an URGENT during a regroup is delivered as normal" "📞 Playbook stopped you to deliver bot's urgent message; read it first." "$(stop_of)"

echo "-- idle colleagues are left to Claude Code"
fresh
playbook_state_put "$SANDBOX/m/team/client" "declared=waiting"
idle client
eq "a waiting teammate is marked idle" "1" "$(st "$SANDBOX/m/team/client" idle)"
msg aserver-1a2b client "ASAP: here is the reply"
eq "a message to an idle teammate is not held, since it wakes it" "" "$(cat "$SANDBOX/m/mail/client" 2>/dev/null)"
eq "and the message clears its idle mark" "" "$(st "$SANDBOX/m/team/client" idle)"
step aclient-3c4d
OUT="$(ctx_of)"; hasnt "so no nudge follows it" "📨"
sig '{"hook_event_name":"Stop","session_id":"m"}'
eq "the lead ending its turn marks it idle" "1" "$(st "$d" lead_idle)"
msg aserver-1a2b team-lead "ASAP: done"
eq "a message to the idle lead is not held" "" "$(cat "$SANDBOX/m/mail/lead" 2>/dev/null)"
step ""
eq "the lead's next tool call clears the mark" "" "$(st "$d" lead_idle)"

echo "-- a nudged teammate is let go idle for the message"
fresh
msg aserver-1a2b client "ASAP: the port is 8081"
step aclient-3c4d
idle client
eq "a nudged teammate with open items is not pushed back to work" "0" "$RC"
silent "and nothing is said"
idle client
eq "the next idle pushes again" "2" "$RC"

echo "-- the lead never joins the crew"
fresh
chan m 'playbook waiting team-lead on server the smoke test'
eq "the lead's waiting is acknowledged" allow "$(decision_of)"
case "$(ran_of)" in *"the lead needs no declaration"*) pass "and it is told it needs none" ;; *) flunk "lead waiting message: $(ran_of)" ;; esac
[ ! -d "$SANDBOX/m/team/team-lead" ] && pass "without adding a crew member called team-lead" || flunk "phantom team-lead crew member"
chan m 'playbook part-done lead'
[ ! -d "$SANDBOX/m/team/lead" ] && pass "nor one called lead for part-done" || flunk "phantom lead crew member"
mkdir -p "$SANDBOX/m/team/team-lead"
f="$d/interface/PROTOCOL.md"; mkdir -p "$d/interface"; echo v1 > "$f"; chan m ": playbook interface $f"
echo v2 > "$f"; post m PostToolUse Edit "{\"file_path\":\"$f\"}" '{}' aserver-1a2b
for n in server client bot; do post m PostToolUse Read "{\"file_path\":\"$f\"}" '{}' "a${n}-1a2b"; chan m "playbook aligned $n" "a${n}-1a2b"; done
post m PostToolUse Read "{\"file_path\":\"$f\"}" '{}'; chan m 'playbook aligned team-lead'
case "$(ran_of)" in *"regroup closed"*) pass "a leftover team-lead folder never blocks a regroup from closing" ;; *) flunk "regroup did not close: $(ran_of)" ;; esac

echo "-- outside a hackathon nothing happens"
fresh
chan m 'playbook route interns three lanes'
msg "" asomeone-1 "URGENT: stop"
step asomeone-1
eq "no stop" "" "$(stop_of)"
[ ! -e "$SANDBOX/m/mail" ] && pass "and nothing is held" || flunk "mail held outside a hackathon"

echo "-- an URGENT to an idle teammate interrupts nothing"
fresh
crew client; playbook_state_put "$SANDBOX/m/team/client" "idle=1"
msg aserver-1a2b client "URGENT: the prod key is in the log"
eq "it is logged as delivered at once" "at once, the receiver was idle" "$(tail -n1 "$d/team-log.jsonl" | jq -r .delivered)"
eq "and starts no cap" "" "$(st "$d" urg_server_client)"
step aclient-3c4d
eq "the receiver is not stopped" "" "$(stop_of)"
step aclient-3c4d
msg aserver-1a2b client "URGENT: and the backup key"
step aclient-3c4d
case "$(stop_of)" in *"urgent message"*) pass "so a real URGENT soon after still stops a busy receiver" ;; *) flunk "second URGENT was capped: $(stop_of)" ;; esac

echo "-- a REGROUP nudge for a regroup that has closed"
fresh
playbook_state_put "$d" "rg_open=1" "rg_by=server" "rg_ok=server"
msg aserver-1a2b client "REGROUP: settled the shapes"
playbook_state_put "$d" "rg_open=" "rg_ok=" "rg_how=everyone aligned on version 2"
step aclient-3c4d
OUT="$(ctx_of)"; hasnt "is dropped, so the receiver is not told to stop for a regroup that is over" "regroup message"

exit "$fail"
