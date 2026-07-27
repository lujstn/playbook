#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
S="$root/skills/playbook/SKILL.md"
fail=0
chk() { if eval "$1" >/dev/null 2>&1; then echo "PASS: $2"; else echo "FAIL: $2"; fail=1; fi; }
chk "! grep -q '\.playbook/' '$S'" "no .playbook/ paths"
chk "! grep -q 'playbook_anchor_init\\|playbook_ledger_append\\|playbook_anchor_read' '$S'" "no removed helpers"
chk "! grep -q 'anchor-format' '$S'" "no anchor-format.md cross-references"
chk "! grep -qi 'uncertaint' '$S'" "no uncertainty word anywhere (concept, hook name, ledger)"
chk "! grep -qiE 'append-only( unease)? ledger|unease ledger|the ledger|band-slug|callout shape' '$S'" "ledger mechanism gone"
chk "! grep -qiE 'the anchor file|pinned anchor file|re-?reads? the anchor|into the anchor' '$S'" "no anchor-file references"
chk "! grep -qE '(^|[^-])design\\.md' '$S'" "no bare lowercase design.md vestige"
chk "! grep -q 'DESIGN\\.md' '$S'" "no stale DESIGN.md reference (docs split)"
chk "grep -q 'regardless of the mode or the unease level' '$S'" "standing override no-ledger phrasing"
chk "! grep -q 'playbook-window' '$S'" "no agent-declared window instruction (the window is inferred now)"
chk "grep -q 'playbook-northstar' '$S'" "engine instructs the project North Star dispatch line"

chk "! grep -qi 'receives only the prompt you author\\|receives only its own prompt' '$S'" "engine skill drops the false no-overlay workflow claim"
chk "grep -q 'SubagentStart overlay' '$S'" "engine skill states the SubagentStart overlay reaches workflow subagents"
chk "grep -q 'SubagentStart overlay' '$root/commands/workflow.md'" "workflow command states the SubagentStart overlay reaches workflow subagents"

chk "grep -qi 'match the tool to the task, never to the mode' '$S'" "engine carries ultracode restraint guidance"
chk "grep -q 'is interns at most' '$S'" "engine rebuts fan-out-for-small-task with the bounded-set tie-break"
chk "grep -qi 'degenerate result' '$S'" "engine warns against trusting a degenerate workflow result"

chk "grep -q 'not colleagues' '$S'" "engine states the subagent price list"
chk "grep -q 'live routing inputs' '$S'" "engine names speed and context preservation as routing inputs"
chk "grep -q 'unless that bulk exceeds' '$S'" "engine tie-break carries the exceeds-one-context escape valve"
chk "grep -q 'crew of experts' '$S'" "engine carries the expert-crew hackathon definition"
chk "grep -q 'interns logic' '$S'" "engine rebuts the interns-logic category error against hackathon"
chk "grep -q 'spine density' '$S'" "engine carries the spine-density tie-break against lone-wolf"
chk "grep -q 'fresh, complete marker line' '$S'" "engine forbids hybrid two-mode marker lines"
chk "grep -q 'will the plan survive contact unchanged' '$S'" "engine carries the frozen-plan tie-break against workflows"
chk "grep -q 'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS' '$S'" "engine detects team availability mechanically, not by guessing"

chk "grep -q 'Assume ultracode is the baseline' '$S'" "engine states the ultracode baseline verbatim from the overlay"
chk "grep -q 'Never restate a changed goal silently' '$S'" "engine requires user confirmation before restating the North Star"
chk "grep -q 'none (task-only)' '$S'" "engine documents the task-only dispatch opt-out"
chk "grep -q 'Route by shape' '$S'" "engine carries the route-by-shape procedure verbatim from the overlay"
chk "grep -q 'Four tie-breaks' '$S'" "engine corrects the tie-break count to four"
chk "! grep -q 'Three tie-breaks' '$S'" "engine no longer carries the miscounted three-tie-break phrasing"
chk "grep -q 'counted in units, never in writers' '$S'" "engine counts scale in units so batching cannot launder the count"
chk "grep -q 'dozens or more frozen units' '$S'" "engine carries the interns-or-workflows scale tie-break"
chk "grep -qi 'solo bias' '$S'" "engine names the solo bias as a failure alongside the workflow bias"

