#!/usr/bin/env bash
# Classify one captured stream-json transcript into a routing-shape row.
# Emits TAB-separated: canary  marker  agree  behaviour  cost  subtype  map  source  shortlist  refused
#   canary    yes|no        overlay actually injected (run is void if no)
#   marker    <mode>|none|censored|malformed   the routing decision, read from the first of:
#             1. the attempted picker: an AskUserQuestion whose question starts "Goal:" (the
#                harness denies the call, but the attempted input is in the stream); the mode
#                is its "(Recommended)" option
#             2. a Bash channel line `playbook route <mode> ...` (the single-option route line)
#             3. a route line printed in ASSISTANT text instead of run, which the Stop hook records
#             4. the first branded route marker line in ASSISTANT text (fallback)
#             censored = the run hit the turn cap with no dispatch before announcing,
#             so it never reached its routing decision (not a solo choice)
#   agree     yes|no|na     does the marker's emoji match its chip (na for picker and route command)
#   behaviour first real dispatch the model reached for, or solo
#   cost      USD for the run
#   subtype   result subtype (success | error_max_turns | ...)
#   map       exact|loose|wrong|na - does the announced mode match the ACTUAL tool
#             signature, mode-exactly? lone-wolf demands zero dispatch; interns
#             demands Agent/Task with no peer messaging; hackathon demands the
#             hackathon-team skill or peer messaging (plain Agent alone is only
#             "loose", since teammates and subagents share the Agent tool);
#             workflows demands a Workflow attempt; gsd demands the gsd-mode skill.
#             na = no scoreable marker (none/censored/malformed), or a picker decision with
#             no dispatch after it (the run stopped at the question, so there is no shape
#             to compare).
#   source    picker|route|printed|marker|none   which reading produced the marker
#   shortlist comma-separated modes offered (picker), the single mode (route), or - when
#             there is no picker or route line
#   refused   route lines the hooks refused without recording them (a mode name that isn't
#             one); the decision is the first route line they recorded, which includes a line
#             refused only for a chained command, since the hook records it before refusing
set -euo pipefail
f="${1:?usage: classify.sh <stream.jsonl>}"

canary=no; grep -q 'PLAYBOOK_OVERLAY' "$f" 2>/dev/null && canary=yes

# Only the model's own assistant text can carry a genuine route marker; the
# injected overlay (which contains an example marker) rides system/user events.
atext="$(jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text' "$f" 2>/dev/null || true)"

# Only route markers count; Playbook also prints non-route markers (🧰 setup,
# 🌡️ unease, 🪙 model) that must not be mistaken for the routing decision.
first_marker="$(printf '%s\n' "$atext" | grep -F '**Playbook**' | grep -E 'lone-wolf|interns|hackathon|workflows|gsd' | head -1 || true)"

