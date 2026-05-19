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

# The project North Star a dispatcher passed into this run: the
# `playbook-northstar: <text>` line carried in the first genuine human or
# dispatch message. Recovered from the same record playbook_original_request
# uses (the first non-tool user message), so a later doc read cannot poison
# it. Empty on the main thread (the engine does not inject the line into the
# user's own request) and empty if absent. Empty, never a wrong value.
playbook_project_northstar() {
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
              else "" end
            | split("\n")
            | map(select(test("^[[:space:]]*playbook-northstar:[[:space:]]*.")))
            | (.[-1] // empty)
            | (capture("playbook-northstar:[[:space:]]*(?<n>.+)$").n // empty)
            | sub("[[:space:]]+$";"")' "$f" 2>/dev/null
  } 2>/dev/null || printf ''
}

# The labelled anchor block to inject. Subagent-aware: on the main thread the
# recovered first message is the user's own request and is labelled as such;
# inside a subagent (agent_id present) that first message is the dispatch
# prompt, so it is labelled as the assigned task and the dispatcher-provided
# project North Star, if any, is given primacy. Empty when there is nothing
# to anchor on. Never fabricates a North Star.
playbook_anchor_block() {
  local s="${1:-}" aid orig ns
  aid="$(jq -r '.agent_id // empty' 2>/dev/null <<<"$s" || true)"
  orig="$(playbook_original_request "$s")"
  [ -n "$orig" ] || { printf ''; return 0; }
  if [ -n "$aid" ]; then
    ns="$(playbook_project_northstar "$s")"
    if [ -n "$ns" ]; then
      local task
      task="$(printf '%s' "$orig" | grep -vE '^[[:space:]]*playbook-northstar:[[:space:]]' || true)"
      [ -n "$task" ] || task="$orig"
      printf 'Overall goal (what success means for the whole project):\n%s\n\nYour part of it, verbatim:\n%s' "$ns" "$task"
    else
      printf 'Your assigned task, verbatim:\n%s\n\nNo project North Star was provided to you. Request it from whoever dispatched you, or proceed treating this task as the local goal and raise unease that you are working without the project anchor.' "$orig"
    fi
  else
    printf 'Original request, verbatim:\n%s' "$orig"
  fi
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

# The agent-declared nominal window: the integer from the most recent
# assistant-authored text element that is, on its own, exactly a
# `playbook-window: <integer>` declaration. Role-anchored the same way
# playbook_original_request is: only the agent's own assistant records
# count, and the whole trimmed text element must be the declaration, so a
# quotation of the token inside prose, a tool-result echo of a spec file
# (e.g. DESIGN.md), or a user-channel paste cannot be mistaken for it.
# Empty if never declared. Silent degradation: empty, never a wrong value.
playbook_declared_window() {
  { local f; f="$(playbook_transcript_path "${1:-}")"
    [ -n "$f" ] && [ -f "$f" ] || { printf ''; return 0; }
    local v
    v="$(jq -rs '
            [ .[]
              | select(.type=="assistant" and (.message.role=="assistant"))
              | .message.content
              | if type=="string" then [.]
                elif type=="array" then [ .[] | select(.type=="text") | .text ]
                else [] end
              | .[] ]
            | map(select(test("^[[:space:]]*playbook-window:[[:space:]]*[0-9]+[[:space:]]*$")))
            | (.[-1] // empty)
            | (capture("playbook-window:[[:space:]]*(?<n>[0-9]+)").n // empty)' \
         "$f" 2>/dev/null)"
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
# three-platform branch: Claude Code reads BOTH additional_context and the nested
# form without dedup, so exactly one field is emitted per platform. Without this
# branch the overlay and anchor silently never inject on Cursor or Copilot.
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