chk "grep -q 'The nine tenets, always live:' '$S'" "engine carries the nine-tenet header"
n_s=$(awk '/The nine tenets, always live:/{t=1; next} t&&/^[1-9]\. /{n++} t&&/^$/{exit} END{print n+0}' "$S" 2>/dev/null)
[ "$n_s" -eq 9 ] \
  && echo "PASS: nine tenets in engine skill" \
  || { echo "FAIL: found $n_s tenets in the engine skill tenets block, expected 9"; fail=1; }

chk "grep -q '🧭' '$S'" "engine marker table registers brainstorming"
chk "grep -q '🌿' '$S'" "engine marker table registers worktrees"
chk "grep -q '🧰' '$S'" "engine marker table registers setup"
chk "grep -q '🌡️' '$S'" "engine marker table registers the unease thermometer"

O="$root/skills/offline-mode/SKILL.md"
chk "! grep -qi 'uncertaint' '$O'" "offline-mode has no uncertainty word anywhere"
chk "! grep -qiE 'uncertainty ledger|the ledger' '$O'" "offline-mode has no ledger reference"
chk "! grep -qE '(^|[^-])design\\.md' '$O'" "offline-mode no bare lowercase design.md vestige"
chk "! grep -q 'DESIGN\\.md' '$O'" "offline-mode no stale DESIGN.md reference"
chk "grep -q 'regardless of the unease level or the mode' '$O'" "offline-mode standing override no-ledger phrasing"
chk "grep -qi 'gated by your in-session unease\\|gated by the in-session unease' '$O'" "external manager gated by in-session unease"
chk "grep -q '^# Offline Mode' '$O'" "offline-mode H1 has no embedded marker"
chk "grep -qF '📴 **Playbook**' '$O'" "offline-mode announce uses the branded bold marker"

NS="$root/skills/offline-mode/notify-setup.md"
chk "grep -qi 'iphone or android' '$NS'" "notify guide asks iPhone or Android first"
chk "grep -qi 'ntfy' '$NS' && grep -qi 'pushover' '$NS'" "notify guide covers both providers"
chk "grep -q 'qrencode' '$NS'" "notify guide offers the Android QR subscribe"
chk "grep -qiE 'live test|test ping|send one real notification' '$NS'" "notify guide ends with a live test ping"
chk "grep -q 'head -c 32' '$NS'" "notify guide generates a 32-char random topic"
chk "grep -q 'ntfy-topic' '$NS' && grep -q 'notify-provider' '$NS'" "notify guide writes the global config keys"
chk "grep -q '~/.claude/playbook/' '$NS'" "notify guide configures globally by default"
chk "grep -q 'notify-setup.md' '$root/skills/setup/SKILL.md'" "setup skill hands into the guided notification walkthrough"
chk "grep -q 'notify-setup.md' '$O'" "offline-mode hands into the guided notification walkthrough"
chk "grep -q 'not now' '$root/skills/setup/SKILL.md' && grep -q 'never' '$root/skills/setup/SKILL.md'" "setup notification offer is yes / not now / never"

H="$root/skills/hackathon-team/SKILL.md"
chk "! grep -qE '(^|[^-])design\\.md' '$H'" "hackathon-team no bare lowercase design.md vestige"
chk "! grep -q 'DESIGN\\.md' '$H'" "hackathon-team no stale DESIGN.md reference"

targets=( "$root"/skills/playbook/SKILL.md \
          "$root"/skills/offline-mode/SKILL.md \
          "$root"/skills/hackathon-team/SKILL.md \
          "$root"/skills/model-rule/SKILL.md \
          "$root"/skills/brainstorming/SKILL.md \
          "$root"/skills/gsd-mode/SKILL.md \
          "$root"/skills/worktrees/SKILL.md \
          "$root"/skills/fix-mode/SKILL.md \
          "$root"/skills/debug-mode/SKILL.md \
          "$root"/skills/setup/SKILL.md \
          "$root"/skills/offline-mode/notify-setup.md \
          "$root"/skills/offline-mode/decision-log.html.tmpl \
          "$root"/commands/workflow.md \
          "$root"/commands/hello.md )
