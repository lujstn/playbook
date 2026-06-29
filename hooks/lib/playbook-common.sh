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

# The dispatched subagent's id from hook stdin. Empty on the main thread,
# which is how callers distinguish a helper from the steering thread.
playbook_agent_id() {
  jq -r '.agent_id // empty' 2>/dev/null <<<"${1:-}" || printf ''
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

# The value of the most recent `playbook-northstar: <text>` line in a block
# of recovered text. The whole line, after optional leading space, must be
# the declaration; the last occurrence wins; trailing space is trimmed.
# Empty if absent. Empty, never a wrong value.
playbook_northstar_line() {
  { printf '%s\n' "${1:-}" \
      | grep -E '^[[:space:]]*playbook-northstar:[[:space:]]*.' \
      | tail -n1 \
      | sed -E 's/^[[:space:]]*playbook-northstar:[[:space:]]*//; s/[[:space:]]+$//'
  } 2>/dev/null || printf ''
}

# The project North Star a dispatcher passed into this run: the
# `playbook-northstar: <text>` line carried in the first genuine human or
# dispatch message. Read off playbook_original_request so it is anchored to
# the exact same record (one parse, no second slurp, and a later doc read
# cannot poison it). Empty on the main thread (the engine does not inject
# the line into the user's own request) and empty if absent.
playbook_project_northstar() {
  local orig; orig="$(playbook_original_request "${1:-}")"
  [ -n "$orig" ] || { printf ''; return 0; }
  playbook_northstar_line "$orig"
}

# The labelled anchor block to inject. Subagent-aware: on the main thread the
# recovered first message is the user's own request and is labelled as such;
# inside a subagent (agent_id present) that first message is the dispatch
# prompt, so it is labelled as the assigned task and the dispatcher-provided
# project North Star, if any, is given primacy. Empty when there is nothing
# to anchor on. Never fabricates a North Star.
playbook_anchor_block() {
  local s="${1:-}" aid orig ns
  aid="$(playbook_agent_id "$s")"
  orig="$(playbook_original_request "$s")"
  [ -n "$orig" ] || { printf ''; return 0; }
  if [ -n "$aid" ]; then
    ns="$(playbook_northstar_line "$orig")"
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
# (e.g. one of the docs/ pages), or a user-channel paste cannot be mistaken for it.
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

# Integer percent of a used/window pair, clamped to 0..100. Empty unless
# both are non-negative integers and the window is positive. The single
# source of the beat formula, so the hook and playbook_context_percent
# cannot drift.
playbook_percent() {
  { local u="${1:-}" w="${2:-}"
    case "$u" in ''|*[!0-9]*) printf ''; return 0 ;; esac
    case "$w" in ''|*[!0-9]*) printf ''; return 0 ;; esac
    [ "$w" -gt 0 ] 2>/dev/null || { printf ''; return 0; }
    local p=$(( (u * 100 + w / 2) / w ))
    [ "$p" -lt 0 ] && p=0; [ "$p" -gt 100 ] && p=100
    printf '%s' "$p"
  } 2>/dev/null || printf ''
}

