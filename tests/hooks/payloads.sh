#!/usr/bin/env bash
# Shared fixtures for the payload-driven hook tests: sourced, never run alone.
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SIG="$root/hooks/signal"
TB="$root/hooks/take-a-beat"
SS="$root/hooks/session-start"
export CLAUDE_PLUGIN_ROOT="$root"
unset CURSOR_PLUGIN_ROOT COPILOT_CLI CLAUDE_PID PLAYBOOK_NOW PLAYBOOK_WINDOW 2>/dev/null || true
source "$root/hooks/lib/playbook-common.sh"

GLOBAL_TMP="$(mktemp -d)"; export PLAYBOOK_GLOBAL_DIR="$GLOBAL_TMP"
printf 'checked=2026-07-24\nplugins=none\n' > "$GLOBAL_TMP/setup"
SANDBOX=""
trap 'rm -rf "$GLOBAL_TMP" "$SANDBOX"' EXIT

fail=0
pass()  { echo "PASS: $1"; }
flunk() { echo "FAIL: $1"; fail=1; }
eq()    { if [ "$2" = "$3" ]; then pass "$1"; else flunk "$1 (expected [$2], got [$3])"; fi }
has()   { if grep -qF -- "$2" <<<"$OUT"; then pass "$1"; else flunk "$1 (output: [$OUT])"; fi }
hasnt() { if grep -qF -- "$2" <<<"$OUT"; then flunk "$1 (output: [$OUT])"; else pass "$1"; fi }
silent() { if [ -z "$OUT" ]; then pass "$1"; else flunk "$1 (output: [$OUT])"; fi }

iso() {
  if [ -n "$SANDBOX" ]; then rm -rf "$SANDBOX"; fi
  SANDBOX="$(mktemp -d)"; export PLAYBOOK_STATE_DIR="$SANDBOX"
}
sd() { playbook_state_dir "{\"session_id\":\"$1\"}"; }
st() { playbook_state_get "$1" "$2"; }

run() { OUT="$(bash "$1" 2>/dev/null)"; RC=$?; }

# sig <json>
sig() { OUT="$(printf '%s' "$1" | bash "$SIG" 2>/dev/null)"; RC=$?; }
tb()  { OUT="$(printf '%s' "$1" | bash "$TB" 2>/dev/null)"; RC=$?; }

# chan <session> <command> [agent_id]
chan() {
  sig "$(jq -cn --arg s "$1" --arg c "$2" --arg a "${3:-}" \
    '{hook_event_name:"PreToolUse",session_id:$s,tool_name:"Bash",tool_input:{command:$c}} + (if $a != "" then {agent_id:$a} else {} end)')"
}
decision_of() { jq -r '.hookSpecificOutput.permissionDecision // empty' <<<"$OUT" 2>/dev/null; }
reason_of()   { jq -r '.hookSpecificOutput.permissionDecisionReason // empty' <<<"$OUT" 2>/dev/null; }
shown_of()    { jq -r '.systemMessage // empty' <<<"$OUT" 2>/dev/null; }
# ran_of: what an approved channel line prints, read from the rewritten command without running it; empty unless the command is Playbook's own fixed shape
ran_of() {
  jq -r '.hookSpecificOutput.updatedInput.command // empty' <<<"$OUT" 2>/dev/null \
    | sed -nE "s/^: playbook [a-z-]+; printf '%s\\\\n' '((([^']|'\\\\'')*))'\$/\\1/p" | sed "s/'\\\\''/'/g"
}
ctx_of()      { jq -r '.hookSpecificOutput.additionalContext // empty' <<<"$OUT" 2>/dev/null; }

# say <session> <text> [now]: a user prompt through the prompt hook
say() {
  tb "$(jq -cn --arg s "$1" --arg t "$2" '{hook_event_name:"UserPromptSubmit",session_id:$s,prompt:$t}')"
}

# post <session> <event> <tool> <tool_input json> <tool_response json> [agent_id]
post() {
  sig "$(jq -cn --arg s "$1" --arg e "$2" --arg t "$3" --argjson i "$4" --argjson r "$5" --arg a "${6:-}" \
    '{hook_event_name:$e,session_id:$s,tool_name:$t,tool_input:$i} + (if $e=="PostToolUse" then {tool_response:$r} else {error:($r|tostring)} end) + (if $a != "" then {agent_id:$a} else {} end)')"
}
# bash_post <session> <command> <exit code> <stdout>
bash_post() {
  if [ "$3" = "0" ]; then
    post "$1" PostToolUse Bash "$(jq -cn --arg c "$2" '{command:$c}')" "$(jq -cn --arg o "$4" '{stdout:$o,stderr:"",interrupted:false}')"
  else
    post "$1" PostToolUseFailure Bash "$(jq -cn --arg c "$2" '{command:$c}')" "\"Exit code $3\\n$4\""
  fi
}
# pre_edit <session> <path> [agent_id]
pre_edit() {
  sig "$(jq -cn --arg s "$1" --arg p "$2" --arg a "${3:-}" \
    '{hook_event_name:"PreToolUse",session_id:$s,tool_name:"Edit",tool_input:{file_path:$p}} + (if $a != "" then {agent_id:$a} else {} end)')"
}
score_of() { playbook_state_int "$1" score10 0; }