for f in "${targets[@]}"; do
  rel="${f#"$root"/}"
  chk "[ -f '$f' ]" "$rel: target file present"
  chk "! grep -qi 'uncertaint' '$f'" "$rel: no uncertainty vocabulary"
  chk "! grep -qiE 'CTO-subagent|CTO consultation' '$f'" "$rel: no CTO vocabulary (external manager is canonical)"
  chk "! grep -qi 'ntfy sends' '$f'" "$rel: provider-agnostic notification wording"
  chk "! grep -qiw 'ledger' '$f'" "$rel: no ledger vocabulary (log is canonical)"
  chk "! grep -qiE 'synchronised-(development|subagent)' '$f'" "$rel: no dropped synchronised-development skill name"
  chk "! grep -qE 'TeamCreate|TeamDelete|team_name' '$f'" "$rel: no removed agent-teams setup API (teams auto-form since CLI 2.1.178)"
  chk "{ ! grep -q 'front door' '$f'; } || grep -q 'not a front door' '$f'" "$rel: no rejected front-door framing"
  chk "! grep -q '—' '$f'" "$rel: no em-dash (house style)"
  chk "! grep -qi 'judgment' '$f'" "$rel: British spelling Judgement"
  chk "! grep -qiw 'toward' '$f'" "$rel: British spelling towards"
  chk "! grep -qiw 'gray' '$f'" "$rel: British spelling grey"
  chk "! grep -qi 'artifact' '$f'" "$rel: British spelling artefact"
  chk "! grep -qE '543N|300M' '$f'" "$rel: no malformed instance-offset placeholders"
done

SS="$root/hooks/session-start"
chk "grep -q 'load the playbook skill' '$SS'" "overlay sends the agent into the engine skill for the modes, tie-breaks and tenets"
chk "grep -q 'A Playbook card arrives with every user prompt' '$SS'" "overlay tells the agent the per-prompt card is live state"
chk "grep -q 'faintly_uneasy' '$SS'" "overlay carries the unease register in full"
chk "grep -q 'Set an explicit model on anything you dispatch' '$SS'" "overlay puts an explicit model on every dispatched helper"

TR="$root/skills/time-rule/SKILL.md"
chk "test -f '$TR'" "time-rule reference skill exists"
chk "grep -q 'user-invocable: false' '$TR'" "time-rule skill is not user-invocable"
chk "grep -q 'divide by ten' '$TR'" "time-rule skill states the correction"
chk "grep -q 'Time rule, always on' '$TR'" "time-rule skill carries the overlay doctrine header verbatim"
chk "grep -q 'items times rate' '$TR'" "time-rule skill exempts external-system waits verbatim"
chk "grep -q 'already observed' '$TR'" "time-rule skill exempts already-observed durations verbatim"
chk "grep -q '12m52s' '$TR'" "time-rule skill carries the founding measurement"
chk "grep -q 'playbook:time-rule' '$root/skills/playbook/SKILL.md'" "engine registry lists the time rule"
chk "! grep -q 'playbook-window' '$SS'" "overlay no longer instructs a window declaration"
chk "grep -q 'ultracode nudge' '$SS'" "overlay nudges the user onto /effort ultracode at session start"
chk "grep -qF 'Playbook runs best on ultracode' '$SS'" "overlay carries the exact ultracode nudge wording"
nudge_ln=$(grep -n 'ultracode nudge' "$SS" | head -1 | cut -d: -f1)
live_ln=$(grep -n 'Playbook liveness' "$SS" | head -1 | cut -d: -f1)
{ [ -n "$nudge_ln" ] && [ -n "$live_ln" ] && [ "$nudge_ln" -lt "$live_ln" ]; } \
  && echo "PASS: the ultracode nudge precedes the liveness line" \
  || { echo "FAIL: the ultracode nudge is not positioned above the liveness line"; fail=1; }

