#!/usr/bin/env bash

# @nonobvious(must-hold) every helper degrades to empty output, never a wrong value
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

playbook_northstar_line() {
  { printf '%s\n' "${1:-}" \
      | grep -E '^[[:space:]]*playbook-northstar:[[:space:]]*.' \
      | tail -n1 \
      | sed -E 's/^[[:space:]]*playbook-northstar:[[:space:]]*//; s/[[:space:]]+$//'
  } 2>/dev/null || printf ''
}

# @nonobvious(mirrors) the input-side usage sum Claude Code shows as used_percentage
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

# @nonobvious(means) exit 0 prints the question Claude's final reply asks the user, 1 means it asks nothing, 2 means the transcript is unreadable
playbook_final_ask() {
  local f; f="$(playbook_transcript_path "${1:-}")"
  [ -n "$f" ] && [ -f "$f" ] || return 2
  local bound="${PLAYBOOK_TAIL_BYTES:-262144}"
  case "$bound" in ''|*[!0-9]*) bound=262144 ;; esac
  local flt='
    def txt: if type=="array" then (map(select(.type=="text")|.text)|join("\n")) else "" end;
    def tidy: gsub("\\*\\*|__"; "") | gsub("\\s+"; " ") | gsub("^ | $"; "") | .[0:220];
    ( [ .[] | select(.type=="assistant") ] ) as $as
    | ($as | last) as $a
    | if $a == null then "state=none" else
        [ $as[] | select(.message.id == $a.message.id) ] as $turn
        | ( [ $turn[] | .message.content | if type=="array" then .[] else empty end
              | select(.type=="tool_use" and .name=="AskUserQuestion")
              | (.input.questions[0].question // "Claude has a question for you") ] | last ) as $q
        | if $q then "state=ask", ("text=" + ($q | tidy)) else
            ( [ $turn[] | .message.content | txt ] | join("\n")
              | [ splits("\n") | select(test("^\\s*(📚|🌡️|Playbook runs best on|Run `/effort)") | not) ] | join("\n")
              | gsub("```[\\s\\S]*?```"; "") | gsub("`[^`\\n]*`"; "") | gsub("https?://\\S+"; "")
              | [ splits("\n[ \t]*\n")
                  | select(test("\\?(?! (Yes|No|Zero|None|Nothing|Never)\\b)([\\s)\"'"'"'*_]|$)")
                           or test("\\b(I|I'"'"'ll|we) need (\\w+ ){0,4}(from you|before|to proceed|to continue|to start)|\\bto (proceed|continue|start|go further),? I need\\b|\\bbefore I (start|begin|proceed|continue)\\b|\\bwaiting (on|for) (you|your)\\b|\\b(your|you to) (call|decide|decision|confirm|choose|pick|approve|go-ahead)\\b|\\blet me know (which|whether|if|what)\\b|\\btell me (which|what|where|whether|how)\\b|\\b(I|we) need\\b[^.\\n]*:\\**\\s*(\\n|$)|\\bwhat I need\\b|\\b(decision|question)s? for you\\b|\\bonce you (answer|reply|confirm|choose|decide|tell|pick|send)\\b"; "i")) ]
              | last ) as $p
            | if $p then "state=ask", ("text=" + ($p | tidy)) else "state=done" end
          end
      end'
  local size out
  size="$(wc -c < "$f" 2>/dev/null | tr -d ' ')"
  case "$size" in ''|*[!0-9]*) size=0 ;; esac
  if [ "$size" -gt "$bound" ]; then
    out="$(tail -c "$bound" "$f" 2>/dev/null | tail -n +2 | jq -rs "$flt" 2>/dev/null)"
  else
    out="$(jq -rs "$flt" "$f" 2>/dev/null)"
  fi
  case "$out" in
    state=ask*) printf '%s' "$(sed -n 's/^text=//p' <<<"$out")"; return 0 ;;
    state=done*) return 1 ;;
    *) return 2 ;;
  esac
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

# @nonobvious(forced-by) Claude Code never auto-approves a write inside a .claude folder, so Playbook keeps everything it stores outside one
playbook_home() {
  printf '%s' "${XDG_STATE_HOME:-${HOME}/.local/state}/playbook"
}

playbook_state_root() {
  printf '%s' "${PLAYBOOK_STATE_DIR:-$(playbook_home)/sessions}"
}

# @nonobvious(mirrors) Playbook 2.8 kept these files in ~/.claude/playbook; they are copied once, never overwriting, and the old folder is left as it was
playbook_global_dir() {
  local d old
  if [ -n "${PLAYBOOK_GLOBAL_DIR:-}" ]; then printf '%s' "$PLAYBOOK_GLOBAL_DIR"; return 0; fi
  d="$(playbook_home)"; old="${HOME}/.claude/playbook"
  if [ ! -f "${d}/.moved" ]; then
    mkdir -p "$d" 2>/dev/null || true
    [ -d "$old" ] && cp -Rpn "${old}/." "${d}/" 2>/dev/null
    : > "${d}/.moved" 2>/dev/null || true
  fi
  printf '%s' "$d"
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

# @nonobvious(must-hold) temp-then-rename, so a reader never sees a torn file
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

playbook_state_gc() {
  local root; root="$(playbook_state_root)"
  case "$root" in ''|/) return 0 ;; esac
  [ -d "$root" ] || return 0
  find "$root" -mindepth 1 -maxdepth 1 -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true
  return 0
}

playbook_now() {
  local t="${PLAYBOOK_NOW:-}"
  [ -n "$t" ] || t="$(date +%s 2>/dev/null)"
  case "$t" in ''|*[!0-9]*) printf '0' ;; *) printf '%s' "$t" ;; esac
}

playbook_pid_alive() {
  local p="${1:-}"
  case "$p" in ''|*[!0-9]*) return 1 ;; esac
  kill -0 "$p" 2>/dev/null || return 1
  ps -o comm= -p "$p" 2>/dev/null | grep -qiE "${PLAYBOOK_OWNER_COMM:-claude}"
}

# @nonobvious(forced-by) a branched terminal keeps its parent's session id, so the live process, not the session, owns the state
playbook_live_dir() {
  local s="${1:-}" root sid base pid owner b f
  root="$(playbook_state_root)"
  [ -n "$root" ] || { printf ''; return 0; }
  sid="$(playbook_session_id "$s")"
  base="${root}/${sid}"
  if [ -z "${PLAYBOOK_STATE_DIR:-}" ] && [ ! -d "$base" ] && [ -d "${HOME}/.claude/hook-state/playbook/${sid}" ]; then
    mkdir -p "$root" 2>/dev/null && cp -Rp "${HOME}/.claude/hook-state/playbook/${sid}" "$base" 2>/dev/null
  fi
  mkdir -p "$base" 2>/dev/null || true
  pid="$(printf '%s' "${CLAUDE_PID:-}" | tr -cd '0-9')"
  [ -n "$pid" ] || { printf '%s' "$base"; return 0; }
  owner="$(cat "${base}/owner" 2>/dev/null | tr -cd '0-9')"
  if [ -z "$owner" ] || [ "$owner" = "$pid" ]; then
    [ "$owner" = "$pid" ] || printf '%s\n' "$pid" > "${base}/owner" 2>/dev/null
    printf '%s' "$base"; return 0
  fi
  b="${base}/branch-${pid}"
  [ -d "$b" ] && { printf '%s' "$b"; return 0; }
  if ! playbook_pid_alive "$owner"; then
    printf '%s\n' "$pid" > "${base}/owner" 2>/dev/null
    printf '%s' "$base"; return 0
  fi
  mkdir -p "$b" 2>/dev/null || { printf '%s' "$base"; return 0; }
  for f in "$base"/*; do
    [ -f "$f" ] || continue
    case "${f##*/}" in owner|offline|offline-log.jsonl|events.jsonl) continue ;; esac
    cp -p "$f" "$b/" 2>/dev/null || true
  done
  playbook_state_put "$b" "branch_notice=1"
  printf '%s' "$b"
}

