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
#
# Bounded read: the first user record is structurally at the top of the file, so
# only the leading PLAYBOOK_TAIL_BYTES are parsed on a large transcript (the last,
# possibly partial, physical line is dropped since JSONL is one record per line);
# a full parse is the fallback only if that window carried no matching record.
playbook_original_request() {
  { local f; f="$(playbook_transcript_path "${1:-}")"
    [ -n "$f" ] && [ -f "$f" ] || { printf ''; return 0; }
    local bound="${PLAYBOOK_TAIL_BYTES:-262144}"
    case "$bound" in ''|*[!0-9]*) bound=262144 ;; esac
    local flt='map(select(.type=="user" and (.message.role=="user")
                       and ((.message.content|type)=="string"
                            or ((.message.content|type)=="array"
                                and (.message.content[0].type? != "tool_result")))))
            | (.[0] // empty)
            | .message.content
            | if type=="string" then .
              elif type=="array" then (map(select(.type=="text")|.text)|join("\n"))
              else empty end'
    local size v; size="$(wc -c < "$f" 2>/dev/null | tr -d ' ')"
    case "$size" in ''|*[!0-9]*) size=0 ;; esac
    if [ "$size" -gt "$bound" ]; then
      v="$(head -c "$bound" "$f" 2>/dev/null | sed '$d' | jq -rs "$flt" 2>/dev/null)"
      [ -n "$v" ] && { printf '%s' "$v"; return 0; }
    fi
    jq -rs "$flt" "$f" 2>/dev/null
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
#
# Bounded read: this runs on every batch and inside the time-budgeted prompt
# hook, so a large transcript is read only from its last PLAYBOOK_TAIL_BYTES
# (the first, partial, physical line is dropped); a full parse is the fallback
# only if no usage record landed in that tail window.
playbook_context_used() {
  { local f; f="$(playbook_transcript_path "${1:-}")"
    [ -n "$f" ] && [ -f "$f" ] || { printf ''; return 0; }
    local bound="${PLAYBOOK_TAIL_BYTES:-262144}"
    case "$bound" in ''|*[!0-9]*) bound=262144 ;; esac
    local flt='select(.message.usage)
                | .message.usage
                | ((.input_tokens // 0) + (.cache_creation_input_tokens // 0)
                   + (.cache_read_input_tokens // 0))'
    local size v; size="$(wc -c < "$f" 2>/dev/null | tr -d ' ')"
    case "$size" in ''|*[!0-9]*) size=0 ;; esac
    if [ "$size" -gt "$bound" ]; then
      v="$(tail -c "$bound" "$f" 2>/dev/null | tail -n +2 \
           | jq -r "$flt" 2>/dev/null \
           | awk 'NF{last=$0} END{if(last!="")print last}')"
      case "$v" in ''|*[!0-9]*) : ;; *) printf '%s' "$v"; return 0 ;; esac
    fi
    v="$(jq -r "$flt" "$f" 2>/dev/null \
         | awk 'NF{last=$0} END{if(last!="")print last}')"
    case "$v" in ''|*[!0-9]*) printf '' ;; *) printf '%s' "$v" ;; esac
  } 2>/dev/null || printf ''
}

# Integer percent of a used/window pair, clamped to 0..100. Empty unless
# both are non-negative integers and the window is positive. The single
# source of the beat formula, so the hook cannot drift from it.
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

# --- Per-session throttle state --------------------------------------------
# All state lives outside the working tree, under
# ${PLAYBOOK_STATE_DIR:-$HOME/.claude/hook-state/playbook}/<sid>/ (main thread)
# or .../<sid>/agents/<aid>/ (subagents). Two files: `state` (KEY=VALUE lines,
# integers only, no jq needed) and `failures` (append-only, one line per
# failure; wc -l is the count). Every helper here returns 0 unconditionally:
# a state failure must never fail a hook, only degrade it to silence.