SU="$root/skills/setup/SKILL.md"
chk "grep -qF '🧰 **Playbook**' '$SU'" "setup skill announces with the branded bold marker"
chk "grep -qi 'never uninstall' '$SU'" "setup skill never uninstalls"
chk "grep -qiE 'back(ed)? up|backup' '$SU'" "setup skill requires a settings backup"
chk "grep -qi 'never execute another plugin' '$SU'" "setup skill reads other plugins, never runs them"
chk "grep -qF '**Want a broader health check' '$SU'" "setup skill offers the wider health check in bold after the audit"

chk "grep -qi 'introduce yourself and ask first' '$SU'" "setup skill introduces and asks before auditing"
chk "grep -qiE 'strictly read-only|read-only look' '$SU'" "setup skill promises a read-only first look"
chk "grep -qF '**not now**' '$SU'" "setup skill offers a 'not now' decline"
chk "grep -qF '**never**' '$SU'" "setup skill offers a 'never' decline"
intro_ln=$(grep -n 'introduce yourself and ask first' "$SU" | head -1 | cut -d: -f1)
gather_ln=$(grep -n 'gather the facts' "$SU" | head -1 | cut -d: -f1)
{ [ -n "$intro_ln" ] && [ -n "$gather_ln" ] && [ "$intro_ln" -lt "$gather_ln" ]; } \
  && echo "PASS: the setup consent gate precedes the audit" \
  || { echo "FAIL: the setup audit is not gated behind the intro"; fail=1; }

chk "grep -q 'playbook:setup' '$root/commands/hello.md'" "hello command gates through the setup skill"
chk "[ ! -f '$root/commands/pb.md' ] && [ ! -f '$root/commands/playbook.md' ]" "the pb/playbook twins are gone; hello is the single entry point"

for internal in playbook model-rule gsd-mode hackathon-team; do
  chk "grep -q 'user-invocable: false' '$root/skills/$internal/SKILL.md'" "skills/$internal is hidden from the / menu (model-invocable only)"
done

chk "[ ! -f '$root/hooks/unease' ]" "the Stop-pulse hook (hooks/unease) is deleted"

chk "grep -qi 'degenerate result' '$root/commands/workflow.md'" "workflow command warns against a degenerate result"
chk "[ -z \"\$(ls '$root'/commands/pb-*.md 2>/dev/null)\" ]" "no pb-* command files remain"
chk "! grep -rq 'Playbook ·' '$root/hooks' '$root/skills' '$root/commands' '$root/README.md'" "no middot marker leftovers in the shipped surface"

R="$root/README.md"
chk "! grep -qE '\.playbook/[A-Za-z._-]' '$R'" "README has no .playbook/ path references"
chk "! grep -qi 'uncertaint' '$R'" "README uses unease naming, no uncertainty word"
chk "! grep -qiw 'ledger' '$R'" "README uses log naming, no ledger vocabulary"
chk "grep -qi 'writes nothing into your project' '$R'" "README states no file is written into the tree"
chk "grep -qi 'baseline is ultracode' '$R'" "README states the ultracode baseline"
chk "grep -q 'crew of different experts' '$R'" "README chooser carries the expert-crew hackathon line"
chk "grep -q 'will the plan survive contact unchanged' '$R'" "README carries the frozen-plan tie-break"
chk "grep -qi 'solo bias' '$R' && grep -qi 'workflow bias' '$R'" "README names both routing biases"
chk "grep -q 'spine density' '$R'" "README carries the spine-density tie-break"
chk "! grep -q '\.playbook/' '$root/.gitignore'" ".gitignore has no .playbook vestige"
GA="$root/.gitattributes"
chk "! grep -qi 'uncertaint' '$GA'" ".gitattributes has no old uncertainty hook name"
chk "! grep -q 'hooks/unease' '$GA'" ".gitattributes no longer pins the deleted unease hook"
exit $fail