playbook_state_dir() {
  local s="${1:-}" live aid dir
  live="$(playbook_live_dir "$s")"
  [ -n "$live" ] || { printf ''; return 0; }
  aid="$(playbook_agent_id "$s" | tr -cd 'A-Za-z0-9._-')"
  if [ -n "$aid" ]; then dir="${live}/agents/${aid}"; else dir="$live"; fi
  mkdir -p "$dir" 2>/dev/null || true
  printf '%s' "$dir"
}

playbook_team_dir() {
  local live name
  live="$(playbook_live_dir "${1:-}")"
  name="$(printf '%s' "${2:-}" | tr -cd 'A-Za-z0-9._-')"
  [ -n "$live" ] && [ -n "$name" ] || { printf ''; return 0; }
  mkdir -p "${live}/team/${name}" 2>/dev/null || true
  printf '%s' "${live}/team/${name}"
}

playbook_team_declare() {
  local d
  d="$(playbook_team_dir "${1:-}" "${2:-}")"
  [ -n "$d" ] || return 0
  playbook_state_put "$d" "declared=${3:-}" "waiting_on=$(printf '%s' "${4:-}" | tr '\n\r=' '   ')" "pushes=0" "declared_at=$(playbook_now)"
}

# @nonobvious(means) a hackathon message's kind is its first word, which is how the sender chooses how hard it interrupts
playbook_msg_tag() {
  local m w
  m="$(printf '%s' "${1:-}" | sed -E '1s/^[[:space:]]+//')"
  case "$m" in *:*) ;; *) return 0 ;; esac
  w="${m%%:*}"
  case "$w" in SOON|ASAP|URGENT|REGROUP|RESUME) printf '%s' "$w" ;; esac
}

playbook_msg_rest() {
  local m
  m="$(printf '%s' "${1:-}" | sed -E '1s/^[[:space:]]+//')"
  printf '%s' "${m#*:}" | sed -E '1s/^[[:space:]]+//'
}

# @nonobvious(means) a teammate's agent_id is "a<name>-<hex>"; the lead has none, and a name declared on the channel wins
playbook_crew_name() {
  local live="${1:-}" dir="${2:-}" aid="${3:-}" t n
  [ -n "$aid" ] || { printf 'lead'; return 0; }
  n="$(playbook_state_get "$dir" crew_name)"
  [ -n "$n" ] && { printf '%s' "$n"; return 0; }
  for t in "$live"/team/*/; do
    [ -d "$t" ] || continue
    n="$(basename "$t")"
    [ "$aid" = "$n" ] && { printf '%s' "$n"; return 0; }
    case "${aid#a}" in "$n"-*) case "${aid#a"$n"-}" in *[!0-9a-f]*|"") ;; *) printf '%s' "$n"; return 0 ;; esac ;; esac
  done
  printf 'teammate'
}

# @nonobvious(must-hold) any message to a teammate wakes it, so a waiting mark must not outlive the message that answers it
playbook_team_message() {
  local live name d
  live="$(playbook_live_dir "${1:-}")"
  name="$(printf '%s' "${2:-}" | tr -cd 'A-Za-z0-9._-')"
  [ -n "$live" ] && [ -n "$name" ] && [ -d "${live}/team/${name}" ] || return 0
  d="${live}/team/${name}"
  [ "$(playbook_state_get "$d" declared)" = "waiting" ] && playbook_state_put "$d" "declared=" "waiting_on="
  playbook_state_put "$d" "pushes=0"
}

# @nonobvious(must-hold) parallel tool calls fire hooks concurrently; one lock per state dir keeps read-modify-write updates from losing each other
playbook_lock() {
  local dir="${1:-}" lk i=0
  [ -n "$dir" ] || return 0
  [ -d "$dir" ] && [ -w "$dir" ] || return 0
  lk="${dir}/.lock"
  while ! mkdir "$lk" 2>/dev/null; do
    i=$(( i + 1 ))
    if [ "$i" -ge 200 ]; then rm -rf "$lk" 2>/dev/null; mkdir "$lk" 2>/dev/null; break; fi
    sleep 0.05 2>/dev/null || sleep 1
  done
  PLAYBOOK_LOCK_PATH="$lk"
  trap 'rm -rf "${PLAYBOOK_LOCK_PATH:-/nonexistent}" 2>/dev/null' EXIT
  return 0
}

playbook_unlock() {
  [ -n "${PLAYBOOK_LOCK_PATH:-}" ] && rm -rf "$PLAYBOOK_LOCK_PATH" 2>/dev/null
  PLAYBOOK_LOCK_PATH=""
  return 0
}

playbook_offline_on() {
  local dir="${1:-}"
  [ -n "$dir" ] && [ -f "${dir}/offline" ]
}

playbook_offline_set() {
  local dir="${1:-}" window="${2:-1}" wait="${3:-b}" quiet="${4:-0}" tmp
  [ -n "$dir" ] || return 0
  tmp="${dir}/offline.$$.tmp"
  printf 'window=%s\nwait=%s\nquiet=%s\nsince=%s\n' "$window" "$wait" "$quiet" "$(playbook_now)" > "$tmp" 2>/dev/null && mv -f "$tmp" "${dir}/offline"
}

playbook_offline_get() {
  local dir="${1:-}" key="${2:-}"
  [ -f "${dir}/offline" ] || { printf ''; return 0; }
  sed -n "s/^${key}=//p" "${dir}/offline" 2>/dev/null | tail -n1
}

playbook_offline_log() {
  local dir="${1:-}" summary="${2:-}" reason="${3:-}"
  jq -cn --argjson ts "$(playbook_now)" --arg s "$summary" --arg r "$reason" '{event:"decision", ts:$ts, summary:$s, reason:$r}' \
    >> "${dir}/offline-log.jsonl" 2>/dev/null || true
}

# @nonobvious(means) the "Oversight:" answer is read from its words, so a decorated label still maps: oversee means online, autonomous means a judge with no wait and no pushes, a number of minutes means wait that long, anything else naming a judge means no wait
playbook_oversight_apply() {
  local dir="${1:-}" a n
  a="$(printf '%s' "${2:-}" | tr 'A-Z' 'a-z')"
  case "$a" in
    *oversee*|*"i'll"*|*myself*) rm -f "${dir}/offline" 2>/dev/null; printf 'online' ;;
    *autonomous*) playbook_offline_set "$dir" 1 b 1; printf 'autonomous' ;;
    *judge*)
      n="$(printf '%s' "$a" | grep -oE '[0-9]+' | head -n1)"
      if [ -n "$n" ] && [ "$n" -gt 0 ]; then playbook_offline_set "$dir" "$n" a; printf 'judge after %s min' "$n"
      else playbook_offline_set "$dir" 1 b; printf 'judge now'; fi ;;
    *) printf '' ;;
  esac
}

# @nonobvious(means) a judge overseeing means a workflow-heavy run the user is not there to opt into launch by launch, so the session-wide switch is asked for once instead of the typed word
playbook_offline_optin_line() {
  local lvl="${1:-}"
  printf '%s' "Playbook workflows opt-in while a judge oversees: the run is likely to be workflow-heavy and the user will not be there to type \"use ultracode\" before each launch, so settle the plan, then ask them now to run \`/effort ultracode\` instead. Warn them that it stays on for the whole session and pushes towards a workflow on every task, and remind them in the closing report to switch back with \`/effort ${lvl:-<their earlier level>}\`. The dispatch guard lets a launch through once it is on. If it is still off when you are ready to launch, wait out the user's window if they set one, then take the next-ranked mode and log why; never leave the run waiting on it."
}

playbook_notify_bg() {
  local level="${1:-info}" head="${2:-}" detail="${3:-}" n
  n="${CLAUDE_PLUGIN_ROOT:-}/scripts/notify"
  [ -f "$n" ] || return 0
  ( bash "$n" --level "$level" "$head" "$detail" >/dev/null 2>&1 & ) 2>/dev/null || true
}

PLAYBOOK_MODES="lone-wolf interns hackathon workflows gsd"

playbook_mode_emoji() {
  case "${1:-}" in
    lone-wolf) printf '🐺' ;; interns) printf '🐜' ;; hackathon) printf '🤝' ;;
    workflows) printf '⚙️' ;; gsd) printf '🏗️' ;; *) printf '📚' ;;
  esac
}

# @nonobvious(means) a picker label can carry more than the mode ("🐜 interns", "Goal: x · Mode: hackathon team (Recommended)"), so the first mode named after any "Mode:" wins
playbook_mode_canon() {
  local m
  m="$(printf '%s' "${1:-}" | tr 'A-Z' 'a-z' | sed -E 's/.*mode:[[:space:]]*//; s/\(recommended\)//g; s/lone[-_ ]?wolf/lone-wolf/g; s/workflow([^s]|$)/workflows\1/g' \
    | grep -oE '(^|[^a-z-])(lone-wolf|interns|hackathon|workflows|gsd)([^a-z-]|$)' | head -n1 | tr -cd 'a-z-')"
  case " $PLAYBOOK_MODES " in *" $m "*) printf '%s' "$m" ;; *) printf '' ;; esac
}