# The root directory holding every per-session state dir.
playbook_state_root() {
  printf '%s' "${PLAYBOOK_STATE_DIR:-${HOME}/.claude/hook-state/playbook}"
}

# The sanitised session id: session_id from stdin, else the transcript filename
# stem, else the literal `unknown`. Sanitised to a safe path segment. Never empty.
playbook_session_id() {
  local s="${1:-}" sid
  sid="$(jq -r '.session_id // empty' 2>/dev/null <<<"$s" || true)"
  sid="$(printf '%s' "$sid" | tr -cd 'A-Za-z0-9._-')"
  if [ -z "$sid" ]; then
    local f; f="$(playbook_transcript_path "$s")"
    if [ -n "$f" ]; then
      sid="$(basename -- "$f")"; sid="${sid%.jsonl}"
      sid="$(printf '%s' "$sid" | tr -cd 'A-Za-z0-9._-')"
    fi
  fi
  [ -n "$sid" ] || sid="unknown"
  printf '%s' "$sid"
}

# The per-session (or per-subagent) state directory, created on demand. Empty
# only if the root is unusable.
playbook_state_dir() {
  local s="${1:-}" root sid aid dir
  root="$(playbook_state_root)"
  [ -n "$root" ] || { printf ''; return 0; }
  sid="$(playbook_session_id "$s")"
  aid="$(playbook_agent_id "$s" | tr -cd 'A-Za-z0-9._-')"
  if [ -n "$aid" ]; then dir="${root}/${sid}/agents/${aid}"; else dir="${root}/${sid}"; fi
  mkdir -p "$dir" 2>/dev/null || true
  printf '%s' "$dir"
}

# Read a single raw state value. Empty if the file or key is absent. Last
# occurrence wins.
playbook_state_get() {
  local dir="${1:-}" key="${2:-}" sf
  [ -n "$dir" ] && [ -n "$key" ] || { printf ''; return 0; }
  sf="${dir}/state"
  [ -f "$sf" ] || { printf ''; return 0; }
  awk -v k="$key" 'index($0,k"=")==1{v=substr($0,length(k)+2)} END{if(v!="")printf "%s",v}' \
    "$sf" 2>/dev/null || printf ''
}

# Read an integer state value with a default. Non-integer or missing -> default.
playbook_state_int() {
  local dir="${1:-}" key="${2:-}" def="${3:-0}" v
  v="$(playbook_state_get "$dir" "$key")"
  case "$v" in ''|*[!0-9]*) printf '%s' "$def" ;; *) printf '%s' "$v" ;; esac
}

# Atomically set KEY=VALUE pairs in <dir>/state, preserving other sane KEY=VALUE
# lines. Writes a sibling temp file then renames it, so a reader never sees a
# torn file. Always returns 0.
playbook_state_put() {
  local dir="${1:-}"; shift 2>/dev/null || true
  [ -n "$dir" ] || return 0
  mkdir -p "$dir" 2>/dev/null || true
  local sf="${dir}/state" tmp="${dir}/.state.$$.${RANDOM}.tmp" kv k keys=" "
  for kv in "$@"; do keys="${keys}${kv%%=*} "; done
  {
    if [ -f "$sf" ]; then
      while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
          *=*) k="${line%%=*}"
               case "$keys" in *" $k "*) : ;; *) printf '%s\n' "$line" ;; esac ;;
          *) : ;;
        esac
      done < "$sf"
    fi
    for kv in "$@"; do printf '%s\n' "$kv"; done
  } > "$tmp" 2>/dev/null || { rm -f "$tmp" 2>/dev/null; return 0; }
  mv -f "$tmp" "$sf" 2>/dev/null || rm -f "$tmp" 2>/dev/null
  return 0
}