# Integer percent of context used, or empty when either input is unavailable.
# Same return contract the take-a-beat caller already expects.
playbook_context_percent() {
  { playbook_percent \
      "$(playbook_context_used "${1:-}")" \
      "$(playbook_declared_window "${1:-}")"
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

# Read a single-line scalar from .claude/playbook/<file> under the project
# dir. Trims surrounding whitespace; returns the first non-empty line only.
# Empty if the file is missing or blank. Silent degradation: empty, never a
# wrong value. Used by scripts/notify to read the gitignored ntfy topic and
# the optional server override.
playbook_claude_file() {
  local proj="${1:-}" name="${2:-}" path
  [ -n "$proj" ] && [ -n "$name" ] || { printf ''; return 0; }
  path="${proj}/.claude/playbook/${name}"
  [ -f "$path" ] || { printf ''; return 0; }
  { tr -d '\r' <"$path" \
      | awk 'NF{print; exit}' \
      | sed -E 's/^[[:space:]]+|[[:space:]]+$//g'
  } 2>/dev/null || printf ''
}

# The gitignored ntfy topic and the optional server override, read from
# .claude/playbook/ in the project tree.
playbook_ntfy_topic()  { playbook_claude_file "${1:-$PWD}" "ntfy-topic"; }
playbook_ntfy_server() { playbook_claude_file "${1:-$PWD}" "ntfy-server"; }

# The chosen notification provider (pushover|ntfy). Empty if not configured;
# scripts/notify falls back to ntfy when an ntfy-topic is present.
playbook_notify_provider() { playbook_claude_file "${1:-$PWD}" "notify-provider"; }

# Pushover app token and user/group key, read from .claude/playbook/ in the
# project tree. Silent degradation: empty, never a wrong value.
playbook_pushover_token() { playbook_claude_file "${1:-$PWD}" "pushover-token"; }
playbook_pushover_user()  { playbook_claude_file "${1:-$PWD}" "pushover-user"; }

# Candidate settings files that may register hooks: the user's global config and
# the project-local configs. Echoed one per line, only those that exist.
playbook_settings_files() {
  local proj="${1:-$PWD}" f
  for f in "${HOME}/.claude/settings.json" \
           "${proj}/.claude/settings.json" \
           "${proj}/.claude/settings.local.json"; do
    [ -f "$f" ] && printf '%s\n' "$f"
  done
}

# Detect a competing context-warning hook: one that injects low-context anxiety
# into the model's context (e.g. GSD's gsd-context-monitor, which tells agents to
# wrap up and stop near the context limit). Echoes a short identifier for the
# first match, else empty. Detection is by the command path a settings file
# registers, since that path is all the settings file carries. Silent
# degradation: empty, never a wrong value.
playbook_competing_context_hook() {
  local proj="${1:-$PWD}" f
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if grep -qiE 'context-monitor|context-warning' "$f" 2>/dev/null; then
      printf 'gsd-context-monitor'
      return 0
    fi
  done < <(playbook_settings_files "$proj")
  printf ''
}

# Whether the context-calm channel has been resolved: the user has either let
# Playbook own it or explicitly declined. Persisted as a marker so the one-time
# offer is not repeated every session. Checks the project marker first, then a
# global fallback. Echoes the marker contents (e.g. owned or declined), else
# empty.
playbook_context_calm_resolved() {
  local proj="${1:-$PWD}" v g
  v="$(playbook_claude_file "$proj" "context-calm")"
  [ -n "$v" ] && { printf '%s' "$v"; return 0; }
  g="${HOME}/.claude/playbook/context-calm"
  [ -f "$g" ] || { printf ''; return 0; }
  { tr -d '\r' <"$g" | awk 'NF{print; exit}' \
      | sed -E 's/^[[:space:]]+|[[:space:]]+$//g'; } 2>/dev/null || printf ''
}

# Discover the most recently modified transcript jsonl for the current
# working directory. Claude Code stores per-project transcripts under
# ~/.claude/projects/<encoded-cwd>/, where the encoding replaces '/' with
# '-' in the absolute project path. Empty if the directory does not exist
# or carries no transcripts.
playbook_latest_transcript() {
  local proj="${1:-$PWD}" enc dir latest
  enc="$(printf '%s' "$proj" | tr '/' '-')"
  dir="${HOME}/.claude/projects/${enc}"
  [ -d "$dir" ] || { printf ''; return 0; }
  latest="$(ls -1t "$dir"/*.jsonl 2>/dev/null | awk 'NR==1')"
  [ -n "$latest" ] && [ -f "$latest" ] && printf '%s' "$latest" || printf ''
}

# The remote-control session URL the live transcript carries when
# /remote-control is active. Recovered the same role/type-anchored way as
# playbook_original_request and playbook_declared_window: filter records
# whose type=="system" and subtype=="bridge_status" and whose content
# literally contains "is active", take the .url of the latest such record.
# A user paste of the URL string is type=="user", so it cannot match. A
# later deactivation or an absent record yields empty: silent degradation
# by construction, never a wrong value.
playbook_remote_url() {
  { local f; f="${1:-}"
    [ -n "$f" ] || f="$(playbook_latest_transcript "${2:-$PWD}")"
    [ -n "$f" ] && [ -f "$f" ] || { printf ''; return 0; }
    jq -rs '
      [ .[] | select(.type=="system" and .subtype=="bridge_status"
                     and ((.content // "") | tostring | test("is active"; "i"))) ]
      | (.[-1].url // empty)' "$f" 2>/dev/null
  } 2>/dev/null || printf ''
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