# @nonobvious(forced-by) Claude Code's own example Workflow script gives its review and verify agent() calls no model, and scripts copy it
PLAYBOOK_WF_MODEL_LINE="Playbook: give every agent() call in the Workflow script a model key, reviewers and verifiers included: Sonnet builds and checks, Opus plans and judges."

PLAYBOOK_REVIEW_LINE4="Only a bug earns another round. If two rounds still find bugs, stop reviewing and take a beat: simplify, accept a contained risk, or ask. Anything bigger than a fix needs a serious assessment and sign-off from a judge or the user; on money or security code, ask."

PLAYBOOK_SCOPE_RULE="Going against one of the user's decisions is never a judge's call. More scope is, when the user's goal needs it and it is achievable. A minor unrelated bug fix or a nice-to-have change waits until the work has been delivered, then goes to the user as a possible extension."

PLAYBOOK_WEIGH_TEXT="Playbook: a review just came back. Take a beat before you act. A review almost never comes back empty, so findings are expected, and a bug found is not always a bug to fix: that depends on context and judgement, which is what this pause is for. Ask: am I delivering the spirit of the user's request and the needs they gave me? If not, what would? That can mean less scope or more. Record your call with \`playbook weigh fix \"<what you will fix, what you will list for the user, whether another round is needed>\"\`. If the answer is bigger than a fix (a new approach, a redesign, more scope), assess it seriously and record it with \`playbook weigh bigger \"<your assessment>\"\`: it then needs sign-off from a judge or the user. A judge may sign off on scope the user's goal needs and that is achievable. A minor unrelated bug fix or a nice-to-have change waits until the work has been delivered, then goes to the user as a possible extension. Until you record your call, edits, shell writes and dispatches are held; reading, tests, messages and questions still run."

PLAYBOOK_WEIGH_BIGGER="Playbook: your call on the review is bigger than a fix, so edits, shell writes and dispatches are held until it is signed off by a judge or the user. Consult a judge (a fresh Opus Agent in the foreground whose description starts \`judge:\`, or codex:codex-rescue) with your assessment and the user's decisions, or ask the user in AskUserQuestion; a typed sign-off counts once you record it with \`playbook decision \"<their exact words>\"\`. ${PLAYBOOK_SCOPE_RULE}"

# @nonobvious(mirrors) the replay scorer's patterns, so the hooks reproduce its stops; the case-sensitive ones are case-sensitive there too
playbook_match() {
  local kind="${1:-}" text="${2:-}" re fl="i"
  case "$kind" in
    test)     fl=""; re='(npm|pnpm|yarn|bun)\s+(run\s+)?test|vitest|\bjest\b|pytest|go test|cargo test|xcodebuild[^|\n]*\btest\b|swift test|deno test|playwright test|supabase test|pg_prove|\bbats\b|run-all\.sh|make test' ;;
    commit)   fl=""; re='git commit|gh pr merge|git add\b' ;;
    merge)    fl=""; re='(^|[;&|]|&&)\s*(gh pr merge\b|git merge(?![-\w])(?!\s+--(abort|quit)\b))' ;;
    benign)   fl=""; re='^\s*(grep|rg|test|\[|ls|find|diff|which|command -v|cmp|pgrep|git diff --quiet)\b' ;;
    signing)  re='gpg|signing|touch ?id|ssh-agent|publickey|1password' ;;
    hookblock) fl=""; re='hook error|Blocked|rejected|doesn.t want to proceed|denied' ;;
    correct)  re="^\\s*(no|nope|wrong)\\b|\\b(that's not right|didn't work|doesn't work|isn't working|still (not|broken|failing|doesn't|isn't))\\b" ;;
    frust)    re="overkill|scope creep|ran out of usage|it's been quite|hours now|\\bETA\\b|stop working|kill (all|these|both)|how long (is|will) (this|it)|taking (so )?long" ;;
    spec)     re="never asked for|you promised|remember the exact spec|i explicitly told you|i told you (to|not)|not what i asked|that's not what i" ;;
    go)       re="^\\s*(go|go ahead|go on|yes,? go|approved)\\b|\\bgo on all fronts\\b|(give|gave|giving|sending) the ['\"]?go\\b|\\bapproved\\b|\\blgtm\\b|\\bthanks\\b|\\bgreat\\b|\\bperfect\\b|looks good" ;;
    away)     re="going to bed|goodnight|i'll be (offline|away|back)|i'm offline|be back|signing off|i'll stay waiting|touch ?id|gpg|stage (things|changes)" ;;
    stop)     re='stop working|stop all|pause (development|work)|kill (all|these|both)' ;;
    waitme)   re='(waiting|wait) (for|on) (your|you to)|needs your (touch ?id|approval|signature)|blocked on (signing|touch ?id|you)' ;;
    review)   re='\breview|verify|audit|redteam|adjud' ;;
    *) return 1 ;;
  esac
  jq -en --arg t "$text" --arg re "$re" --arg f "$fl" '$t | test($re; $f)' >/dev/null 2>&1
}

# @nonobvious(means) the user's own messages only: meta records, pasted blocks, peer and teammate messages and continuation summaries are not the user speaking
# @nonobvious(means) Claude Code wraps text the user pasted in pasted_content lines; it is something they quoted, not their own words, but the words around it are
playbook_strip_pasted() {
  printf '%s\n' "${1:-}" | awk '/<pasted_content id="[^"]*">/{skip=1; next} /<\/pasted_content id="[^"]*">/{skip=0; next} !skip'
}

playbook_is_human_text() {
  local t="${1:-}"
  [ -n "$t" ] || return 1
  case "$t" in *'<pasted_content'*) t="$(playbook_strip_pasted "$t" | sed '/^[[:space:]]*`*[[:space:]]*$/d')"; [ -n "$(printf '%s' "$t" | tr -d '[:space:]')" ] || return 1 ;; esac
  case "$t" in '<'*|'This session is being continued'*|'Another Claude'*) return 1 ;; esac
  case "${t:0:200}" in *teammate-message*) return 1 ;; esac
  return 0
}