# Whether <dir>/state exists and every always-present integer key parses. Drives
# the bias-to-silence self-heal on corruption.
playbook_state_healthy() {
  local dir="${1:-}" k v
  [ -n "$dir" ] || return 1
  [ -f "${dir}/state" ] || return 1
  for k in last_anchor_used calm_fired fail_snapshot; do
    v="$(playbook_state_get "$dir" "$k")"
    case "$v" in ''|*[!0-9]*) return 1 ;; esac
  done
  return 0
}

# Re-seed state biased to silence: baseline set to current usage, calm and
# snapshot zeroed, failures truncated. window_proven is deliberately preserved
# (a compaction does not change the window size) and otherwise re-derived by the
# ratchet. Always returns 0.
playbook_state_reset() {
  local dir="${1:-}" used="${2:-0}"
  [ -n "$dir" ] || return 0
  case "$used" in ''|*[!0-9]*) used=0 ;; esac
  playbook_state_put "$dir" "v=1" "last_anchor_used=${used}" "calm_fired=0" "fail_snapshot=0"
  : > "${dir}/failures" 2>/dev/null || true
  return 0
}

# Append one atomic failure marker (single-line >> is atomic under PIPE_BUF, so
# concurrent parallel failures never lose an increment).
playbook_fail_append() {
  local dir="${1:-}"
  [ -n "$dir" ] || return 0
  mkdir -p "$dir" 2>/dev/null || true
  printf 'x\n' >> "${dir}/failures" 2>/dev/null || true
  return 0
}

# The current failure count (wc -l of the failures file). Zero if absent.
playbook_fail_count() {
  local dir="${1:-}" c
  [ -n "$dir" ] || { printf '0'; return 0; }
  [ -f "${dir}/failures" ] || { printf '0'; return 0; }
  c="$(wc -l < "${dir}/failures" 2>/dev/null | tr -d ' ')"
  case "$c" in ''|*[!0-9]*) printf '0' ;; *) printf '%s' "$c" ;; esac
}

# Remove per-session state dirs older than 7 days. Guarded so an empty or root
# path can never be swept. Best-effort; always returns 0.
playbook_state_gc() {
  local root; root="$(playbook_state_root)"
  case "$root" in ''|/) return 0 ;; esac
  [ -d "$root" ] || return 0
  find "$root" -mindepth 1 -maxdepth 1 -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true
  return 0
}

# The nominal context window in tokens. PLAYBOOK_WINDOW (a positive integer)
# is the escape hatch and always wins. Otherwise the ratchet-proven window from
# the state dir wins once usage has exceeded 200000 this session. Otherwise the
# assumed standard 200000-token window. Never empty.
playbook_window() {
  local dir="${1:-}" e="${PLAYBOOK_WINDOW:-}" v
  case "$e" in ''|*[!0-9]*) : ;; *) [ "$e" -gt 0 ] 2>/dev/null && { printf '%s' "$e"; return 0; } ;; esac
  if [ -n "$dir" ]; then
    v="$(playbook_state_get "$dir" window_proven)"
    case "$v" in ''|*[!0-9]*) : ;; *) [ "$v" -gt 0 ] 2>/dev/null && { printf '%s' "$v"; return 0; } ;; esac
  fi
  printf '200000'
}

# Provenance of the window figure: `proven` when it comes from the env override
# or the usage ratchet, `assumed` when it is the 200000 default. The calm beat
# may state a percentage only when the window is proven.
playbook_window_provenance() {
  local dir="${1:-}" e="${PLAYBOOK_WINDOW:-}" v
  case "$e" in ''|*[!0-9]*) : ;; *) [ "$e" -gt 0 ] 2>/dev/null && { printf 'proven'; return 0; } ;; esac
  if [ -n "$dir" ]; then
    v="$(playbook_state_get "$dir" window_proven)"
    case "$v" in ''|*[!0-9]*) : ;; *) [ "$v" -gt 0 ] 2>/dev/null && { printf 'proven'; return 0; } ;; esac
  fi
  printf 'assumed'
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
# playbook_original_request: filter records
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
