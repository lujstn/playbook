#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/payloads.sh"

CAP='"Subagent spawn limit reached: 8 of 8 in use"'
agent_fail() { post "$1" PostToolUseFailure Agent '{"description":"look","prompt":"x"}' "$2" "${3:-}"; }

iso; d="$(sd cap)"
agent_fail cap "$CAP"; ctx="$(ctx_of)"; OUT="$ctx"
has "the refusal is named as a stale counter" "stale per-process counter"
has "online, a fresh session with a handover comes first" "a fresh session with a short handover is the cleanest way on"
has "claude -r comes second" "claude -r <label>"
has "in a new terminal window" "new terminal window"
has "reassuring that nothing is lost" "nothing is lost"
has "and forbidding a silent solo fallback" "Do not quietly fall back to solo work"
if [ "$(printf '%s' "$ctx" | grep -bo 'fresh session' | head -1 | cut -d: -f1)" -lt "$(printf '%s' "$ctx" | grep -bo 'claude -r' | head -1 | cut -d: -f1)" ]; then pass "the handover is recommended before claude -r"; else flunk "claude -r came first"; fi
eq "the mark is set" 1 "$(st "$d" cap_notice)"
agent_fail cap "$CAP"; hasnt "one notice per session" "Playbook subagent cap"

iso; d="$(sd off)"; : > "$d/offline"
agent_fail off "$CAP"; OUT="$(ctx_of)"
has "offline: keep going via the Workflow pool" "Workflow tool draws on a separate pool"
has "and log it for the morning" "Log the refusal for the morning"
hasnt "never told to stop and wait" "/rename"
hasnt "nor to stop here" "Stop here"

iso; d="$(sd other)"
agent_fail other '"some other dispatch error"'
OUT="$(ctx_of)"; hasnt "other Agent failures raise no cap notice" "Playbook subagent cap"
post other PostToolUse Agent '{"description":"x","prompt":"y"}' '{"content":"the text Subagent spawn limit reached appears in a report"}'
silent "a successful return that quotes the refusal is silent"
post other PostToolUse Bash '{"command":"echo Subagent spawn limit reached"}' '{"stdout":"Subagent spawn limit reached","stderr":""}'
silent "so is a Bash command that prints it"
agent_fail other "$CAP" helper1
silent "a helper's refusal is not the main thread's to announce"

exit $fail