playbook_weight() {
  case "${1:-}" in
    fail_streak|rewrite_after_fail|no_progress|dispatch_burst|active_hours|ns_hours) printf '10' ;;
    test_fail|correction|review_repeat) printf '20' ;;
    test_fail_repeat|frustration|spec_drift) printf '40' ;;
    test_pass) printf '%s' '-30' ;;
    commit) printf '%s' '-20' ;;
    *) printf '0' ;;
  esac
}

playbook_weak() {
  case "${1:-}" in no_progress|dispatch_burst|active_hours|ns_hours|rewrite_after_fail) return 0 ;; esac
  return 1
}

playbook_score10() { playbook_state_int "${1:-}" score10 0; }

playbook_level_of() {
  local s="${1:-0}"
  case "$s" in ''|*[!0-9]*) s=0 ;; esac
  if [ "$s" -ge 150 ]; then printf '3'
  elif [ "$s" -ge 100 ]; then printf '2'
  elif [ "$s" -ge 50 ]; then printf '1'
  else printf '0'; fi
}

playbook_level_name() {
  case "${1:-0}" in 1) printf 'uneasy' ;; 2) printf 'concerned' ;; 3) printf 'alarmed' ;; *) printf 'calm' ;; esac
}

playbook_level_rank() {
  case "${1:-}" in uneasy) printf '1' ;; concerned) printf '2' ;; alarmed) printf '3' ;; *) printf '' ;; esac
}

playbook_score_text() {
  local s; s="$(playbook_score10 "${1:-}")"
  printf '%s.%s' "$(( s / 10 ))" "$(( s % 10 ))"
}

playbook_engaged() {
  local dir="${1:-}" now="${2:-}" h
  [ -n "$now" ] || now="$(playbook_now)"
  h="$(playbook_state_int "$dir" last_human_ts 0)"
  [ "$h" -gt 0 ] && [ $(( now - h )) -lt 1200 ]
}

playbook_score_add() {
  local dir="${1:-}" key="${2:-}" reason="${3:-}" w s
  [ -n "$dir" ] && [ -n "$key" ] || return 0
  w="$(playbook_weight "$key")"
  [ "$w" = "0" ] && return 0
  if playbook_weak "$key" && playbook_engaged "$dir"; then w=$(( w / 2 )); fi
  s="$(playbook_score10 "$dir")"
  s=$(( s + w )); [ "$s" -lt 0 ] && s=0
  playbook_state_put "$dir" "score10=${s}"
  [ -n "$reason" ] || reason="$key"
  printf '%s\t%s\t%s\n' "$(playbook_now)" "$w" "$(printf '%s' "$reason" | tr '\t\n\r' '   ')" >> "${dir}/contrib" 2>/dev/null || true
  if [ -f "${dir}/contrib" ] && [ "$(wc -l < "${dir}/contrib" | tr -d ' ')" -gt 40 ]; then
    { tail -n 40 "${dir}/contrib" > "${dir}/contrib.$$" && mv -f "${dir}/contrib.$$" "${dir}/contrib"; } 2>/dev/null || rm -f "${dir}/contrib.$$"
  fi
  return 0
}

playbook_score_halve() {
  local dir="${1:-}" s
  [ -n "$dir" ] || return 0
  s="$(playbook_score10 "$dir")"
  playbook_state_put "$dir" "score10=$(( s / 2 ))"
}

# @nonobvious(must-hold) a self-report only ever raises the score
playbook_score_floor() {
  local dir="${1:-}" lvl="${2:-}" thr s
  case "$lvl" in uneasy) thr=50 ;; concerned) thr=100 ;; alarmed) thr=150 ;; *) return 0 ;; esac
  s="$(playbook_score10 "$dir")"
  [ "$s" -lt "$thr" ] && playbook_state_put "$dir" "score10=${thr}"
  return 0
}

playbook_top_reasons() {
  local dir="${1:-}"
  [ -f "${dir}/contrib" ] || { printf ''; return 0; }
  awk -F'\t' '$2>0{c[$3]+=$2} END{for(k in c) printf "%d\t%s\n", c[k], k}' "${dir}/contrib" 2>/dev/null \
    | sort -rn | head -n 3 | cut -f2 | paste -sd ';' - | sed 's/;/; /g'
}

playbook_gate() { playbook_state_get "${1:-}" gate; }

playbook_gate_rank() { case "${1:-}" in rethink) printf '1' ;; judge) printf '2' ;; ask) printf '3' ;; *) printf '0' ;; esac; }

playbook_gate_set() {
  local dir="${1:-}" g="${2:-}" cur
  cur="$(playbook_gate "$dir")"
  [ "$(playbook_gate_rank "$g")" -gt "$(playbook_gate_rank "$cur")" ] && playbook_state_put "$dir" "gate=${g}"
  return 0
}

playbook_gate_clear() {
  local dir="${1:-}" which="${2:-all}" cur
  cur="$(playbook_gate "$dir")"
  [ -n "$cur" ] || return 0
  if [ "$which" = "all" ] || [ "$which" = "$cur" ]; then playbook_state_put "$dir" "gate="; fi
  return 0
}

playbook_event_push() {
  local dir="${1:-}" text="${2:-}"
  [ -n "$dir" ] && [ -n "$text" ] || return 0
  jq -cn --arg t "$text" '$t' >> "${dir}/events.jsonl" 2>/dev/null || true
}

# @nonobvious(must-hold) the rename claims the queue, so two hooks draining at once never inject one event twice
playbook_event_drain() {
  local dir="${1:-}" claim
  [ -n "$dir" ] && [ -s "${dir}/events.jsonl" ] || { printf ''; return 0; }
  claim="${dir}/events.claim.$$.${RANDOM}"
  mv "${dir}/events.jsonl" "$claim" 2>/dev/null || { printf ''; return 0; }
  jq -rs 'map(select(type=="string" and length>0)) | reduce .[] as $e ([]; if index([$e]) != null then . else . + [$e] end) | join("\n\n")' "$claim" 2>/dev/null
  rm -f "$claim" 2>/dev/null || true
}

playbook_score_settle() {
  local dir="${1:-}" s new old now ca why
  [ -n "$dir" ] || return 0
  s="$(playbook_score10 "$dir")"
  new="$(playbook_level_of "$s")"
  old="$(playbook_state_int "$dir" level 0)"
  now="$(playbook_now)"
  if [ "$new" -gt "$old" ] && [ "$(playbook_state_get "$dir" stopped)" != "1" ]; then
    why="$(playbook_top_reasons "$dir")"; [ -n "$why" ] && why=" (${why})"
    if [ "$new" -eq 2 ]; then
      ca="$(playbook_state_int "$dir" concerned_at 0)"
      if [ "$ca" -gt 0 ] && [ $(( now - ca )) -le 7200 ]; then new=3; why="${why} and a second concerned within 2 hours"; fi
    fi
    [ "$new" -ge 2 ] && playbook_state_put "$dir" "concerned_at=${now}"
    case "$new" in
      1)
        playbook_gate_set "$dir" rethink
        playbook_event_push "$dir" "Playbook unease: uneasy, score $(playbook_score_text "$dir")${why}. Before your next edit or dispatch, stop and reconsider: write one line on what changes with \`playbook rethink <what changes>\`." ;;
      2)
        playbook_gate_set "$dir" judge
        playbook_event_push "$dir" "Playbook unease: concerned, score $(playbook_score_text "$dir")${why}. New edits and dispatches are held until a judge has been consulted: dispatch a fresh Opus Agent in the foreground whose description starts \`judge:\`, or codex:codex-rescue, with the evidence and the user's decisions, then act on its view. Its return halves the score." ;;
      3)
        playbook_state_put "$dir" "score10=50"
        playbook_gate_set "$dir" ask
        if playbook_offline_on "$dir"; then
          playbook_event_push "$dir" "Playbook unease: alarmed${why}. The user is offline: push a notification with scripts/notify --level action stating the problem, wait the declared window, then consult an outside judge (codex:codex-rescue, or a fresh Opus Agent whose description starts \`judge:\`) and log the call. New edits and dispatches stay held until the judge returns. ${PLAYBOOK_SCOPE_RULE}"
        else
          playbook_event_push "$dir" "Playbook unease: alarmed${why}. Stop and consult a judge: a fresh Opus Agent in the foreground whose description starts \`judge:\`, or codex:codex-rescue, with the evidence and the user's decisions. If the user is here, you may ask them in AskUserQuestion instead. New edits and dispatches stay held until one of them answers."
        fi ;;
    esac
  fi
  playbook_state_put "$dir" "level=$(playbook_level_of "$(playbook_score10 "$dir")")"
  return 0
}

