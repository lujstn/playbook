#!/usr/bin/env bash
# Shared helpers for Playbook hooks. Sourced, never executed directly.

# Resolve the project working directory from hook stdin or PWD.
playbook_project_dir() {
  local cwd
  cwd="$(jq -r '.cwd // empty' 2>/dev/null <<<"${1:-}")"
  [ -n "$cwd" ] && { printf '%s' "$cwd"; return; }
  printf '%s' "${CLAUDE_PROJECT_DIR:-$PWD}"
}

# Resolve the transcript path from hook stdin JSON. Empty if absent.
playbook_transcript_path() {
  jq -r '.transcript_path // empty' 2>/dev/null <<<"${1:-}" || printf ''
}

# The verbatim original request: the complete content of the first transcript
# record that is the human's own user message, with multi-line content
# preserved. Skips system/hook records (.type!="user"), records whose role is
# not "user", and tool-result turns (content is an array whose first element
# type is "tool_result"). Returns the full text, or empty on any failure.
# Silent degradation is mandatory: empty, never a wrong value.
playbook_original_request() {
  { local f; f="$(playbook_transcript_path "${1:-}")"
    [ -n "$f" ] && [ -f "$f" ] || { printf ''; return 0; }
    jq -rs 'map(select(.type=="user" and (.message.role=="user")
                       and ((.message.content|type)=="string"
                            or ((.message.content|type)=="array"
                                and (.message.content[0].type? != "tool_result")))))
            | (.[0] // empty)
            | .message.content
            | if type=="string" then .
              elif type=="array" then (map(select(.type=="text")|.text)|join("\n"))
              else empty end' "$f" 2>/dev/null
  } 2>/dev/null || printf ''
}

# Context tokens in use = the last assistant record's input-side usage, the
# exact formula Claude Code uses for used_percentage. Empty if unavailable.
playbook_context_used() {
  { local f; f="$(playbook_transcript_path "${1:-}")"
    [ -n "$f" ] && [ -f "$f" ] || { printf ''; return 0; }
    local v
    v="$(jq -r 'select(.message.usage)
                | .message.usage
                | ((.input_tokens // 0) + (.cache_creation_input_tokens // 0)
                   + (.cache_read_input_tokens // 0))' "$f" 2>/dev/null \
         | awk 'NF{last=$0} END{if(last!="")print last}')"
    case "$v" in ''|*[!0-9]*) printf '' ;; *) printf '%s' "$v" ;; esac
  } 2>/dev/null || printf ''
}

# The agent-declared nominal window: the most recent line matching the fixed
# prefix `playbook-window: <integer>` anywhere in the transcript. Empty if
# never declared.
playbook_declared_window() {
  { local f; f="$(playbook_transcript_path "${1:-}")"
    [ -n "$f" ] && [ -f "$f" ] || { printf ''; return 0; }
    local v
    v="$(grep -oE 'playbook-window:[[:space:]]*[0-9]+' "$f" 2>/dev/null \
         | tail -1 | grep -oE '[0-9]+' || true)"
    case "$v" in ''|*[!0-9]*) printf '' ;; *) printf '%s' "$v" ;; esac
  } 2>/dev/null || printf ''
}

# Integer percent of context used, or empty when either input is unavailable.
# Same return contract the take-a-beat caller already expects.
playbook_context_percent() {
  { local u w; u="$(playbook_context_used "${1:-}")"
    w="$(playbook_declared_window "${1:-}")"
    case "$u" in ''|*[!0-9]*) printf ''; return 0 ;; esac
    case "$w" in ''|*[!0-9]*) printf ''; return 0 ;; esac
    [ "$w" -gt 0 ] 2>/dev/null || { printf ''; return 0; }
    local p=$(( (u * 100 + w / 2) / w ))
    [ "$p" -lt 0 ] && p=0; [ "$p" -gt 100 ] && p=100
    printf '%s' "$p"
  } 2>/dev/null || printf ''
}

# JSON-string escape via bash parameter substitution (single C-level passes;
# identical technique to the Superpowers session-start hook).
playbook_json_escape() {
  local s="${1:-}"
  s="${s//\\/\\\\}"; s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"; s="${s//$'\r'/\\r}"; s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

# Emit the context-injection envelope. Replicates the Superpowers session-start
# 3-platform branch VERBATIM (proven at /tmp/playbook-research/superpowers/hooks/
# session-start lines 46-56, comment 38-45): Claude Code reads BOTH additional_context and the
# nested form without dedup, so exactly one field is emitted per platform.
# Without this branch the overlay+anchor silently never inject on Cursor/Copilot.
playbook_emit_context() {
  local event="${1:-}" body="${2:-}" escaped
  escaped="$(playbook_json_escape "$body")"
  if [ -n "${CURSOR_PLUGIN_ROOT:-}" ]; then
    printf '{\n  "additional_context": "%s"\n}\n' "$escaped"
  elif [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -z "${COPILOT_CLI:-}" ]; then
    printf '{\n  "hookSpecificOutput": {\n    "hookEventName": "%s",\n    "additionalContext": "%s"\n  }\n}\n' "$event" "$escaped"
  else
    printf '{\n  "additionalContext": "%s"\n}\n' "$escaped"
  fi
}

# Stop-turn nudge. Channel decided by docs/playbook/decisions/2026-05-16-stop-channel.md.
# MUST be a model-visible, turn-terminating channel (never unconditional decision:block).
playbook_emit_stop_nudge() {
  local body="$1"
  playbook_emit_context "Stop" "$body"   # replace with decided carrier if not additionalContext
}
