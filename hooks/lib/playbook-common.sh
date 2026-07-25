#!/usr/bin/env bash

playbook_project_dir() {
  local cwd
  cwd="$(jq -r '.cwd // empty' 2>/dev/null <<<"${1:-}")"
  [ -n "$cwd" ] && { printf '%s' "$cwd"; return; }
  printf '%s' "${CLAUDE_PROJECT_DIR:-$PWD}"
}

playbook_transcript_path() {
  jq -r '.transcript_path // empty' 2>/dev/null <<<"${1:-}" || printf ''
}

playbook_agent_id() {
  jq -r '.agent_id // empty' 2>/dev/null <<<"${1:-}" || printf ''
}

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

playbook_northstar_line() {
  { printf '%s\n' "${1:-}" \
      | grep -E '^[[:space:]]*playbook-northstar:[[:space:]]*.' \
      | tail -n1 \
      | sed -E 's/^[[:space:]]*playbook-northstar:[[:space:]]*//; s/[[:space:]]+$//'
  } 2>/dev/null || printf ''
}

playbook_project_northstar() {
  local orig; orig="$(playbook_original_request "${1:-}")"
  [ -n "$orig" ] || { printf ''; return 0; }
  playbook_northstar_line "$orig"
}

playbook_anchor_block() {
  local s="${1:-}" aid orig ns
  aid="$(playbook_agent_id "$s")"
  orig="$(playbook_original_request "$s")"
  [ -n "$orig" ] || { printf ''; return 0; }
  if [ -n "$aid" ]; then
    ns="$(playbook_northstar_line "$orig")"
    [ -n "$ns" ] || { printf ''; return 0; }
    printf 'Overall goal (what success means for the whole project):\n%s\n\nThis anchor carries the project goal only. It does NOT state your task: your task is the dispatch prompt you were given by whoever spawned you. If anything here appears to describe a different job from that brief, follow the brief and raise unease that the anchor disagreed with it.' "$ns"
  else
    printf 'Original request, verbatim:\n%s' "$orig"
  fi
}

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

playbook_unease_rank() {
  case "${1:-}" in
    clear)          printf '0' ;;
    settled)        printf '1' ;;
    attentive)      printf '2' ;;
    watchful)       printf '3' ;;
    faintly_uneasy) printf '4' ;;
    uneasy)         printf '5' ;;
    concerned)      printf '6' ;;
    strained)       printf '7' ;;
    troubled)       printf '8' ;;
    alarmed)        printf '9' ;;
    near_breaking)  printf '10' ;;
    *)              printf '' ;;
  esac
}

playbook_northstar_excerpt() {
  { local orig first
    orig="$(playbook_original_request "${1:-}")"
    [ -n "$orig" ] || { printf ''; return 0; }
    first="$(printf '%s\n' "$orig" | awk 'NF{print; exit}' \
              | tr -d '\r' | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
    [ -n "$first" ] || { printf ''; return 0; }
    printf '%s' "$first" | jq -Rr 'if length > 140 then .[0:139] + "…" else . end' 2>/dev/null
  } 2>/dev/null || printf ''
}