playbook_progress_reset() {
  playbook_state_put "${1:-}" "batches_np=0" "disp_np=0" "active_np=0"
}

playbook_tick() {
  local dir="${1:-}" now="${2:-}" prev dt a n
  [ -n "$dir" ] || return 0
  [ -n "$now" ] || now="$(playbook_now)"
  prev="$(playbook_state_int "$dir" last_ts 0)"
  playbook_state_put "$dir" "last_ts=${now}"
  [ "$prev" -gt 0 ] || return 0
  dt=$(( now - prev ))
  [ "$dt" -gt 0 ] && [ "$dt" -lt 1800 ] || return 0
  [ "$(playbook_state_get "$dir" away)" = "1" ] && return 0
  a=$(( $(playbook_state_int "$dir" active_np 0) + dt ))
  n=$(( $(playbook_state_int "$dir" ns_active 0) + dt ))
  if [ "$a" -ge 7200 ]; then playbook_score_add "$dir" active_hours "2 active hours without progress"; a=0; fi
  if [ "$n" -ge 7200 ]; then playbook_score_add "$dir" ns_hours "2 more active hours on this goal"; n=0; fi
  playbook_state_put "$dir" "active_np=${a}" "ns_active=${n}"
}

playbook_batch() {
  local dir="${1:-}" b
  [ -n "$dir" ] || return 0
  [ "$(playbook_state_get "$dir" away)" = "1" ] && return 0
  b=$(( $(playbook_state_int "$dir" batches_np 0) + 1 ))
  if [ "$b" -ge 60 ]; then playbook_score_add "$dir" no_progress "60 tool batches without progress"; b=0; fi
  playbook_state_put "$dir" "batches_np=${b}"
}

playbook_dispatch_count() {
  local dir="${1:-}" d
  [ -n "$dir" ] || return 0
  [ "$(playbook_state_get "$dir" away)" = "1" ] && return 0
  d=$(( $(playbook_state_int "$dir" disp_np 0) + 1 ))
  [ $(( d % 8 )) -eq 0 ] && playbook_score_add "$dir" dispatch_burst "8 more dispatches without progress"
  playbook_state_put "$dir" "disp_np=${d}"
}

playbook_norm_cmd() {
  printf '%s' "${1:-}" | tr '\n\t\r' '   ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//' | cut -c1-120
}

# @nonobvious(means) a test runner named inside a search, a print or a quoted argument is not a test run; only a command segment that runs it is
playbook_is_test_cmd() {
  local c="${1:-}" seg head
  playbook_match test "$c" || return 1
  while IFS= read -r seg; do
    seg="$(printf '%s' "$seg" | sed -E 's/^[[:space:]]+//; s/^([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)+//; s/^((time|sudo|nice|exec)[[:space:]]+)+//')"
    head="${seg%%[[:space:]]*}"; head="${head##*/}"
    case "$head" in
      "" | grep | egrep | fgrep | rg | ag | ack | cat | bat | head | tail | less | more | sed | awk | jq | yq | echo | printf \
        | ls | find | fd | wc | diff | git | gh | which | type | command | whereis | file | stat | vim | vi | nano | code \
        | open | cp | mv | rm | ln | mkdir | touch | chmod | tee | sort | uniq | cut | tr | xargs) continue ;;
    esac
    playbook_match test "$seg" && return 0
  done < <(printf '%s\n' "$c" | sed -E "s/'[^']*'/Q/g; s/\"[^\"]*\"/Q/g" | awk '{ gsub(/&&|\|\||;|\|/, "\n"); print }')
  return 1
}

playbook_bash_result() {
  local dir="${1:-}" cmd="${2:-}" failed="${3:-0}" body="${4:-}" key fs
  [ -n "$dir" ] || return 0
  if playbook_is_test_cmd "$cmd"; then
    key="$(playbook_norm_cmd "$cmd" | cksum | cut -d' ' -f1)"
    if [ "$failed" = "1" ]; then
      if [ "$(playbook_state_get "$dir" last_failed_key)" = "$key" ]; then
        playbook_score_add "$dir" test_fail_repeat "the same test failed again"
      else
        playbook_score_add "$dir" test_fail "a test failed"
      fi
      playbook_state_put "$dir" "last_failed_key=${key}" "failed_since_pass=1"
    else
      [ "$(playbook_state_get "$dir" failed_since_pass)" = "1" ] && playbook_score_add "$dir" test_pass "a test passed after failing"
      playbook_state_put "$dir" "failed_since_pass=0" "last_failed_key="
      : > "${dir}/edits" 2>/dev/null || true
      playbook_progress_reset "$dir"
    fi
    playbook_state_put "$dir" "fail_streak=0"
  elif [ "$failed" != "1" ] && playbook_match commit "$cmd"; then
    playbook_score_add "$dir" commit "a commit, stage or merge"
    playbook_progress_reset "$dir"
    playbook_state_put "$dir" "fail_streak=0"
  elif [ "$failed" = "1" ] && ! playbook_match benign "$cmd" && ! playbook_match signing "$body" && ! playbook_match hookblock "$body"; then
    fs=$(( $(playbook_state_int "$dir" fail_streak 0) + 1 ))
    playbook_state_put "$dir" "fail_streak=${fs}"
    [ "$fs" -ge 3 ] && playbook_score_add "$dir" fail_streak "3 or more tool failures in a row"
  elif [ "$failed" != "1" ]; then
    playbook_state_put "$dir" "fail_streak=0"
  fi
  if [ "$failed" != "1" ] && playbook_match merge "$cmd"; then playbook_ns_mark "$dir" stale "a merge landed"; fi
  return 0
}

playbook_tool_result() {
  local dir="${1:-}" failed="${2:-0}" body="${3:-}" fs
  [ -n "$dir" ] || return 0
  if [ "$failed" = "1" ]; then
    playbook_match signing "$body" && return 0
    playbook_match hookblock "$body" && return 0
    fs=$(( $(playbook_state_int "$dir" fail_streak 0) + 1 ))
    playbook_state_put "$dir" "fail_streak=${fs}"
    [ "$fs" -ge 3 ] && playbook_score_add "$dir" fail_streak "3 or more tool failures in a row"
  else
    playbook_state_put "$dir" "fail_streak=0"
  fi
  return 0
}

playbook_edit_done() {
  local dir="${1:-}" path n
  path="$(printf '%s' "${2:-}" | tr -d '\n\r')"
  [ -n "$dir" ] && [ -n "$path" ] || return 0
  printf '%s\n' "$path" >> "${dir}/edits" 2>/dev/null || true
  [ "$(playbook_state_get "$dir" failed_since_pass)" = "1" ] || return 0
  n="$(grep -cxF -- "$path" "${dir}/edits" 2>/dev/null)"
  case "$n" in 3|4|5) playbook_score_add "$dir" rewrite_after_fail "rewrote a file while tests fail" ;; esac
  return 0
}

