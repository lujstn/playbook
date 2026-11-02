#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
SS="$root/hooks/session-start"
TB="$root/hooks/take-a-beat"
SG="$root/hooks/signal"
HJ="$root/hooks/hooks.json"
SN="$root/scripts/notify"
SK="$root/skills"
fail=0
chk() { if eval "$1" >/dev/null 2>&1; then echo "PASS: $2"; else echo "FAIL: $2"; fail=1; fi; }

n=$(awk '/The nine tenets, always live:/{t=1; next} t&&/^[1-9]\. /{n++} t&&/^$/{exit} END{print n+0}' "$SK/playbook/SKILL.md" 2>/dev/null)
[ "$n" -eq 9 ] \
  && echo "PASS: nine tenets in the engine skill" \
  || { echo "FAIL: found $n tenets in the tenets block, expected 9"; fail=1; }

chk "grep -qF 'Sonnet builds and checks, Opus plans and judges' '$SS'" "model rule: Sonnet builds and checks, Opus plans and judges (helper block)"
chk "grep -qF 'Sonnet builds and checks, Opus plans and judges' '$SK/model-rule/SKILL.md' || grep -q 'Sonnet builds and checks' '$SK/model-rule/SKILL.md'" "model rule: carried by the model-rule skill"

chk "grep -qi 'auto-compact is seamless' '$TB'" "context-calm: auto-compact is seamless"
chk "! grep -qi 'never wrap up early' '$TB' '$SS'" "context-calm: no never-wrap-up-early rule"
chk "grep -q 'Keep working at the same completeness bar' '$TB'" "context-calm: keep working at the same bar"

chk "grep -qF '**Playbook**' '$SG'" "brand convention: the route line the hook shows is bold Playbook"
chk "grep -qF '**Playbook**' '$SK/playbook/SKILL.md'" "brand convention: bold Playbook in the engine skill's route line"

chk "grep -q 'must match the confirmed goal, or the dispatch guard refuses it' '$SK/playbook/SKILL.md'" "a named North Star in a brief must match the confirmed one"

chk "jq -e '.hooks.SubagentStart' '$HJ'" "SubagentStart wired in hooks.json (overlay and helper block carrier)"
chk "jq -e '.hooks.PostToolUse[0].matcher | test(\"AskUserQuestion\")' '$HJ'" "PostToolUse reaches AskUserQuestion (the picker's answer)"
chk "jq -e '.hooks.TeammateIdle' '$HJ'" "TeammateIdle wired (hackathon A and B)"

chk "grep -q 'Playbook is active; its hooks carry it across compaction' '$SS'" "overlay states the hooks are the carrier"
chk "grep -qi 'writes nothing into your project' '$root/README.md'" "README states the no-file model"

chk "grep -qF 'f a choice could leave the work short of the goal, or go against one of the user' '$SK/playbook/SKILL.md'" "standing override present in the engine skill"
chk "! grep -rq 'regardless of the unease level or the mode\|regardless of the mode or the unease level' '$SK'" "old standing override wording gone from every skill"

chk "grep -qi 'pushover' '$SN'" "Pushover provider in scripts/notify"
chk "grep -qi 'pushover' '$SK/offline-mode/SKILL.md'" "Pushover referenced in offline-mode skill"

chk "grep -qi 'ntfy' '$SN'" "ntfy provider in scripts/notify"
chk "grep -qi 'ntfy' '$SK/offline-mode/SKILL.md'" "ntfy referenced in offline-mode skill"

chk "grep -q 'playbook_competing_context_hook' '$TB'" "competing-hook offer in take-a-beat"
chk "grep -q 'context-calm' '$TB'" "context-calm channel referenced in take-a-beat"

chk "! grep -rqE '\\.playbook/[A-Za-z._-]' '$SS' '$SK'" "no .playbook/ path reference in overlay or skills"
chk "! grep -rq 'DESIGN\\.md' '$SS' '$SK' '$HJ'" "no stale DESIGN.md reference in shipped surface"

chk "[ ! -e '$SK/time-rule' ]" "the time-rule skill is deleted"
chk "! grep -rqi 'time-rule\\|divide by ten' '$SS' '$TB' '$SG' '$HJ' '$SK' '$root/commands' '$root/README.md'" "no time-rule reference anywhere in the shipped surface"
chk "! grep -rqi 'runs best on ultracode\\|ultracode nudge' '$SS' '$TB' '$SK' '$root/README.md'" "no ultracode nudge anywhere in the shipped surface"

echo "--- the statusline contract between the setup skill and the script"
SU="$SK/setup/SKILL.md"
chk "grep -qF '~/.local/state/playbook/bin/statusline' '$SU'" "setup installs to ~/.local/state/playbook/bin/statusline"
chk "grep -qF '~/.local/state/playbook/statusline-wrapped' '$SU'" "setup saves the previous command to statusline-wrapped"
chk "grep -qE 'Write \`owned\` to \`~/.local/state/playbook/statusline\`' '$SU'" "setup writes owned to the marker"
chk "grep -qF '\`refreshInterval\` \`5\`' '$SU'" "setup sets a refresh interval so the crew segment stays current while the lead waits"
chk "grep -q 'crew_msgs' '$root/scripts/statusline'" "scripts/statusline shows the crew's messages"
if [ -f "$root/scripts/statusline" ]; then
  chk "[ -x '$root/scripts/statusline' ]" "scripts/statusline is executable"
  chk "grep -q 'statusline-wrapped' '$root/scripts/statusline'" "scripts/statusline reads the wrapped command the setup skill saves"
  chk "grep -q '🟨 uneasy' '$root/scripts/statusline' && grep -q '🟥 alarmed' '$root/scripts/statusline'" "scripts/statusline shows the unease level"
else
  echo "FAIL: scripts/statusline is missing"; fail=1
fi

echo "--- the channel the skills teach is the channel the signal hook parses"
for verb in route goal unease decision rethink done interface part-done waiting; do
  chk "grep -q '$verb' '$SG'" "signal hook handles 'playbook $verb'"
done
for verb in $(grep -rhoE 'playbook [a-z-]+' "$SK" "$root/commands" "$root/README.md" | awk '{print $3}' | sort -u); do
  chk "grep -q '$verb' '$SG'" "every skill-taught verb is parsed: $verb"
done

exit $fail
