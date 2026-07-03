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
chk "grep -q 'playbook-window' '$S'" "agent-declared window instruction present"
chk "grep -q 'playbook-northstar' '$S'" "engine instructs the project North Star dispatch line"

# Ultracode-baseline restraint: the engine must reason about what the task needs
# rather than reaching for a workflow because the mode is on. This guards against
# regressing to the "ultracode is on, so this is the right scale" failure mode.
chk "grep -qi 'match the tool to the task, never to the mode' '$S'" "engine carries ultracode restraint guidance"
chk "grep -q 'is interns at most' '$S'" "engine rebuts fan-out-for-small-task with the bounded-set tie-break"
chk "grep -qi 'degenerate result' '$S'" "engine warns against trusting a degenerate workflow result"

O="$root/skills/offline-mode/SKILL.md"
chk "! grep -qi 'uncertaint' '$O'" "offline-mode has no uncertainty word anywhere"
chk "! grep -qiE 'uncertainty ledger|the ledger' '$O'" "offline-mode has no ledger reference"
chk "! grep -qE '(^|[^-])design\\.md' '$O'" "offline-mode no bare lowercase design.md vestige"
chk "! grep -q 'DESIGN\\.md' '$O'" "offline-mode no stale DESIGN.md reference"
chk "grep -q 'regardless of the unease level or the mode' '$O'" "offline-mode standing override no-ledger phrasing"
chk "grep -qi 'gated by your in-session unease\\|gated by the in-session unease' '$O'" "external manager gated by in-session unease"
chk "grep -q '^# Offline Mode' '$O'" "offline-mode H1 has no embedded marker"
chk "grep -q 'Playbook · offline:' '$O'" "offline-mode announce uses the canonical colon separator"
chk "! grep -q 'Playbook · offline -' '$O'" "offline-mode announce has no hyphen-separator drift"

H="$root/skills/hackathon-team/SKILL.md"
chk "! grep -qE '(^|[^-])design\\.md' '$H'" "hackathon-team no bare lowercase design.md vestige"
chk "! grep -q 'DESIGN\\.md' '$H'" "hackathon-team no stale DESIGN.md reference"

# Shared stale-term and house-style blocklist across every skill plus the offline
# decision-log template. The original test guarded only three skills; the drift
# both baseline-test sessions found lived in the unguarded six, so sweep them all.
targets=( "$root"/skills/playbook/SKILL.md \
          "$root"/skills/offline-mode/SKILL.md \
          "$root"/skills/hackathon-team/SKILL.md \
          "$root"/skills/model-rule/SKILL.md \
          "$root"/skills/brainstorming/SKILL.md \
          "$root"/skills/gsd-mode/SKILL.md \
          "$root"/skills/worktrees/SKILL.md \
          "$root"/skills/fix-mode/SKILL.md \
          "$root"/skills/debug-mode/SKILL.md \
          "$root"/skills/offline-mode/decision-log.html.tmpl \
          "$root"/commands/workflow.md \
          "$root"/commands/pb-workflow.md )
for f in "${targets[@]}"; do
  rel="${f#"$root"/}"
  # A missing target would make every negative grep below pass vacuously (grep on
  # a nonexistent path exits non-zero, which the leading ! flips to success), so
  # assert presence first to fail loudly on a rename or deletion.
  chk "[ -f '$f' ]" "$rel: target file present"
  chk "! grep -qi 'uncertaint' '$f'" "$rel: no uncertainty vocabulary"
  chk "! grep -qiE 'CTO-subagent|CTO consultation' '$f'" "$rel: no CTO vocabulary (external manager is canonical)"
  chk "! grep -qi 'ntfy sends' '$f'" "$rel: provider-agnostic notification wording"
  chk "! grep -qiw 'ledger' '$f'" "$rel: no ledger vocabulary (log is canonical)"
  chk "! grep -qiE 'synchronised-(development|subagent)' '$f'" "$rel: no dropped synchronised-development skill name"
  chk "{ ! grep -q 'front door' '$f'; } || grep -q 'not a front door' '$f'" "$rel: no rejected front-door framing"
  chk "! grep -q '—' '$f'" "$rel: no em-dash (house style)"
  chk "! grep -qi 'judgment' '$f'" "$rel: British spelling Judgement"
  chk "! grep -qiw 'toward' '$f'" "$rel: British spelling towards"
  chk "! grep -qiw 'gray' '$f'" "$rel: British spelling grey"
  chk "! grep -qi 'artifact' '$f'" "$rel: British spelling artefact"
  chk "! grep -qE '543N|300M' '$f'" "$rel: no malformed instance-offset placeholders"
done

# The session-start overlay is the always-on doctrine; assert it carries the
# ultracode-baseline restraint and registers every command-triggered marker.
SS="$root/hooks/session-start"
chk "grep -q 'Assume ultracode is the baseline' '$SS'" "overlay states the ultracode baseline"
chk "grep -qi 'match the tool to the task, never to the mode' '$SS'" "overlay carries ultracode restraint guidance"
chk "grep -q '🌿 worktrees' '$SS'" "overlay registers the worktrees marker"

# The Stop pulse must honour stop_hook_active so it cannot loop until the
# platform force-overrides the turn.
U="$root/hooks/unease"
chk "grep -q 'stop_hook_active' '$U'" "unease hook guards against the stop-hook loop"

# Both workflow commands must teach validating the workflow's own result.
chk "grep -qi 'degenerate result' '$root/commands/workflow.md'" "workflow command warns against a degenerate result"
chk "grep -qi 'degenerate result' '$root/commands/pb-workflow.md'" "pb-workflow command warns against a degenerate result"

R="$root/README.md"
chk "! grep -qE '\.playbook/[A-Za-z._-]' '$R'" "README has no .playbook/ path references"
chk "! grep -qi 'uncertaint' '$R'" "README uses unease naming, no uncertainty word"
chk "! grep -qiw 'ledger' '$R'" "README uses log naming, no ledger vocabulary"
chk "grep -qi 'writes no file into' '$R'" "README states no file is written into the tree"
chk "grep -qi 'baseline is ultracode' '$R'" "README states the ultracode baseline"
chk "! grep -q '\.playbook/' '$root/.gitignore'" ".gitignore has no .playbook vestige"
GA="$root/.gitattributes"
chk "! grep -qi 'uncertaint' '$GA'" ".gitattributes has no old uncertainty hook name"
chk "grep -q 'hooks/unease' '$GA'" ".gitattributes pins the renamed unease hook"
exit $fail