playbook_append_capped() {
  local file="${1:-}" line="${2:-}" cap="${3:-6000}"
  [ -n "$file" ] || return 0
  printf '%s\n' "$line" >> "$file" 2>/dev/null || return 0
  while [ "$(wc -c < "$file" | tr -d ' ')" -gt "$cap" ] && [ "$(wc -l < "$file" | tr -d ' ')" -gt 1 ]; do
    { tail -n +2 "$file" > "${file}.$$" && mv -f "${file}.$$" "$file"; } 2>/dev/null || break
  done
}

# @nonobvious(means) returns 1 when the text is not the user's own words, so the caller injects nothing on its behalf
playbook_human_message() {
  local dir="${1:-}" text="${2:-}" now="${3:-}" key last kind=""
  [ -n "$dir" ] || return 1
  playbook_is_human_text "$text" || return 1
  case "$text" in *'<pasted_content'*) text="$(playbook_strip_pasted "$text")" ;; esac
  [ -n "$now" ] || now="$(playbook_now)"
  if [ "${PLAYBOOK_DEDUPE_HUMAN:-}" = "1" ]; then
    key="$(printf '%s' "${text:0:300}" | cksum | cut -d' ' -f1)"
    if grep -qxF "$key" "${dir}/seen_human" 2>/dev/null; then return 0; fi
    printf '%s\n' "$key" >> "${dir}/seen_human" 2>/dev/null || true
  fi
  last="$(playbook_state_int "$dir" last_ts 0)"
  if [ "$last" -gt 0 ] && [ $(( now - last )) -gt 28800 ]; then
    playbook_score_halve "$dir"
    playbook_state_put "$dir" "ns_active=0" "route_mode=" "route_reason="
    playbook_ns_mark "$dir" stale "more than 8 hours passed"
  fi
  if playbook_match spec "$text"; then
    kind=spec
    playbook_score_add "$dir" spec_drift "the user: spec drift"
    playbook_event_push "$dir" "Playbook North Star check: the user's words suggest the work has drifted from what they asked for. Re-read their words$( [ -n "$(playbook_ns_goal "$dir")" ] && printf ' and the confirmed goal: %s' "$(playbook_ns_goal "$dir")"), and if the goal is in doubt, ask them."
  elif playbook_match frust "$text"; then
    kind=frust
    playbook_score_add "$dir" frustration "the user: frustration"
  elif playbook_match correct "$text"; then
    playbook_score_add "$dir" correction "the user: correction"
  fi
  if [ -z "$kind" ] && playbook_match go "$text"; then
    playbook_score_halve "$dir"
    playbook_state_put "$dir" "ns_active=0"
    playbook_progress_reset "$dir"
  fi
  playbook_user_answered "$dir" "$now"
  if playbook_match away "$text"; then playbook_state_put "$dir" "away=1"; else playbook_state_put "$dir" "away=0"; fi
  if playbook_match stop "$text"; then playbook_state_put "$dir" "stopped=1"; else playbook_state_put "$dir" "stopped=0"; fi
  playbook_tick "$dir" "$now"
  playbook_state_put "$dir" "last_human_ts=${now}"
  playbook_append_capped "${dir}/prompts.jsonl" "$(jq -cn --arg t "$text" --argjson at "$now" '{at:$at,text:$t}')" 6000
  playbook_append_capped "${dir}/human.jsonl" "$(jq -cn --arg t "$text" --argjson at "$now" '{at:$at,text:$t}')" 400000
  playbook_score_settle "$dir"
  return 0
}

# @nonobvious(means) the user has spoken, typed or through AskUserQuestion; like a judge's return, this releases an alarmed gate and a held review round
playbook_user_answered() {
  local dir="${1:-}" now="${2:-}"
  [ -n "$dir" ] || return 0
  [ -n "$now" ] || now="$(playbook_now)"
  playbook_gate_clear "$dir" ask
  if [ -n "$(playbook_state_get "$dir" review_hold)" ]; then
    printf '%s\n' "$(playbook_state_get "$dir" review_hold)" >> "${dir}/review_cleared" 2>/dev/null || true
    playbook_state_put "$dir" "review_hold="
  fi
  playbook_state_put "$dir" "last_human_ts=${now}" "away=0"
}

playbook_words_found() {
  local dir="${1:-}" words="${2:-}"
  [ -n "$dir" ] && [ -n "$words" ] && [ -f "${dir}/human.jsonl" ] || return 1
  jq -es --arg w "$words" '
    def norm: ascii_downcase | gsub("[\\s]+"; " ") | gsub("^ | $"; "");
    ($w | norm) as $n | ($n | length) > 0 and any(.[]; (.text | norm) | contains($n))' "${dir}/human.jsonl" >/dev/null 2>&1
}

playbook_decision_add() {
  local dir="${1:-}" source="${2:-}" q="${3:-}" a="${4:-}"
  [ -n "$dir" ] && [ -n "$a" ] || return 0
  jq -cn --arg s "$source" --arg q "$q" --arg a "$a" --argjson at "$(playbook_now)" '{at:$at,source:$s,question:$q,answer:$a}' \
    >> "${dir}/decisions.jsonl" 2>/dev/null || return 0
  jq -rs 'to_entries | map("\(.key + 1). " + (if (.value.question // "") != "" then "Asked: \(.value.question)\n   Answer: " else "" end) + "\"\(.value.answer)\"") | join("\n")' \
    "${dir}/decisions.jsonl" > "${dir}/decisions.txt" 2>/dev/null || true
  playbook_event_push "$dir" "Playbook decision recorded, verbatim: \"${a}\". It outranks you and every helper, reviewer, judge and reviser; quote it, and treat a conflict with it as a question for the user."
}

playbook_decisions_text() {
  local dir="${1:-}" budget="${2:-6000}" t
  [ -s "${dir}/decisions.txt" ] || { printf ''; return 0; }
  t="$(cat "${dir}/decisions.txt" 2>/dev/null)"
  if [ "${#t}" -gt "$budget" ]; then
    printf '%s\n(The rest are in %s; read it.)' "${t:0:$budget}" "${dir}/decisions.txt"
  else
    printf '%s' "$t"
  fi
}

playbook_ns_state() { playbook_state_get "${1:-}" ns_state; }
playbook_ns_goal()  { playbook_state_get "${1:-}" ns_goal; }

playbook_ns_confirm() {
  local dir="${1:-}" goal mode="${3:-}" source="${4:-picker}" id now
  goal="$(printf '%s' "${2:-}" | tr '\n\r' '  ' | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
  [ -n "$dir" ] && [ -n "$goal" ] || return 0
  now="$(playbook_now)"
  id=$(( $(playbook_state_int "$dir" ns_id 0) + 1 ))
  playbook_state_put "$dir" "ns_goal=${goal}" "ns_mode=${mode}" "ns_state=confirmed" "ns_at=${now}" \
    "ns_id=${id}" "ns_source=${source}" "ns_changed_at=${now}" "ns_active=0"
  playbook_optin_track "$dir" "$mode" fresh
  if [ -f "${dir}/prompts.jsonl" ]; then mv -f "${dir}/prompts.jsonl" "${dir}/ns_words.jsonl" 2>/dev/null || true
  else : > "${dir}/ns_words.jsonl" 2>/dev/null || true; fi
  playbook_score_halve "$dir"
  playbook_event_push "$dir" "Playbook North Star confirmed: ${goal}${mode:+ · mode ${mode}}. It travels into every helper and back after compaction."
}

