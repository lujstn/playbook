#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/payloads.sh"
rm -f "$GLOBAL_TMP/setup"; printf 'checked=2026-07-24\nplugins=none\n' > "$GLOBAL_TMP/setup"

start() { # <session> <source> [cwd]
  tb "$(jq -cn --arg s "$1" --arg src "$2" --arg c "${3:-}" '{hook_event_name:"SessionStart",source:$src,session_id:$s} + (if $c != "" then {cwd:$c} else {} end)')"
}

# --- startup is quiet when there is nothing to say -------------------------
iso
start s startup; silent "a clean startup says nothing"
eq "and exits 0" 0 "$RC"

# --- /clear forgets the conversation ---------------------------------------
iso; d="$(sd clr)"
playbook_ns_confirm "$d" "old goal" interns picker
playbook_decision_add "$d" asked "Q" "A" >/dev/null
playbook_state_put "$d" score10=90 gate=judge iface_path=/x iface_ver=3 cap_notice=1
start clr clear
eq "/clear forgets the goal" "" "$(playbook_ns_goal "$d")"
eq "the score" 0 "$(score_of "$d")"
eq "the gate" "" "$(playbook_gate "$d")"
eq "the decisions" "" "$(playbook_decisions_text "$d")"
eq "the declared interface" "" "$(st "$d" iface_path)"
eq "the cap notice mark" "" "$(st "$d" cap_notice)"
start clr startup
iso; d="$(sd keep)"
playbook_ns_confirm "$d" "keep this" interns picker
start keep startup
eq "a plain startup does not wipe state" "keep this" "$(playbook_ns_goal "$d")"

# --- context-calm offers ---------------------------------------------------
iso
home="$(mktemp -d)"; proj="$(mktemp -d)"
mkdir -p "$home/.claude" "$proj/.claude/playbook"
printf '{"hooks":{"PostToolUse":[{"hooks":[{"command":"gsd-context-monitor"}]}]}}' > "$home/.claude/settings.json"
OUT="$(printf '{"hook_event_name":"SessionStart","source":"startup","session_id":"off","cwd":"%s"}' "$proj" | HOME="$home" bash "$TB" 2>/dev/null)"; OUT="$(ctx_of)"
has "the offer fires when a competing hook is registered" "context-calm offer"
has "and saves the answer machine-wide, outside the project" "write the word owned to $PLAYBOOK_GLOBAL_DIR/context-calm"
hasnt "never into the project" "to .claude/playbook/context-calm"
printf 'owned\n' > "$PLAYBOOK_GLOBAL_DIR/context-calm"
OUT="$(printf '{"hook_event_name":"SessionStart","source":"startup","session_id":"off","cwd":"%s"}' "$proj" | HOME="$home" bash "$TB" 2>/dev/null)"; OUT="$(ctx_of)"
has "an owned channel re-surfaces it when the hook returns" "has come back"
printf 'declined\n' > "$PLAYBOOK_GLOBAL_DIR/context-calm"
OUT="$(printf '{"hook_event_name":"SessionStart","source":"startup","session_id":"off","cwd":"%s"}' "$proj" | HOME="$home" bash "$TB" 2>/dev/null)"
silent "a declined channel stays silent"
printf 'owned\n' > "$PLAYBOOK_GLOBAL_DIR/context-calm"; printf '{"hooks":{}}' > "$home/.claude/settings.json"
OUT="$(printf '{"hook_event_name":"SessionStart","source":"startup","session_id":"off","cwd":"%s"}' "$proj" | HOME="$home" bash "$TB" 2>/dev/null)"
silent "an owned channel with the hook gone stays silent"
rm -f "$PLAYBOOK_GLOBAL_DIR/context-calm"
printf '{"hooks":{"PostToolUse":[{"hooks":[{"command":"gsd-context-monitor"}]}]}}' > "$home/.claude/settings.json"
printf 'declined\n' > "$proj/.claude/playbook/context-calm"
OUT="$(printf '{"hook_event_name":"SessionStart","source":"startup","session_id":"off","cwd":"%s"}' "$proj" | HOME="$home" bash "$TB" 2>/dev/null)"
silent "an answer saved in a project by Playbook 2.8 is still honoured"
printf '{"hooks":{}}' > "$home/.claude/settings.json"