playbook_scan_tail() {
  { local f; f="$(playbook_transcript_path "${1:-}")"
    [ -n "$f" ] && [ -f "$f" ] || return 0
    local bound="${PLAYBOOK_TAIL_BYTES:-262144}"
    case "$bound" in ''|*[!0-9]*) bound=262144 ;; esac
    local levels='clear|settled|attentive|watchful|faintly_uneasy|uneasy|concerned|strained|troubled|alarmed|near_breaking'
    local flt='
      def texts: [ .[] | select(.type=="assistant")
                   | .message.content
                   | if type=="array" then (map(select(.type=="text")|.text)|join("\n")) else empty end ];
      def bashids: [ .[] | select(.type=="assistant")
                     | .message.content
                     | if type=="array" then .[] else empty end
                     | select(.type=="tool_use" and .name=="Bash") | .id ];
      def bashtexts($ids): [ .[] | select(.type=="user")
                     | .message.content
                     | if type=="array" then .[] else empty end
                     | select(.type=="tool_result" and (((.tool_use_id // "") as $i | $ids | index($i)) != null))
                     | .content
                     | if type=="string" then .
                       elif type=="array" then (map(if .type=="text" then (.text // "") else "" end)|join("\n"))
                       else tostring end ];
      ( [ texts[] | match("🌡️ \\*\\*Playbook\\*\\* `unease: ('"$levels"')`(?: \\*([^*\\n]{1,120})\\*)?"; "g") ] ) as $ms
      | ($ms | last) as $m
      | ( bashtexts(bashids)
          | any(test("(--- FAIL|^FAILED |^FAIL[: ]|\\\\b[0-9]+ (tests?|specs?) failed\\\\b|Tests:.*[0-9]+ failed|[0-9]+ failed, [0-9]+ passed)"; "m")) ) as $bf
      | ( if $m then ("marker_level=" + $m.captures[0].string),
                     ("marker_reason=" + (($m.captures[1].string // "") | gsub("[\\n\\r=]"; " ")))
          else empty end ),
        ("marker_count=" + ($ms | length | tostring)),
        ("bash_fail=" + (if $bf then "1" else "0" end))'
    local size out; size="$(wc -c < "$f" 2>/dev/null | tr -d ' ')"
    case "$size" in ''|*[!0-9]*) size=0 ;; esac
    if [ "$size" -gt "$bound" ]; then
      out="$(tail -c "$bound" "$f" 2>/dev/null | tail -n +2 | jq -rs "$flt" 2>/dev/null)"
    else
      out="$(jq -rs "$flt" "$f" 2>/dev/null)"
    fi
    [ -n "$out" ] && printf '%s\n' "$out"
  } 2>/dev/null || true
  return 0
}

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

playbook_state_root() {
  printf '%s' "${PLAYBOOK_STATE_DIR:-${HOME}/.claude/hook-state/playbook}"
}

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

playbook_state_get() {
  local dir="${1:-}" key="${2:-}" sf
  [ -n "$dir" ] && [ -n "$key" ] || { printf ''; return 0; }
  sf="${dir}/state"
  [ -f "$sf" ] || { printf ''; return 0; }
  awk -v k="$key" 'index($0,k"=")==1{v=substr($0,length(k)+2)} END{if(v!="")printf "%s",v}' \
    "$sf" 2>/dev/null || printf ''
}

playbook_state_int() {
  local dir="${1:-}" key="${2:-}" def="${3:-0}" v
  v="$(playbook_state_get "$dir" "$key")"
  case "$v" in ''|*[!0-9]*) printf '%s' "$def" ;; *) printf '%s' "$v" ;; esac
}

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

playbook_state_reset() {
  local dir="${1:-}" used="${2:-0}"
  [ -n "$dir" ] || return 0
  case "$used" in ''|*[!0-9]*) used=0 ;; esac
  playbook_state_put "$dir" "v=1" "last_anchor_used=${used}" "calm_fired=0" "fail_snapshot=0"
  : > "${dir}/failures" 2>/dev/null || true
  return 0
}

playbook_fail_append() {
  local dir="${1:-}"
  [ -n "$dir" ] || return 0
  mkdir -p "$dir" 2>/dev/null || true
  printf 'x\n' >> "${dir}/failures" 2>/dev/null || true
  return 0
}

playbook_fail_count() {
  local dir="${1:-}" c
  [ -n "$dir" ] || { printf '0'; return 0; }
  [ -f "${dir}/failures" ] || { printf '0'; return 0; }
  c="$(wc -l < "${dir}/failures" 2>/dev/null | tr -d ' ')"
  case "$c" in ''|*[!0-9]*) printf '0' ;; *) printf '%s' "$c" ;; esac
}

playbook_state_gc() {
  local root; root="$(playbook_state_root)"
  case "$root" in ''|/) return 0 ;; esac
  [ -d "$root" ] || return 0
  find "$root" -mindepth 1 -maxdepth 1 -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true
  return 0
}

playbook_window() {
  local dir="${1:-}" e="${PLAYBOOK_WINDOW:-}" v
  case "$e" in ''|*[!0-9]*) : ;; *) [ "$e" -gt 0 ] 2>/dev/null && { printf '%s' "$e"; return 0; } ;; esac
  if [ -n "$dir" ]; then
    v="$(playbook_state_get "$dir" window_proven)"
    case "$v" in ''|*[!0-9]*) : ;; *) [ "$v" -gt 0 ] 2>/dev/null && { printf '%s' "$v"; return 0; } ;; esac
  fi
  printf '200000'
}