playbook_ns_mark() {
  local dir="${1:-}" st="${2:-}" why="${3:-}"
  [ -n "$dir" ] || return 0
  [ "$(playbook_ns_state "$dir")" = "confirmed" ] || return 0
  playbook_state_put "$dir" "ns_state=${st}" "ns_changed_at=$(playbook_now)"
  case "$st" in
    stale) playbook_event_push "$dir" "Playbook North Star is stale (${why}): $(playbook_ns_goal "$dir"). Before the next dispatch, confirm the goal with the user again in the picker, or declare a single-option route." ;;
    done)  playbook_event_push "$dir" "Playbook North Star marked complete: $(playbook_ns_goal "$dir"). New work needs a new goal." ;;
  esac
}

playbook_ns_words_text() {
  local dir="${1:-}"
  [ -s "${dir}/ns_words.jsonl" ] || { printf ''; return 0; }
  jq -rs 'map(.text) | join("\n---\n")' "${dir}/ns_words.jsonl" 2>/dev/null
}

playbook_route_set() {
  local dir="${1:-}" mode="${2:-}" reason="${3:-}"
  [ -n "$dir" ] && [ -n "$mode" ] || return 0
  playbook_state_put "$dir" "route_mode=${mode}" "route_reason=$(printf '%s' "$reason" | tr '\n\r=' '   ')" "route_at=$(playbook_now)"
  playbook_optin_track "$dir" "$mode"
}

playbook_optin_track() {
  local dir="${1:-}" mode="${2:-}" fresh="${3:-}"
  if [ "$mode" = "workflows" ]; then
    if [ -n "$fresh" ] || [ "$(playbook_state_get "$dir" wf_optin)" != "ok" ]; then playbook_state_put "$dir" "wf_optin=pending"; fi
  else
    playbook_state_put "$dir" "wf_optin=" "wf_optin_fails=0" "wf_optin_fail_turn="
  fi
}

# @nonobvious(mirrors) Claude Code 2.1.311 decides ultracode from the last ultra_effort_enter or ultra_effort_exit attachment in the transcript, and records a typed "ultracode" as a workflow_keyword_request attachment; neither is documented, so a rename reads as no opt-in
playbook_ultracode_on() {
  local t="${1:-}" last
  [ -n "$t" ] && [ -f "$t" ] || return 1
  last="$(grep -oE '"attachment":\{"type":"ultra_effort_(enter|exit)"' "$t" 2>/dev/null | tail -n1)"
  case "$last" in *enter*) return 0 ;; esac
  return 1
}

playbook_keyword_since() {
  local t="${1:-}" since="${2:-0}" ts
  [ -n "$t" ] && [ -f "$t" ] || return 1
  ts="$(grep -F '"attachment":{"type":"workflow_keyword_request"' "$t" 2>/dev/null | tail -n1 \
    | jq -r '.timestamp // empty | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601' 2>/dev/null)"
  case "$ts" in ''|*[!0-9]*) return 1 ;; esac
  [ "$ts" -ge $(( since - 5 )) ]
}

# @nonobvious(means) a Workflow launch is opted in by a typed "ultracode" in this turn, ultracode switched on, or /playbook:workflow typed this turn, which is itself the user's ask
playbook_optin_ok() {
  local dir="${1:-}" t="${2:-}" turn
  [ "${PLAYBOOK_OPTIN_CHECK:-}" = "off" ] && return 0
  turn="$(playbook_state_int "$dir" turn_at 0)"
  [ "$(playbook_state_get "$dir" turn_wf)" = "1" ] && return 0
  playbook_ultracode_on "$t" && return 0
  playbook_keyword_since "$t" "$turn"
}

# @nonobvious(means) a declared route with no goal confirmed after it is the single-option case, whose helpers run with no North Star
playbook_route_live() {
  local dir="${1:-}" ra nc
  [ -n "$(playbook_state_get "$dir" route_mode)" ] || return 1
  ra="$(playbook_state_int "$dir" route_at 0)"
  nc="$(playbook_state_int "$dir" ns_changed_at 0)"
  [ "$ra" -ge "$nc" ]
}

# @nonobvious(means) a route whose mode differs from the picked one is new single-option work, so its helpers carry no goal rather than the older one
playbook_ns_carried() {
  local dir="${1:-}"
  [ "$(playbook_ns_state "$dir")" = "confirmed" ] || { printf ''; return 0; }
  if playbook_route_live "$dir" && [ "$(playbook_state_get "$dir" route_mode)" != "$(playbook_state_get "$dir" ns_mode)" ]; then
    printf ''; return 0
  fi
  playbook_ns_goal "$dir"
}

playbook_mode() {
  local dir="${1:-}"
  if [ "$(playbook_ns_state "$dir")" = "confirmed" ] && ! playbook_route_live "$dir"; then
    playbook_state_get "$dir" ns_mode
  elif playbook_route_live "$dir"; then
    playbook_state_get "$dir" route_mode
  else
    playbook_state_get "$dir" ns_mode
  fi
}

playbook_review_scope() {
  local dir="${1:-}"
  if [ "$(playbook_ns_state "$dir")" = "confirmed" ]; then printf 'ns%s' "$(playbook_state_int "$dir" ns_id 0)"
  else printf 'session'; fi
}

# @nonobvious(means) briefs drift between rounds ("Review same-person PR 27", "Third review of PR 27 fixes"), so a PR or issue number is the review's identity, and ordinals never are
playbook_review_base() {
  local t n
  t="$(printf '%s' "${1:-}" | tr 'A-Z' 'a-z' | tr '\n\r\t' '   ' | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
  n="$(printf '%s' "$t" | sed -nE 's/.*(^|[^a-z])(pr|pull request|issue)[[:space:]]*#?[[:space:]]*([0-9]+).*/\3/p' | head -n1)"
  if [ -n "$n" ]; then printf 'review pr %s' "$n"; return 0; fi
  printf '%s' "$t" \
    | sed -E 's/[[:space:]]*\((round|r|pass)[[:space:]]*[0-9]+\)$//; s/[[:space:]]*(round|pass)[[:space:]]*[0-9]+$//; s/-r[0-9]+$//; s/-?round[0-9]+$//; s/-rereview-[0-9]+$//; s/-fixes$//; s/[[:space:]]+r[0-9]+$//; s/-[0-9]+$//' \
    | sed -E 's/^((first|second|third|fourth|fifth|sixth|final|another|one more|fresh|new)[[:space:]]+)+//; s/re-?review/review/g; s/[[:space:]]+(of|the|for|on)[[:space:]]+/ /g; s/[[:space:]]+(of|the|for|on)[[:space:]]+/ /g; s/^(of|the|for|on)[[:space:]]+//; s/[[:space:]]+fixes$//; s/[-[:space:]]+$//; s/[[:space:]]+/ /g' \
    | cut -c1-80
}

# @nonobvious(means) a builder that applies, fixes or addresses review findings names the review but is not a round of it
playbook_is_review() {
  local t="${1:-}"
  playbook_match review "$t" || return 1
  ! jq -en --arg t "$t" '$t | test("^\\s*((first|second|third|fourth|fifth|final|another|one more)\\s+)?(apply|fix|fixes|address|addresses|implement|resolve|action|land|push|patch|update|build|write|ship|respond)\\b"; "i")' >/dev/null 2>&1
}

# @nonobvious(means) a background review returns at once with only its ID, so the ID is how its report is recognised when it arrives later
playbook_review_note() { [ -n "${2:-}" ] && printf '%s\n' "$2" >> "${1}/review_ids" 2>/dev/null; return 0; }
playbook_review_known() { [ -n "${2:-}" ] && grep -qxF -- "$2" "${1}/review_ids" 2>/dev/null; }