# --- setup nudge ------------------------------------------------------------
iso
gd="$(mktemp -d)"
OUT="$(printf '{"hook_event_name":"SessionStart","source":"startup","session_id":"n1"}' | PLAYBOOK_GLOBAL_DIR="$gd" HOME="$home" bash "$TB" 2>/dev/null)"; OUT="$(ctx_of)"
has "the first-run nudge fires" "type /playbook:hello"
eq "and writes its once-ever marker" 1 "$([ -f "$gd/setup-nudged" ] && echo 1 || echo 0)"
OUT="$(printf '{"hook_event_name":"SessionStart","source":"startup","session_id":"n1"}' | PLAYBOOK_GLOBAL_DIR="$gd" HOME="$home" bash "$TB" 2>/dev/null)"
silent "it never repeats"

# --- status line ownership --------------------------------------------------
iso
gd="$(mktemp -d)"; fake="$(mktemp -d)"
mkdir -p "$fake/hooks" "$fake/scripts" "$gd/bin"; printf "checked=x\n" > "$gd/setup"
cp -R "$root/hooks/." "$fake/hooks/"; printf '#!/bin/sh\necho v2\n' > "$fake/scripts/statusline"
printf '{"statusLine":{"type":"command","command":"/usr/local/bin/other-status"}}' > "$home/.claude/settings.json"
sl() { OUT="$(printf '{"hook_event_name":"SessionStart","source":"startup","session_id":"sl","cwd":"%s"}' "$proj" | PLAYBOOK_GLOBAL_DIR="$gd" HOME="$home" bash "$fake/hooks/take-a-beat" 2>/dev/null)"; OUT="$(ctx_of)"; }
sl; silent "without the ownership marker nothing is offered"
printf 'owned\n' > "$gd/statusline"
printf '#!/bin/sh\necho v1\n' > "$gd/bin/statusline"
sl
has "an owned wrapper that settings no longer point at is offered back" "Playbook status line"
has "naming the command that replaced it" "/usr/local/bin/other-status"
has "with consent and a backup" "back up the settings file"
eq "the installed copy is refreshed from the plugin" "$(cat "$fake/scripts/statusline")" "$(cat "$gd/bin/statusline")"
eq "and stays executable" 1 "$([ -x "$gd/bin/statusline" ] && echo 1 || echo 0)"
printf '{"statusLine":{"type":"command","command":"%s/bin/statusline"}}' "$gd" > "$home/.claude/settings.json"
sl; silent "when settings still point at the wrapper, nothing is offered"
printf 'declined\n' > "$gd/statusline"
printf '{"statusLine":{"type":"command","command":"/usr/local/bin/other-status"}}' > "$home/.claude/settings.json"
sl; silent "a declined wrapper is not offered again"
rm -rf "$gd" "$fake" "$home" "$proj"

# --- silence ---------------------------------------------------------------
iso
for ev in Stop SubagentStop PostToolUse PreCompact Notification; do
  tb "$(jq -cn --arg e "$ev" '{hook_event_name:$e,session_id:"u"}')"
  silent "silent on unwired $ev"; eq "exit 0 on $ev" 0 "$RC"
done
for bad in '' 'not json' '{"hook_event_name":"PostToolBatch"'; do
  tb "$bad"; silent "malformed stdin [$bad] is silent"; eq "and exits 0" 0 "$RC"
done
d="$(mktemp -d)"
tb "$(jq -cn --arg c "$d" '{hook_event_name:"PostToolBatch",session_id:"w",cwd:$c}')"
eq "nothing is written into the project" 0 "$(ls -A "$d" | wc -l | tr -d ' ')"
rm -rf "$d"

exit $fail