# The first routing decision the model attempted through a tool, in stream order: the picker
# (AskUserQuestion with a question starting "Goal:") or the route no-op (a Bash command that
# starts "playbook route <mode>", with or without the older leading ": "). Output: source TAB recommended-mode TAB shortlist.
decision="$(jq -rs '
  def canon: ascii_downcase | gsub("\\(recommended\\)"; "") | gsub("[^a-z -]"; " ")
             | gsub("lone[ _]wolf"; "lone-wolf") | gsub("workflow\\b"; "workflows")
             | ([scan("lone-wolf|interns|hackathon|workflows|gsd")] | first) // "";
  [ .[] | select(.type=="user") | .message.content[]? | select(.type=="tool_result" and .is_error==true) | select((.content | tostring) | test("recorded this channel line") | not) | .tool_use_id ] as $refused
  | [ .[] | select(.type=="assistant") | .message.content[]? | select(.type=="tool_use") ]
  | map(
      if .name=="AskUserQuestion" then
        ( [ (.input.questions // [])[] | select((.question // "") | test("^\\s*Goal:")) ] | first ) as $q
        | if $q == null then empty else
            ( [ ($q.options // [])[] | {m: ((.label // "") | canon), r: ((.label // "") | test("\\(recommended\\)"; "i"))} ] ) as $o
            | {src: "picker",
               mode: (([ $o[] | select(.r) | .m ] | first) // ""),
               list: ([ $o[] | .m | select(. != "") ] | unique | join(","))}
          end
      elif .name=="Bash" and ((.input.command // "") | test("^\\s*(:\\s+)?playbook\\s+route\\s")) and ((.id as $i | $refused | index($i)) | not) then
        ((.input.command | capture("^\\s*(:\\s+)?playbook\\s+route\\s+(?<w>\\S+)").w | canon)) as $m
        | {src: "route", mode: $m, list: $m}
      else empty end)
  | first // empty
  | [.src, .mode, .list] | @tsv' "$f" 2>/dev/null || true)"

printed="$(printf '%s\n' "$atext" | sed -nE 's/^[[:space:]`]*(:[[:space:]]+)?playbook[[:space:]]+route[[:space:]]+([A-Za-z_-]+).*/\2/p' | tr 'A-Z' 'a-z' | sed -E 's/^lone[_]?wolf$/lone-wolf/' | grep -xE 'lone-wolf|interns|hackathon|workflows|gsd' | head -n1 || true)"
[ -z "$decision" ] && [ -n "$printed" ] && decision="$(printf 'printed\t%s\t%s' "$printed" "$printed")"

source=none; shortlist=-
if [ -n "$decision" ]; then
  source="$(cut -f1 <<<"$decision")"; chip="$(cut -f2 <<<"$decision")"; shortlist="$(cut -f3 <<<"$decision")"
  [ -n "$shortlist" ] || shortlist=-
  agree=na
  if [ -n "$chip" ]; then marker="$chip"; else marker=malformed; agree=no; fi
elif [ -z "$first_marker" ]; then
  marker=none; agree=na
else
  source=marker
  chip="$(printf '%s' "$first_marker" | grep -oE '(lone-wolf|interns|hackathon|workflows|gsd)' | head -1 || true)"
  if [ -z "$chip" ]; then
    marker=malformed; agree=no
  else
    marker="$chip"
    case "$chip" in
      lone-wolf) em='🐺';; interns) em='🐜';; hackathon) em='🤝';; workflows) em='⚙️';; gsd) em='🏗️';;
    esac
    if printf '%s' "$first_marker" | grep -qF "$em"; then agree=yes; else agree=no; fi
  fi
fi

# First dispatch-shaped action the model actually attempted (the deny-hook blocks
# it, but the attempt is still recorded), so a marker that lies about what the
# model then does is caught.
actions="$(jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use")
  | if .name=="Skill" then "Skill:"+((.input.skill)//"?") else .name end' "$f" 2>/dev/null || true)"
behaviour=solo
while IFS= read -r a; do
  case "$a" in
    Workflow)               behaviour=workflow;      break;;
    Agent)                  behaviour=agent;         break;;
    Task)                   behaviour=agent;         break;;
    TeamCreate)             behaviour=team;          break;;
    SendMessage)            behaviour=sendmessage;   break;;
    Skill:*gsd-mode*)       behaviour=skill:gsd;     break;;
    Skill:*hackathon-team*) behaviour=skill:hackathon; break;;
  esac
done <<< "$actions"

refused="$(jq -rs '
  [ .[] | select(.type=="user") | .message.content[]? | select(.type=="tool_result" and .is_error==true) | select((.content | tostring) | test("recorded this channel line") | not) | .tool_use_id ] as $bad
  | [ .[] | select(.type=="assistant") | .message.content[]? | select(.type=="tool_use" and .name=="Bash")
      | select((.input.command // "") | test("^\\s*(:\\s+)?playbook\\s+route\\s")) | select(.id as $i | $bad | index($i)) ] | length' "$f" 2>/dev/null || echo 0)"
[ -n "$refused" ] || refused=0

cost="$(jq -r 'select(.type=="result") | .total_cost_usd // 0' "$f" 2>/dev/null | head -1)"
subtype="$(jq -r 'select(.type=="result") | .subtype // "?"' "$f" 2>/dev/null | head -1)"
[ -n "$cost" ] || cost=0
[ -n "$subtype" ] || subtype='?'

# A capped run that never announced and never dispatched was cut off before its
# routing decision; calling that "none" would misread censoring as a solo choice.
if [ "$marker" = "none" ] && [ "$behaviour" = "solo" ] && [ "$subtype" = "error_max_turns" ]; then
  marker=censored
fi

# Mode-exact mapping between the announced route and the full set of dispatch
# attempts, so a marker cannot claim one staffing shape while the tools tell
# another (e.g. "interns" announced but peers messaged, or "hackathon" announced
# on plain subagents).
has() { printf '%s\n' "$actions" | grep -q "$1"; }
map=na
case "$marker" in
  lone-wolf)
    if [ "$behaviour" = "solo" ]; then map=exact; else map=wrong; fi;;
  interns)
    if has '^Agent$' || has '^Task$'; then
      if has '^SendMessage$'; then map=wrong; else map=exact; fi
    else map=wrong; fi;;
  hackathon)
    if has 'hackathon-team' || has '^SendMessage$'; then map=exact
    elif has '^Agent$' || has '^Task$'; then map=loose
    else map=wrong; fi;;
  workflows)
    if has '^Workflow$'; then map=exact; else map=wrong; fi;;
  gsd)
    if has 'gsd-mode'; then map=exact; else map=wrong; fi;;
esac

if [ "$source" = picker ] && [ "$behaviour" = solo ] && [ "$marker" != lone-wolf ]; then map=na; fi

printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$canary" "$marker" "$agree" "$behaviour" "$cost" "$subtype" "$map" "$source" "$shortlist" "$refused"