# @nonobvious(means) one review's report arrives as a tool result, a hand-back turn, a task notice or a SubagentStop, often more than one of them, so it arms the pause once and shows it once
playbook_weigh_arm() {
  local dir="${1:-}" id="${2:-}"
  [ -n "$dir" ] && [ -n "$id" ] || return 1
  grep -qxF -- "$id" "${dir}/weigh_seen" 2>/dev/null && return 1
  printf '%s\n' "$id" >> "${dir}/weigh_seen" 2>/dev/null
  [ "$(playbook_state_get "$dir" weigh)" = bigger ] || playbook_state_put "$dir" "weigh=pending"
  return 0
}


playbook_weigh_hold_text() {
  case "$(playbook_state_get "${1:-}" weigh)" in
    pending) printf '%s' "$PLAYBOOK_WEIGH_TEXT" ;;
    bigger)
      printf '%s' "$PLAYBOOK_WEIGH_BIGGER"
      playbook_offline_on "$1" && printf ' %s' "The user is away, so a judge signs it off once the user's declared window has passed, without waiting when none was set; a change that goes against one of the user's decisions waits for them." ;;
  esac
}

playbook_weigh_signed() { [ "$(playbook_state_get "${1:-}" weigh)" = bigger ] && playbook_state_put "$1" "weigh="; return 0; }

# @nonobvious(means) Claude Code can put a reminder, a hand-back and a task notice in one prompt, so every report in it is found wherever it sits; prints one agent or task ID per review report
playbook_report_review_ids() {
  local dir="${1:-}" t="${2:-}" id blk sum st
  case "$t" in *'[Subagent hand-back]'*)
    while IFS= read -r id; do
      playbook_review_known "$dir" "$id" && printf '%s\n' "$id"
    done < <(printf '%s' "$t" | sed -nE 's/.*<agent-message from="([^"]+)">.*/\1/p') ;;
  esac
  case "$t" in *'<task-notification>'*)
    while IFS= read -r blk; do
      id="$(printf '%s' "$blk" | sed -nE 's#.*<task-id>([^<]+)</task-id>.*#\1#p')"
      st="$(printf '%s' "$blk" | sed -nE 's#.*<status>([^<]+)</status>.*#\1#p')"
      sum="$(printf '%s' "$blk" | sed -nE 's#.*<summary>(.*)</summary>.*#\1#p' | sed -E 's/^(Agent|Dynamic workflow|Workflow) "(.*)" [a-z]+$/\2/')"
      [ "$st" = completed ] && [ -n "$id" ] || continue
      if playbook_review_known "$dir" "$id" || playbook_is_review "$sum"; then printf '%s\n' "$id"; fi
    done < <(printf '%s' "$t" | awk '/<task-notification>/{b=""; on=1} on{b=b $0 " "} /<\/task-notification>/{if(on) print b; on=0}')
  ;; esac
  return 0
}

# @nonobvious(means) a hold armed by SubagentStop has shown no text yet, since that hook cannot speak to the main thread, so the next prompt or step that can speak shows the pause once
playbook_weigh_tell_any() {
  local dir="${1:-}" id untold=""
  [ "$(playbook_state_get "$dir" weigh)" = pending ] || return 1
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    grep -qxF -- "$id" "${dir}/weigh_told" 2>/dev/null || { untold=1; printf '%s\n' "$id" >> "${dir}/weigh_told"; }
  done < "${dir}/weigh_seen" 2>/dev/null
  [ -n "$untold" ]
}

playbook_review_rounds() {
  local dir="${1:-}" scope="${2:-}" base="${3:-}"
  [ -f "${dir}/reviews" ] || { printf '0'; return 0; }
  awk -F'\t' -v s="$scope" -v b="$base" '$1==s && $2==b{n=$3} END{print n+0}' "${dir}/reviews" 2>/dev/null
}

playbook_review_bump() {
  local dir="${1:-}" scope="${2:-}" base="${3:-}" n
  n=$(( $(playbook_review_rounds "$dir" "$scope" "$base") + 1 ))
  printf '%s\t%s\t%s\n' "$scope" "$base" "$n" >> "${dir}/reviews" 2>/dev/null || true
  printf '%s' "$n"
}

playbook_review_cleared() {
  local dir="${1:-}" scope="${2:-}" base="${3:-}" n="${4:-0}"
  [ -f "${dir}/review_cleared" ] || return 1
  awk -F'\t' -v s="$scope" -v b="$base" -v n="$n" '$1==s && $2==b && $3+0>=n+0{f=1} END{exit f?0:1}' "${dir}/review_cleared" 2>/dev/null
}

playbook_judge_returned() {
  local dir="${1:-}"
  [ -n "$dir" ] || return 0
  playbook_score_halve "$dir"
  playbook_gate_clear "$dir" judge
  playbook_gate_clear "$dir" ask
  playbook_weigh_signed "$dir"
  if [ -n "$(playbook_state_get "$dir" review_hold)" ]; then
    printf '%s\n' "$(playbook_state_get "$dir" review_hold)" >> "${dir}/review_cleared" 2>/dev/null || true
    playbook_state_put "$dir" "review_hold="
  fi
  playbook_state_put "$dir" "level=$(playbook_level_of "$(playbook_score10 "$dir")")"
}

playbook_rule_paths() {
  local proj="${1:-$PWD}" f
  for f in "${HOME}/.claude/CLAUDE.md" "${HOME}/.claude/rules/"*.md \
           "${proj}/CLAUDE.md" "${proj}/.claude/CLAUDE.md" "${proj}/CLAUDE.local.md"; do
    [ -f "$f" ] && printf '%s\n' "$f"
  done
}

# @nonobvious(must-hold) clears the conversation, not the process: a /clear keeps the session id, so everything the old conversation decided must go
playbook_conversation_reset() {
  local dir="${1:-}"
  [ -n "$dir" ] || return 0
  playbook_state_put "$dir" "score10=0" "level=0" "gate=" "concerned_at=" "ns_goal=" "ns_mode=" "ns_state=" \
    "ns_at=" "ns_source=" "ns_changed_at=" "ns_active=0" "route_mode=" "route_reason=" "route_at=" \
    "batches_np=0" "disp_np=0" "active_np=0" "fail_streak=0" "failed_since_pass=0" "last_failed_key=" \
    "away=0" "stopped=0" "last_human_ts=" "review_hold=" "calm_fired=0" "nudge200_fired=0" \
    "wf_optin=" "wf_optin_fails=0" "wf_optin_fail_turn=" "uc_reminded="
  rm -f "${dir}/decisions.jsonl" "${dir}/decisions.txt" "${dir}/prompts.jsonl" "${dir}/ns_words.jsonl" \
        "${dir}/human.jsonl" "${dir}/seen_human" "${dir}/reviews" "${dir}/review_cleared" "${dir}/edits" \
        "${dir}/contrib" "${dir}/events.jsonl" 2>/dev/null || true
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
  dir="$(playbook_global_dir)"
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

# @nonobvious(mirrors) Playbook 2.8 saved this answer inside the project; such a file is still read, but the answer is now only ever written machine-wide
playbook_context_calm_resolved() {
  local proj="${1:-$PWD}" v
  v="$(playbook_global_file context-calm)"
  [ -n "$v" ] && { printf '%s' "$v"; return 0; }
  playbook_claude_file "$proj" "context-calm"
}

playbook_latest_transcript() {
  local proj="${1:-$PWD}" enc dir latest
  enc="$(printf '%s' "$proj" | tr '/' '-')"
  dir="${HOME}/.claude/projects/${enc}"
  [ -d "$dir" ] || { printf ''; return 0; }
  latest="$(ls -1t "$dir"/*.jsonl 2>/dev/null | awk 'NR==1')"
  [ -n "$latest" ] && [ -f "$latest" ] && printf '%s' "$latest" || printf ''
}

# @nonobvious(must-hold) only system bridge_status records match, so a pasted URL in a user message cannot poison the link
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

# @nonobvious(forced-by) Cursor, Claude Code and Copilot each read a different envelope field
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