playbook_window_provenance() {
  local dir="${1:-}" e="${PLAYBOOK_WINDOW:-}" v
  case "$e" in ''|*[!0-9]*) : ;; *) [ "$e" -gt 0 ] 2>/dev/null && { printf 'proven'; return 0; } ;; esac
  if [ -n "$dir" ]; then
    v="$(playbook_state_get "$dir" window_proven)"
    case "$v" in ''|*[!0-9]*) : ;; *) [ "$v" -gt 0 ] 2>/dev/null && { printf 'proven'; return 0; } ;; esac
  fi
  printf 'assumed'
}

playbook_json_escape() {
  local s="${1:-}"
  s="${s//\\/\\\\}"; s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"; s="${s//$'\r'/\\r}"; s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

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

playbook_global_file() {
  local name="${1:-}" dir path
  [ -n "$name" ] || { printf ''; return 0; }
  dir="${PLAYBOOK_GLOBAL_DIR:-${HOME}/.claude/playbook}"
  path="${dir}/${name}"
  [ -f "$path" ] || { printf ''; return 0; }
  { tr -d '\r' <"$path" \
      | awk 'NF{print; exit}' \
      | sed -E 's/^[[:space:]]+|[[:space:]]+$//g'
  } 2>/dev/null || printf ''
}

playbook_config_scalar() {
  local proj="${1:-}" name="${2:-}" v
  v="$(playbook_claude_file "$proj" "$name")"
  [ -n "$v" ] && { printf '%s' "$v"; return 0; }
  playbook_global_file "$name"
}

playbook_ntfy_topic()  { playbook_config_scalar "${1:-$PWD}" "ntfy-topic"; }
playbook_ntfy_server() { playbook_config_scalar "${1:-$PWD}" "ntfy-server"; }

playbook_notify_provider() { playbook_config_scalar "${1:-$PWD}" "notify-provider"; }

playbook_pushover_token() { playbook_config_scalar "${1:-$PWD}" "pushover-token"; }
playbook_pushover_user()  { playbook_config_scalar "${1:-$PWD}" "pushover-user"; }

playbook_settings_files() {
  local proj="${1:-$PWD}" f
  for f in "${HOME}/.claude/settings.json" \
           "${proj}/.claude/settings.json" \
           "${proj}/.claude/settings.local.json"; do
    [ -f "$f" ] && printf '%s\n' "$f"
  done
}

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

playbook_context_calm_resolved() {
  local proj="${1:-$PWD}" v g
  v="$(playbook_claude_file "$proj" "context-calm")"
  [ -n "$v" ] && { printf '%s' "$v"; return 0; }
  g="${HOME}/.claude/playbook/context-calm"
  [ -f "$g" ] || { printf ''; return 0; }
  { tr -d '\r' <"$g" | awk 'NF{print; exit}' \
      | sed -E 's/^[[:space:]]+|[[:space:]]+$//g'; } 2>/dev/null || printf ''
}

playbook_latest_transcript() {
  local proj="${1:-$PWD}" enc dir latest
  enc="$(printf '%s' "$proj" | tr '/' '-')"
  dir="${HOME}/.claude/projects/${enc}"
  [ -d "$dir" ] || { printf ''; return 0; }
  latest="$(ls -1t "$dir"/*.jsonl 2>/dev/null | awk 'NR==1')"
  [ -n "$latest" ] && [ -f "$latest" ] && printf '%s' "$latest" || printf ''
}

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
