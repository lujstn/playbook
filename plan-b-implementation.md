# Playbook Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `@lujstn/playbook` Claude Code plugin exactly as specified in the locked `design.md`: a decision engine (`playbook:playbook`) plus a nine-tenet execution overlay enforced by two hooks and a pinned anchor file, with five team-mode routing and two moved-in skills.

**Architecture:** A directory-discovered Claude Code plugin (`.claude-plugin/plugin.json` + `marketplace.json`, `skills/*/SKILL.md`, `hooks/hooks.json`) modelled exactly on the Superpowers packaging blueprint. Persistence of the nine-tenet overlay does not come from skill text (a skill fires once and does not follow subagents into fresh contexts): it comes from a `SessionStart` bootstrap hook plus a pinned `.playbook/anchor.md` file, with a `take-a-beat` hook steering compaction and a `uncertainty` hook prompting an end-of-turn confidant test. The engine routes work to native Claude Code, native parallel `Agent` dispatch, native agent-teams, the Superpowers chain, or GSD. It builds no third runtime.

**Tech Stack:** Markdown skills (Superpowers house style), POSIX/bash extensionless hook scripts behind a cross-platform `run-hook.cmd` polyglot wrapper, JSON manifests, `jq` for schema assertions, `bash -n` for hook syntax (shellcheck optional, not a dependency), the `claude` CLI with `--plugin-dir` + `--output-format stream-json` for behavioural skill-trigger tests.

---

## Binding constraints (read before any task)

These come from `design.md` §12 and Appendix A. They are non-negotiable and apply to every task.

1. **`design.md` is the single source of truth for all doctrine content.** Skill prose is *rendered faithfully from* the cited `design.md` section, not invented. Where a task says "verbatim", the exact words from `design.md` must appear in the artifact.
2. **British English, no long dashes.** All generated skill and hook text uses British spelling ("behaviour", "minimise", "colour") and must not use the long dash character. Use commas, parentheses, or full stops instead. (Appendix A's own text is exempt and canonical: never alter quoted Appendix A text.)
3. **Improve adherence; do not re-explain native behaviour.** Skill/hook text must not re-teach native planning, TodoWrite, subagents, compaction, or code hygiene from scratch. It rides on top of native behaviour and closes the specific shortfall named in the `design.md` §3 table.
4. **Appendix A is canonical.** The five states, nine tenets and framing note govern intent. Exactly three deliberate mechanism adaptations are permitted (`design.md` §12): tenet 3's external-manager check-in is gated by the uncertainty ledger; tenet 5's SMS becomes ntfy; tenet 7's "65% of the day" becomes ~65% context used. Any other conflict resolves in favour of Appendix A.
5. **Less is more (tenet 8).** The common path is zero-dependency. Skill prose is short. No invented scope: every artifact maps to a `design.md` section. Do not add features, config wizards, or a third runtime.
6. **Two-principles test.** Every artifact must satisfy "less is more" and "speed is not rushing": complete, not partial; minimal, not bloated.

## Verbatim blocks (paste these exactly; never re-transcribe)

`design.md` is the source of truth for all doctrine. To prevent independent re-transcription drift on the few invariants that must appear **identically and verbatim** across multiple generated artifacts, those exact strings are pinned here. Tasks that reference a block paste it byte-for-byte (it is already British English with no long dash, so no transformation is applied). Everything else is still rendered faithfully from the cited `design.md` section.

**VB-1, the standing North-Star override** (must appear identically in the engine skill, the offline-mode skill, the escalation-ladder doctrine, and `anchor-format.md`; `design.md` §5.1/§6/§8 use minor wording variants, and this single canonical form is used everywhere):

> if an uncertainty or decision could degrade the North Star such that the work would no longer meet it, stop and ask the user before proceeding, regardless of the uncertainty ledger or the mode.

**VB-2, the adjacent-mode tiebreaker** (`design.md` §5.1, paste verbatim into the engine skill):

> Adjacent-mode tiebreaker, applied in this order whenever more than one route seems to fit:
> 1. If the work is separable into sub-tasks that do not need to communicate with each other, choose `intern-team`.
> 2. Else if the work is coupled and needs live peer-to-peer communication because it cannot be cleanly partitioned by file ownership, choose `hackathon-team`.
> 3. Else if the work can be made file-disjoint into waves, choose `superpowers-team` for a session-scoped milestone, or `gsd-team` when durable cross-session state is required.
> 4. Else, if none of the above adds value over a single thread, choose `lone-wolf`.
>
> Separability decides step 1 versus 2 versus 3. Durability decides `superpowers-team` versus `gsd-team` within step 3. Size only decides whether to decompose first (decompose-as-judgement), never which mode runs the work.

**VB-3, the five-mode table** (`design.md` §2, paste verbatim into the engine skill):

> | Mode | When it is chosen | Substrate |
> |---|---|---|
> | `lone-wolf` | Small, single coherent unit; no benefit from extra hands | Native main thread, no subagents |
> | `intern-team` | Several independent sub-tasks; you stay steering; helpers do not need to talk to each other | Native parallel `Agent` dispatch, up to ~10 ephemeral helpers, star topology |
> | `hackathon-team` | Coupled work in one shared codebase; peers must talk to each other; lightweight coordination | `playbook:hackathon-team` over native agent-teams |
> | `superpowers-team` | One session-scoped milestone, separable into waves, no need for durable cross-session state | Superpowers `brainstorming`/`writing-plans` plus `playbook:modifying-plans` plus `playbook:synchronised-subagent-development` |
> | `gsd-team` | Multi-milestone product; state must survive `/clear`; durable project memory required | GSD (`gsd-build/get-shit-done`) |

**VB-4, uncertainty band labels and their slugs** (`design.md` §6 uses prose labels; the ledger encodes them as slugs. This is a deliberate slugification, NOT "verbatim". The engine doctrine instructs the agent to write the slug; `anchor-format.md` carries this mapping table so ledger entries match callout-shape detection):

> | Slug (written to ledger) | design.md §6 prose label | What it instructs |
> |---|---|---|
> | `minorly-unsure` | Minorly unsure | note it, carry on |
> | `starting-unsure` | Starting to become unsure | note it; glance at the ledger next time you pause |
> | `medium-unsure` | Medium unsure | glance now; if an earlier entry shares the theme, research or ask a subagent |
> | `really-unsure` | Really unsure | stop, re-read the North Star, take a beat or get a second pair of eyes before continuing |
> | `dangerously-unsure` | Dangerously unsure | stop now, escalate to the user or a CTO subagent; a single entry at this band trips escalation on its own |

## Testing reality (how "TDD" maps to this plugin)

This plugin is markdown + bash + JSON, not application code. The red/green discipline is preserved but the test mechanism differs by artifact type. Each task states its own verification; the global mapping is:

- **JSON manifests** (`plugin.json`, `marketplace.json`, `hooks.json`): assert with `jq -e` *before* writing the file (the assertion fails because the file is absent), then write, then the assertion passes. A malformed settings/hook JSON silently disables the whole file, so schema assertions are mandatory.
- **Bash hooks**: write a pipe-test first that feeds synthesised stdin JSON and asserts the emitted stdout JSON (the test fails, script absent), then write the script, then it passes. Syntax-gate every hook with `bash -n` (always available). `shellcheck` is run if present but is never a hard dependency.
- **Skills (behaviour-shaping prose)**: the "test" is a behavioural skill-trigger run (`claude -p` with `--plugin-dir` and `--output-format stream-json`, grep the emitted skill id) plus a written review checklist derived from the `design.md` section. Agent behaviour cannot be fully red/green unit-tested; where it cannot, the task says so explicitly and uses a concrete manual verification with expected observable output. This honesty is required by the project's own tenet 6/8 and by `superpowers:verification-before-completion`.

## File structure (decomposition lock-in)

```
/Users/lucas/Developer/lujstn/playbook/
├── .claude-plugin/
│   ├── plugin.json                 # plugin manifest (metadata only; discovery by directory)
│   └── marketplace.json            # marketplace descriptor (source: "./")
├── .gitattributes                  # LF for *.sh, run-hook.cmd, extensionless hooks
├── .gitignore                      # .DS_Store (exists) + .playbook/ + .worktrees/
├── hooks/
│   ├── hooks.json                  # SessionStart, PreCompact, PostToolUse, Stop declarations
│   ├── run-hook.cmd                # cross-platform polyglot dispatcher (cloned verbatim from Superpowers)
│   ├── lib/
│   │   └── playbook-common.sh      # json-escape, anchor/ledger paths, read/write/init, context_percent
│   ├── session-start               # bootstrap: inject overlay pointer + re-inject anchor with primacy
│   ├── take-a-beat                 # tenet 7: PreCompact steer + post-compact re-anchor + ~65% monitor
│   └── uncertainty                 # tenet 4: Stop end-of-turn confidant-test prompt + timestamp writer
├── skills/
│   ├── playbook/SKILL.md           # the engine: North Star, questions, staffing call, 5-mode routing,
│   │                               #   9-tenet doctrine, decompose-as-judgement, writing-plans override,
│   │                               #   escalation ladder, gsd/superpowers prerequisite forks
│   ├── hackathon-team/SKILL.md     # thin choreography over native agent-teams
│   ├── offline-mode/
│   │   ├── SKILL.md                # per-run picker, decision log, ntfy seam, HTML export
│   │   └── decision-log.html.tmpl  # clean morning-readable HTML template
│   ├── modifying-plans/            # ALREADY PRESENT (de-gitlink + selective re-point)
│   │   ├── SKILL.md
│   │   └── prompts/{scout,transformer,contract-checker}.md
│   └── synchronised-subagent-development/   # ALREADY PRESENT (de-gitlink + re-point + conductor whistle)
│       ├── SKILL.md
│       └── prompts/{implementer,spec-reviewer,code-quality-reviewer,wave-integration-reviewer}.md
├── tests/
│   ├── run-all.sh                  # aggregator: bash -n lint, manifests, hooks, skill-trigger
│   ├── manifests.sh                # jq -e schema assertions for all JSON
│   ├── hooks/                      # one pipe-test per hook event
│   │   ├── test-session-start.sh
│   │   ├── test-take-a-beat.sh
│   │   └── test-uncertainty.sh
│   └── skill-triggering/
│       ├── run-test.sh             # claude -p --plugin-dir … stream-json + grep skill id
│       └── prompts/                # non-trivial / explicit / superpowers-team fixtures
├── docs/
│   ├── superpowers/plans/2026-05-16-playbook-plugin.md   # this plan
│   └── playbook/                   # dogfood specs/plans location (mirrors design.md intent)
├── design.md                       # the locked spec (exists; content source of truth)
└── README.md                       # install, five modes, nine tenets, prerequisites
```

Reference clones (read-only, retained for exact upstream citation): `/tmp/playbook-research/superpowers`, `/tmp/playbook-research/gsd`, `/tmp/playbook-research/ccsp`.

---

## Task 1: Repository foundation and de-gitlink the two moved-in skills

**Why first:** `git ls-files -s skills/` shows `skills/modifying-plans` and `skills/synchronised-subagent-development` are committed as mode-`160000` gitlinks with **no `.gitmodules`**. Their actual `SKILL.md` and `prompts/` content is therefore *not tracked* in this repo. Until fixed, the plugin ships two empty skill directories and nothing else in the plan can be verified end-to-end.

**Files:**
- Modify: index entries `skills/modifying-plans`, `skills/synchronised-subagent-development` (remove gitlinks)
- Delete: `skills/modifying-plans/.git`, `skills/synchronised-subagent-development/.git` (nested repos)
- Modify: `/Users/lucas/Developer/lujstn/playbook/.gitignore`

- [ ] **Step 1: Prove the defect (failing observation)**

Run: `git ls-files -s skills/ | awk '{print $1}' | sort -u`
Expected now: `160000` (gitlink mode, the defect). Target after task: `100644` blob modes only.

- [ ] **Step 2: Capture the real file content is on disk**

Run: `test -f skills/modifying-plans/SKILL.md && test -f skills/synchronised-subagent-development/prompts/implementer.md && echo PRESENT`
Expected: `PRESENT` (working-tree files exist; only git tracking is wrong).

- [ ] **Step 3: Remove the gitlink index entries (no working-tree deletion)**

```bash
git rm --cached skills/modifying-plans skills/synchronised-subagent-development
```
Expected: `rm 'skills/modifying-plans'` and `rm 'skills/synchronised-subagent-development'`.

- [ ] **Step 4: Delete the nested git repositories**

```bash
rm -rf skills/modifying-plans/.git skills/synchronised-subagent-development/.git
```

- [ ] **Step 5: Re-add as ordinary tracked files**

```bash
git add skills/modifying-plans skills/synchronised-subagent-development
git ls-files -s skills/ | awk '{print $1}' | sort -u
```
Expected: only `100644` (and `100755` if any executable), no `160000`.

- [ ] **Step 6: Add runtime-state ignores to .gitignore**

The plugin repo's `.gitignore` currently contains only `.DS_Store`. Append the runtime-state directory Playbook writes into *consuming* projects, plus worktree scratch, so a dogfood run never accidentally commits them:

```
.DS_Store
.playbook/
.worktrees/
```

(`.worktrees/` is justified: this plugin owns `synchronised-subagent-development`, which creates worktrees during dogfooding. No `node_modules/` line: there is no Node toolchain in scope.)

- [ ] **Step 7: Verify and commit**

Run: `git status --short && git ls-files skills/ | wc -l`
Expected: `skills/` now lists many files (both SKILL.md plus all `prompts/*.md`), not 2 gitlinks.

```bash
git add .gitignore
git commit -m "fix: de-gitlink moved-in skills so plugin ships their content"
```

---

## Task 2: Plugin manifest and marketplace descriptor

**Files:**
- Create: `/Users/lucas/Developer/lujstn/playbook/.claude-plugin/plugin.json`
- Create: `/Users/lucas/Developer/lujstn/playbook/.claude-plugin/marketplace.json`
- Test: `tests/manifests.sh`

Blueprint is the Superpowers manifest pair (`/tmp/playbook-research/superpowers/.claude-plugin/`), which is metadata-only: Claude Code discovers skills via `skills/*/SKILL.md` and hooks via `hooks/hooks.json`; do **not** add `skills`/`hooks` keys to `plugin.json`.

- [ ] **Step 1: Write the failing manifest assertion**

Create `tests/manifests.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
fail=0

assert() { if eval "$1" >/dev/null 2>&1; then echo "PASS: $2"; else echo "FAIL: $2"; fail=1; fi; }

assert "jq -e '.name == \"playbook\"' '$root/.claude-plugin/plugin.json'" "plugin.json name is playbook"
assert "jq -e '.version and .description and .license' '$root/.claude-plugin/plugin.json'" "plugin.json has core metadata"
assert "jq -e 'has(\"skills\") | not' '$root/.claude-plugin/plugin.json'" "plugin.json does NOT list skills (directory discovery)"
assert "jq -e '.plugins[0].name == \"playbook\" and .plugins[0].source == \"./\"' '$root/.claude-plugin/marketplace.json'" "marketplace lists playbook at ./"

exit $fail
```

Run: `bash tests/manifests.sh`
Expected: FAIL lines (files absent).

- [ ] **Step 2: Write `.claude-plugin/plugin.json`**

```json
{
  "name": "playbook",
  "description": "Personal Claude Code workflow harness: a decision engine that makes one visible staffing call across five team modes, plus a nine-tenet execution overlay that improves adherence through execution and compaction.",
  "version": "0.1.0",
  "author": {
    "name": "Lucas Johnston Kurilov",
    "email": "lucas@buildin.london"
  },
  "homepage": "https://github.com/lujstn/playbook",
  "repository": "https://github.com/lujstn/playbook",
  "license": "MIT",
  "keywords": [
    "workflow",
    "skills",
    "decision-engine",
    "subagents",
    "compaction",
    "playbook"
  ]
}
```

- [ ] **Step 3: Write `.claude-plugin/marketplace.json`**

```json
{
  "name": "playbook-dev",
  "description": "Distribution marketplace for the Playbook workflow harness",
  "owner": {
    "name": "Lucas Johnston Kurilov",
    "email": "lucas@buildin.london"
  },
  "plugins": [
    {
      "name": "playbook",
      "description": "Personal Claude Code workflow harness: decision engine plus nine-tenet execution overlay.",
      "version": "0.1.0",
      "source": "./",
      "author": {
        "name": "Lucas Johnston Kurilov",
        "email": "lucas@buildin.london"
      }
    }
  ]
}
```

- [ ] **Step 4: Run the assertion to verify it passes**

Run: `bash tests/manifests.sh`
Expected: all `PASS:` lines, exit 0.

- [ ] **Step 5: Commit**

```bash
git add .claude-plugin/plugin.json .claude-plugin/marketplace.json tests/manifests.sh
git commit -m "feat: add playbook plugin manifest and marketplace descriptor"
```

---

## Task 3: Hook harness (polyglot wrapper, hooks.json skeleton, shared lib, gitattributes)

**Files:**
- Create: `/Users/lucas/Developer/lujstn/playbook/hooks/run-hook.cmd`
- Create: `/Users/lucas/Developer/lujstn/playbook/hooks/hooks.json`
- Create: `/Users/lucas/Developer/lujstn/playbook/hooks/lib/playbook-common.sh`
- Create: `/Users/lucas/Developer/lujstn/playbook/.gitattributes`

`run-hook.cmd` is cloned verbatim from `/tmp/playbook-research/superpowers/hooks/run-hook.cmd` (a proven cross-platform polyglot: bash here-doc no-op skips the cmd block on Unix; cmd.exe ignores the leading `:` line). Only the leading comment changes.

- [ ] **Step 1: Write the failing harness test**

Create `tests/hooks/test-harness.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
bash -n "$root/hooks/run-hook.cmd" 2>/dev/null && echo "PASS: run-hook.cmd parses as bash" || { echo "FAIL: run-hook.cmd"; exit 1; }
jq -e '.hooks | type == "object"' "$root/hooks/hooks.json" >/dev/null && echo "PASS: hooks.json valid" || { echo "FAIL: hooks.json"; exit 1; }
bash -n "$root/hooks/lib/playbook-common.sh" && echo "PASS: playbook-common.sh parses" || { echo "FAIL: lib"; exit 1; }
```

Run: `bash tests/hooks/test-harness.sh`
Expected: FAIL (files absent).

- [ ] **Step 2: Write `hooks/run-hook.cmd`** (verbatim clone; swap the header comment to say `playbook`)

Copy `/tmp/playbook-research/superpowers/hooks/run-hook.cmd` byte-for-byte, changing only the comment line `REM Cross-platform polyglot wrapper for hook scripts.` block to reference Playbook. The mechanism (Git-for-Windows bash discovery, PATH bash fallback, silent exit if no bash, Unix `exec bash "${SCRIPT_DIR}/${SCRIPT_NAME}" "$@"`) must remain identical.

- [ ] **Step 3: Write `hooks/lib/playbook-common.sh`** (shared helpers; `context_percent` is a stub until Task 4 resolves the signal)

```bash
#!/usr/bin/env bash
# Shared helpers for Playbook hooks. Sourced, never executed directly.

# Resolve the project working directory from hook stdin or PWD.
playbook_project_dir() {
  local cwd
  cwd="$(jq -r '.cwd // empty' 2>/dev/null <<<"${1:-}")"
  [ -n "$cwd" ] && { printf '%s' "$cwd"; return; }
  printf '%s' "${CLAUDE_PROJECT_DIR:-$PWD}"
}

playbook_dir()        { printf '%s/.playbook' "$(playbook_project_dir "${1:-}")"; }
playbook_anchor()     { printf '%s/anchor.md' "$(playbook_dir "${1:-}")"; }
playbook_ledger()     { printf '%s/uncertainty-ledger.md' "$(playbook_dir "${1:-}")"; }

playbook_ensure_dir() {
  # Only creates the runtime directory. It MUST NOT mutate the consuming
  # project's .gitignore: that is an unsolicited side-effect, races under
  # parallel Stop-hook fire, and is not authorised by design.md. The README
  # documents .playbook/ and the engine proposes the ignore once (Task 11/17),
  # never a per-turn hook.
  mkdir -p "$(playbook_dir "${1:-}")" 2>/dev/null || true
}

# JSON-string escape via bash parameter substitution (single C-level passes;
# identical technique to the Superpowers session-start hook).
playbook_json_escape() {
  local s="$1"
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
  local event="$1" body="$2" escaped
  escaped="$(playbook_json_escape "$body")"
  if [ -n "${CURSOR_PLUGIN_ROOT:-}" ]; then
    printf '{\n  "additional_context": "%s"\n}\n' "$escaped"
  elif [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -z "${COPILOT_CLI:-}" ]; then
    printf '{\n  "hookSpecificOutput": {\n    "hookEventName": "%s",\n    "additionalContext": "%s"\n  }\n}\n' "$event" "$escaped"
  else
    printf '{\n  "additionalContext": "%s"\n}\n' "$escaped"
  fi
}

# STUB: replaced by Task 4 with the spike-decided context measurement.
# Returns integer 0-100 (percent of context window used) or empty if unknown.
playbook_context_percent() { printf ''; }
```

- [ ] **Step 4: Write `hooks/hooks.json`** (skeleton; later tasks add PreCompact/PostToolUse/Stop entries)

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" session-start",
            "async": false
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 5: Write `.gitattributes`** (LF discipline so the polyglot and extensionless hooks work on Windows)

```
*.sh text eol=lf
hooks/run-hook.cmd text eol=lf
hooks/session-start text eol=lf
hooks/take-a-beat text eol=lf
hooks/uncertainty text eol=lf
*.md text eol=lf
*.json text eol=lf
```

- [ ] **Step 6: Make hooks executable, verify, commit**

```bash
chmod +x hooks/run-hook.cmd
bash tests/hooks/test-harness.sh
```
Expected: three `PASS:` lines.

```bash
git add hooks/run-hook.cmd hooks/hooks.json hooks/lib/playbook-common.sh .gitattributes tests/hooks/test-harness.sh
git commit -m "feat: add cross-platform hook harness and shared lib"
```

---

## Task 4 (SPIKE): Resolve the ~65% context signal for take-a-beat

**Why a spike:** `design.md` §3 tenet 7 and §12 require `take-a-beat` to fire at ~65% context used. Research confirmed there is **no native hook event that fires on a context threshold**. The signal is observable (the native `Token usage: used/total; remaining` system reminder) and GSD ships a working reference pattern. This spike picks the mechanism and replaces the `playbook_context_percent` stub. It blocks Task 7.

**Files:**
- Modify: `/Users/lucas/Developer/lujstn/playbook/hooks/lib/playbook-common.sh` (`playbook_context_percent`)
- Create: `/Users/lucas/Developer/lujstn/playbook/docs/playbook/decisions/2026-05-16-context-signal.md`

- [ ] **Step 1: Enumerate candidate signal sources (investigation, no code)**

Inspect each and record findings in the decision doc:
1. Hook stdin JSON: run a throwaway `PostToolUse` command hook that does `jq . > /tmp/pb-stdin.json` and inspect for any `tokens`/`context`/`usage` field.
2. Environment variables visible to hooks (`env | grep -i -E 'token|context|claude'`).
3. GSD's bridge pattern: `/tmp/playbook-research/gsd/hooks/gsd-statusline.js` writes `/tmp/claude-ctx-{session}.json`; `gsd-context-monitor.js` (a `PostToolUse` hook) reads it and warns at ≤35%/≤25% remaining. Read both files for the exact field names and the session-id source.
4. Transcript file: the session `.jsonl` under the Claude projects dir contains token-usage system reminders that can be tailed.

- [ ] **Step 2: Decide and document (with the used-vs-remaining inversion made explicit)**

Pick the simplest sufficient source (tenet 8). Default expectation from research: a `PostToolUse` hook reads a session-keyed bridge file if Claude Code writes one, else parse the most recent `Token usage:` reminder from the session transcript.

CRITICAL ARITHMETIC: `design.md` §3 tenet 7 / §12 require firing at "~65% **used**". GSD's reference bridge (`/tmp/playbook-research/gsd/hooks/gsd-statusline.js`, `gsd-context-monitor.js`) keys on `context_window.remaining_percentage` and warns at `remaining <= 35` (i.e. 65% used). If you literally "replicate GSD" you get *remaining*, and comparing remaining `>= 65` fires at 35% used or never. Therefore: `playbook_context_percent` MUST return **percent used**, derived as `used = 100 - remaining_percentage` when the source exposes remaining. Decide explicitly whether to mirror GSD's auto-compact-buffer rescale (`AUTO_COMPACT_BUFFER_PCT`) or use the raw window; record the exact formula.

Write `docs/playbook/decisions/2026-05-16-context-signal.md` stating: chosen source, exact field/path, session-id derivation, the precise used-from-remaining formula, the rescale decision, and the silent-degradation fallback (empty string, never a wrong number, no false beats).

- [ ] **Step 3: Write a failing test for `playbook_context_percent`**

Create `tests/hooks/test-context-percent.sh` that synthesises the chosen input (e.g. a fixture bridge file or a fixture transcript line at 70% used) and asserts:

```bash
#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
source "$root/hooks/lib/playbook-common.sh"
# Fixture represents 700000/1000000 used. (Exact harness per Step 2 decision.)
export PLAYBOOK_CTX_FIXTURE="$root/tests/hooks/fixtures/ctx-used-70.json"
got="$(playbook_context_percent)"
[ "$got" = "70" ] && echo "PASS: 70% used parsed" || { echo "FAIL: got '$got'"; exit 1; }
# Inversion guard: a GSD-shaped fixture with remaining_percentage=35 MUST
# yield 65 (used), proving used = 100 - remaining is applied. This is the
# regression test for review finding M3.
export PLAYBOOK_CTX_FIXTURE="$root/tests/hooks/fixtures/ctx-remaining-35.json"
got="$(playbook_context_percent)"
[ "$got" = "65" ] && echo "PASS: remaining=35 -> used=65 (no inversion)" || { echo "FAIL inversion: got '$got'"; exit 1; }
# Absent signal must yield empty, never a wrong number.
unset PLAYBOOK_CTX_FIXTURE
[ -z "$(playbook_context_percent)" ] && echo "PASS: silent when unknown" || { echo "FAIL: not silent"; exit 1; }
```

Run: `bash tests/hooks/test-context-percent.sh`
Expected: FAIL (stub returns empty for the 70% case).

- [ ] **Step 4: Implement `playbook_context_percent` per the decision**

Replace the stub in `playbook-common.sh` with the chosen mechanism. It must: return an integer 0 to 100 when the signal is available; return empty string when it is not (caller treats empty as "do not beat"); never block or error the hook (wrap in `2>/dev/null || true`).

- [ ] **Step 5: Run the test to verify it passes**

Run: `bash tests/hooks/test-context-percent.sh`
Expected: `PASS: 70% parsed` and `PASS: silent when unknown`.

- [ ] **Step 6: Commit**

```bash
git add hooks/lib/playbook-common.sh tests/hooks/test-context-percent.sh tests/hooks/fixtures docs/playbook/decisions/2026-05-16-context-signal.md
git commit -m "feat: resolve context-usage signal for take-a-beat (~65% trigger)"
```

---

## Task 5 (SPIKE): Resolve the Stop-hook output channel for the uncertainty prompt

**Why a spike:** `design.md` §4 says the `uncertainty` hook fires at the end of every turn and asks the agent one question (the confidant test); it performs no computation, and the **default expected answer is "log nothing" and the turn ends normally**. The Hooks Configuration reference says `type: prompt`/`type: agent` are unavailable for `Stop` (command only). The documented model-visible Stop channels are `decision:"block"`+`reason` (surfaced via the "hook stopped continuation" reminder) and `systemMessage` (explicitly user-UI-only); `additionalContext` is documented generically but only worked-examples for tool/compact events show it injecting. This spike picks the channel empirically.

HARD CONSTRAINT the spike must satisfy: the chosen mechanism MUST NOT prevent the turn from ending in the common (log-nothing) case. `decision:"block"` forces continuation with `reason`, so emitting it every turn would trap the agent in infinite continuation and is therefore disqualified as the every-turn channel (it remains usable only if conditionally emitted, which the design forbids since the hook performs no computation). The viable outcome is a channel that injects a one-line nudge the agent sees on the next turn while the current turn still terminates. It blocks Task 8. Independent of Task 4; parallel-safe.

**Files:**
- Create: `/Users/lucas/Developer/lujstn/playbook/docs/playbook/decisions/2026-05-16-stop-channel.md`

- [ ] **Step 1: Build the probe hook**

Temporarily add a `Stop` entry to `hooks/hooks.json` pointing at a throwaway script that emits, in successive trials: (a) `{"hookSpecificOutput":{"hookEventName":"Stop","additionalContext":"PB-PROBE-A"}}`, (b) `{"systemMessage":"PB-PROBE-B"}`, (c) `{"decision":"block","reason":"PB-PROBE-C"}`, (d) `{}` (empty, the control, confirms the turn ends cleanly with no output).

- [ ] **Step 2: Observe channel AND termination**

Reload hooks (open `/hooks` once, or restart; `Stop` fires outside the turn so it cannot be proven in-turn, the documented settings-watcher caveat). For each trial record TWO things: (1) does `PB-PROBE-x` appear as model-visible context on the next turn, or only in user UI; (2) **did the turn actually end, or did the agent get forced to continue?** Trial (c) is expected to force continuation (disqualified per the hard constraint). The chosen channel is the one that is model-visible AND lets trial (a)/(d)-style turns terminate normally.

- [ ] **Step 3: Decide and document**

Write `docs/playbook/decisions/2026-05-16-stop-channel.md` recording: the chosen channel; the exact JSON shape; explicit confirmation that with this channel a log-nothing turn still terminates (no infinite continuation); and the constraint that the hook only *prompts* the confidant test while the timestamp is written by `playbook_ledger_append` when the agent itself appends an entry (the hook computes nothing and holds no score, per `design.md` §4/§6). If no channel is both model-visible and termination-safe, record that the uncertainty nudge moves to a `UserPromptSubmit` or `PostToolUse`-adjacent carrier instead, and update Task 8 accordingly. Remove the probe `Stop` entry and the throwaway script.

- [ ] **Step 4: Commit the decision**

```bash
git add docs/playbook/decisions/2026-05-16-stop-channel.md
git checkout -- hooks/hooks.json   # ensure probe entry removed
git commit -m "docs: decide Stop-hook output channel for uncertainty prompt"
```

---

## Task 6: Anchor file and uncertainty-ledger protocol

**Files:**
- Modify: `/Users/lucas/Developer/lujstn/playbook/hooks/lib/playbook-common.sh` (read/write/init helpers)
- Create: `/Users/lucas/Developer/lujstn/playbook/docs/playbook/anchor-format.md`
- Test: `tests/hooks/test-anchor.sh`

Schemas come from `design.md` §6. Anchor: original user request verbatim; current one-line what-matters; lessons-and-wrong-turns ledger (including silent wrong turns); next work. Uncertainty ledger: append-only, one line per entry = `ISO-8601 timestamp | band-slug | single clause phrased as drift from the North Star`. The band slugs are NOT verbatim from §6 (review finding M6): §6 uses prose labels; the ledger encodes them as the slugs in **VB-4**. This is a deliberate, documented slugification, so the engine doctrine (Task 9) must instruct the agent to write the exact slug so ledger entries match callout-shape detection. Location `.playbook/` in the working project (must not collide with GSD's `.planning/`).

- [ ] **Step 1: Write the failing protocol test**

Create `tests/hooks/test-anchor.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
source "$root/hooks/lib/playbook-common.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
in="{\"cwd\":\"$tmp\"}"

playbook_anchor_init "Build X without breaking Y" "Ship X; never regress Y" "$in"
test -f "$tmp/.playbook/anchor.md" && echo "PASS: anchor created" || { echo FAIL; exit 1; }
grep -qF "Build X without breaking Y" "$tmp/.playbook/anchor.md" && echo "PASS: original request verbatim" || { echo FAIL; exit 1; }
# M8: playbook_ensure_dir must NOT have touched the project .gitignore.
[ ! -e "$tmp/.gitignore" ] && echo "PASS: no unsolicited .gitignore mutation" || { echo "FAIL: hook mutated .gitignore"; exit 1; }

playbook_ledger_append "really-unsure" "less sure I am still delivering X, because schema Y changed" "$in"
tail -1 "$tmp/.playbook/uncertainty-ledger.md" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T.*\| really-unsure \|' \
  && echo "PASS: ledger line shape" || { echo FAIL; exit 1; }
```

Run: `bash tests/hooks/test-anchor.sh`
Expected: FAIL (`playbook_anchor_init` undefined).

- [ ] **Step 2: Add the protocol helpers to `playbook-common.sh`**

Append:

```bash
playbook_anchor_init() {
  local original="$1" what_matters="$2" stdin="${3:-}"
  playbook_ensure_dir "$stdin"
  local f; f="$(playbook_anchor "$stdin")"
  [ -f "$f" ] && return 0   # never clobber an existing anchor
  cat >"$f" <<EOF
# Playbook anchor

## Original request (verbatim)
$original

## What matters now (one line)
$what_matters

## Lessons and wrong turns
(none yet)

## Next work
(set by the engine)
EOF
}

playbook_ledger_append() {
  local band="$1" clause="$2" stdin="${3:-}"
  playbook_ensure_dir "$stdin"
  local f ts; f="$(playbook_ledger "$stdin")"
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '%s | %s | %s\n' "$ts" "$band" "$clause" >>"$f"
}

playbook_anchor_read() { local f; f="$(playbook_anchor "${1:-}")"; [ -f "$f" ] && cat "$f" || printf ''; }
```

- [ ] **Step 3: Write `docs/playbook/anchor-format.md`**

Document, faithfully from `design.md` §6: both schemas; the **VB-4 band table** (slug, the §6 prose label, what each instructs) presented explicitly as a deliberate slugification mapping, not as verbatim §6 text; the one-hour active-development reading window; the three callout shapes (single top-band entry; rising staircase; same-theme cluster); and the standing North-Star override pasted verbatim from **VB-1**. Add this note (review findings m6, MINOR-1): "Timestamp authority: the ISO-8601 stamp is written by `playbook_ledger_append` at the moment the agent appends an entry, not by the `uncertainty` hook process. This is NOT a fourth §12 adaptation: §6's literal phrase 'written by the uncertainty hook' is physically unrealisable (the hook fires on Stop, after the turn, and `design.md` §4 forbids it from computing anything, so it cannot author an entry the agent writes during a later turn). This is therefore a mechanism-realisation of an unrealisable literal, governed by §12's own principle that canonicity governs intent and lens, not literal mechanism; the intent (every entry is wall-clock timestamped, the hook holds no score) is fully preserved. Do not later 'correct' the mechanism toward the literal wording." British English, no long dashes.

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/hooks/test-anchor.sh`
Expected: all `PASS:` lines.

- [ ] **Step 5: Commit**

```bash
git add hooks/lib/playbook-common.sh tests/hooks/test-anchor.sh docs/playbook/anchor-format.md
git commit -m "feat: add anchor file and uncertainty-ledger protocol"
```

---

## Task 7: `take-a-beat` hook (tenet 7)

**Depends on:** Task 4 (context signal), Task 6 (anchor).

**Files:**
- Create: `/Users/lucas/Developer/lujstn/playbook/hooks/take-a-beat`
- Modify: `/Users/lucas/Developer/lujstn/playbook/hooks/hooks.json` (add `PreCompact` and the monitor event)
- Test: `tests/hooks/test-take-a-beat.sh`

One extensionless script dispatched by event. Three responsibilities from `design.md` §3 tenet 7 and §6:
1. **PreCompact**: emit `additionalContext` containing a `## Compact Instructions` block that steers native compaction to preserve the lessons-and-wrong-turns ledger verbatim and re-anchor on the original request (native compaction explicitly honours injected compact instructions, confirmed in research).
2. **Post-compaction** (`SessionStart` matcher `compact`, or `PostCompact` per the harness): re-inject the anchor first so original intent outranks orchestration scaffolding.
3. **Monitor** (the event chosen in Task 4, e.g. `PostToolUse`): when `playbook_context_percent` ≥ 65, emit a one-line announced "taking a beat" prompt that re-reads the anchor and lessons. Empty/unknown percent → emit nothing.

- [ ] **Step 1: Write the failing pipe-tests**

Create `tests/hooks/test-take-a-beat.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
H="$root/hooks/take-a-beat"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
source "$root/hooks/lib/playbook-common.sh"
printf '{"cwd":"%s"}' "$tmp" > "$tmp/in.json"
playbook_anchor_init "ORIG-REQ" "WHAT-MATTERS" "$(cat "$tmp/in.json")"

# PreCompact: must inject compact instructions naming the lessons ledger.
out="$(jq -c '. + {hook_event_name:"PreCompact"}' "$tmp/in.json" | bash "$H")"
jq -e '.hookSpecificOutput.additionalContext | test("Compact Instructions")' <<<"$out" >/dev/null \
  && echo "PASS: precompact steers" || { echo "FAIL precompact"; exit 1; }
grep -q "Lessons and wrong turns" <<<"$out" && echo "PASS: lessons preserved" || { echo "FAIL lessons"; exit 1; }

# Post-compaction: anchor re-injected with primacy.
out="$(jq -c '. + {hook_event_name:"SessionStart",source:"compact"}' "$tmp/in.json" | bash "$H")"
grep -q "ORIG-REQ" <<<"$out" && echo "PASS: anchor re-injected" || { echo "FAIL reanchor"; exit 1; }

# Monitor below threshold: silent.
PLAYBOOK_CTX_FIXTURE="$root/tests/hooks/fixtures/ctx-used-40.json" \
  out="$(jq -c '. + {hook_event_name:"PostToolUse"}' "$tmp/in.json" | bash "$H")"
[ -z "$out" ] || [ "$(jq -r '.hookSpecificOutput.additionalContext // ""' <<<"$out")" = "" ] \
  && echo "PASS: no beat under 65%" || { echo "FAIL spurious beat"; exit 1; }

# Monitor at/over threshold: announces the beat.
PLAYBOOK_CTX_FIXTURE="$root/tests/hooks/fixtures/ctx-used-70.json" \
  out="$(jq -c '. + {hook_event_name:"PostToolUse"}' "$tmp/in.json" | bash "$H")"
grep -qi "taking a beat" <<<"$out" && echo "PASS: beat at 70%" || { echo "FAIL no beat"; exit 1; }

# Unrelated event (e.g. Stop) must produce nothing (regression for m3).
out="$(jq -c '. + {hook_event_name:"Stop"}' "$tmp/in.json" | bash "$H")"
[ -z "$out" ] && echo "PASS: silent on non-handled events" || { echo "FAIL: spurious output on Stop"; exit 1; }
```

Run: `bash tests/hooks/test-take-a-beat.sh`
Expected: FAIL (script absent).

Fixtures: this test reuses `tests/hooks/fixtures/ctx-used-70.json` (created in Task 4) and additionally needs `tests/hooks/fixtures/ctx-used-40.json` (a 40%-used fixture in the identical shape). Create `ctx-used-40.json` here if absent.

- [ ] **Step 2: Write `hooks/take-a-beat`**

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/playbook-common.sh"

stdin="$(cat 2>/dev/null || true)"
event="$(jq -r '.hook_event_name // empty' 2>/dev/null <<<"$stdin")"
anchor="$(playbook_anchor_read "$stdin")"

MONITOR_EVENT="PostToolUse"   # the monitor event chosen in Task 4; change here only

case "$event" in
  PreCompact)
    body="## Compact Instructions
When summarising this conversation, preserve the Playbook anchor's Lessons and wrong turns section verbatim (silent wrong turns included, not only errors that produced a stack trace). Re-anchor the summary on the original user request and the next work, so the original intent outranks planning and orchestration scaffolding. The anchor follows:

${anchor}"
    playbook_emit_context "PreCompact" "$body"
    ;;
  PostCompact)
    # First-class post-compaction event ("receives summary" per the hooks
    # reference). Re-inject the anchor with primacy regardless of matcher.
    [ -n "$anchor" ] && playbook_emit_context "PostCompact" \
      "Playbook anchor (restored first, before orchestration scaffolding):

${anchor}"
    ;;
  SessionStart)
    # Belt-and-braces: if the harness re-runs SessionStart after auto-compaction
    # (source=compact) rather than PostCompact, restore the anchor here too.
    src="$(jq -r '.source // empty' 2>/dev/null <<<"$stdin")"
    if [ "$src" = "compact" ] && [ -n "$anchor" ]; then
      playbook_emit_context "SessionStart" \
        "Playbook anchor (restored first, before orchestration scaffolding):

${anchor}"
    fi
    ;;
  "$MONITOR_EVENT")
    pct="$(playbook_context_percent || true)"
    if [ -n "$pct" ] && [ "$pct" -ge 65 ] 2>/dev/null; then
      playbook_emit_context "$MONITOR_EVENT" \
        "Taking a beat: context is at ${pct}% used. Pause, re-read the Playbook anchor and its lessons ledger, then continue with a fresh head. Carry the lessons forward; do not treat them as historical. Anchor:

${anchor}"
    fi
    ;;
  *)
    : # any other event: emit nothing (m3: no broad wildcard monitor)
    ;;
esac
exit 0
```

- [ ] **Step 3: Wire `hooks.json`**: add all three take-a-beat events, each dispatching `run-hook.cmd take-a-beat`:
  - `PreCompact` matcher `manual|auto` (the lessons-preserving compaction steer). Note: `manual` and `auto` are the two documented matcher VALUES for compaction events, combined as a regex alternation exactly as Superpowers combines `startup|clear|compact` for SessionStart; this is the correct matcher syntax, not free-form regex.
  - `PostCompact` matcher `manual|auto` (the documented "after compaction, receives summary" event, the primary post-compaction anchor restore).
  - The Task-4 monitor event (default `PostToolUse`, matcher `*`).
  The `SessionStart` entry from Task 3 continues to dispatch `session-start`; its `compact` source ALSO restores the anchor inside `take-a-beat`'s `SessionStart` branch as belt-and-braces. Both PostCompact and SessionStart/compact restoring is intentional and idempotent (the anchor is the same text); do NOT remove either path.

- [ ] **Step 3a: Empirically confirm the post-compaction event (spike step, blocks Task 14 Step 3)**

It is unverified whether Claude Code fires `PostCompact` or re-fires `SessionStart` (source `compact`) after an *auto*-compaction. Trigger an auto-compaction (or force `/compact`), and from a sentinel write in each branch (e.g. `echo "$(date) <branch>" >> /tmp/pb-compact-probe`) record which branch actually fired. Write the finding to `docs/playbook/decisions/2026-05-16-compaction-wiring.md`. Keep both paths regardless (belt-and-braces); the decision doc records which is load-bearing so Task 14 does not delete the wrong one.

- [ ] **Step 4: Make executable, run tests, lint**

```bash
chmod +x hooks/take-a-beat
bash -n hooks/take-a-beat
bash tests/hooks/test-take-a-beat.sh
```
Expected: `bash -n` silent; all `PASS:` lines.

- [ ] **Step 5: Commit**

```bash
git add hooks/take-a-beat hooks/hooks.json tests/hooks/test-take-a-beat.sh
git commit -m "feat: add take-a-beat hook (tenet 7: steered compaction + 65% beat)"
```

---

## Task 8: `uncertainty` hook (tenet 4)

**Depends on:** Task 5 (Stop channel), Task 6 (ledger).

**Files:**
- Create: `/Users/lucas/Developer/lujstn/playbook/hooks/uncertainty`
- Modify: `/Users/lucas/Developer/lujstn/playbook/hooks/hooks.json` (add `Stop`)
- Test: `tests/hooks/test-uncertainty.sh`

From `design.md` §4 and §6: fires at end of every turn (`Stop`), asks the agent the single confidant-test question; default expected answer is "log nothing"; the hook performs no computation and holds no score; it only prompts and (when the agent appends an entry) the helper writes the wall-clock timestamp. Channel/shape from Task 5's decision doc.

- [ ] **Step 0: Read the decided channel (gate)**

Open `docs/playbook/decisions/2026-05-16-stop-channel.md` (Task 5). This task is BLOCKED until that decision exists. Implement strictly to the chosen channel and carrier; do not assume `additionalContext`.

- [ ] **Step 1: Write the failing pipe-test (channel-shape + termination guard)**

Create `tests/hooks/test-uncertainty.sh`. The channel-shape assertion is filled from the decision doc; the termination guard is fixed regardless of channel:

```bash
#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
H="$root/hooks/uncertainty"
out="$(echo '{"hook_event_name":"Stop"}' | bash "$H")"
# (a) The confidant gate prompt is present (verbatim VB-style sentence).
grep -qi "would a competent colleague bother flagging" <<<"$out" && echo "PASS: gate question present" || { echo FAIL gate; exit 1; }
# (b) Channel shape per docs/playbook/decisions/2026-05-16-stop-channel.md
#     (e.g. jq -e '.hookSpecificOutput.additionalContext' OR the decided carrier).
jq -e '<JQ EXPR FROM DECISION DOC>' <<<"$out" >/dev/null && echo "PASS: decided channel shape" || { echo FAIL channel; exit 1; }
# (c) Termination guard (regression for review finding C1): the hook MUST NOT
#     emit an unconditional decision:block, which would trap every turn in
#     infinite continuation. design.md §4 forbids the hook computing anything,
#     so a conditional block is also impossible here -> assert no block at all.
jq -e '(.decision // "") != "block"' <<<"$out" >/dev/null && echo "PASS: turn can terminate (no forced block)" || { echo "FAIL: hook would force infinite continuation"; exit 1; }
# (d) Hook prompts only: it must not itself write a band slug.
grep -qiE 'dangerously-unsure|really-unsure|medium-unsure' <<<"$out" && { echo "FAIL hook editorialised"; exit 1; } || echo "PASS: hook prompts only"
```

Run: `bash tests/hooks/test-uncertainty.sh`
Expected: FAIL (script absent). After Step 2 the `<JQ EXPR FROM DECISION DOC>` placeholder is replaced with the concrete expression from Task 5's decision (this is a decision-driven fill, not a plan placeholder).

- [ ] **Step 2: Add `playbook_emit_stop_nudge` to `playbook-common.sh`, then write `hooks/uncertainty`**

The Stop channel lives in ONE helper so the decided shape is changed in one place. Add to `playbook-common.sh` (body filled from the decision doc; the example below is the `additionalContext` outcome, replace the emit line if Task 5 chose otherwise):

```bash
# Stop-turn nudge. Channel decided by docs/playbook/decisions/2026-05-16-stop-channel.md.
# MUST be a model-visible, turn-terminating channel (never unconditional decision:block).
playbook_emit_stop_nudge() {
  local body="$1"
  playbook_emit_context "Stop" "$body"   # replace with decided carrier if not additionalContext
}
```

Then `hooks/uncertainty`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/playbook-common.sh"
_=$(cat 2>/dev/null || true)   # drain stdin; the hook reads nothing from it

prompt="Uncertainty check (confidant gate): would a competent colleague bother flagging anything from this turn to the lead if they walked past? On almost every turn the answer is no and you log nothing. If yes, append one line to the uncertainty ledger via the documented append helper: a band slug (minorly-unsure, starting-unsure, medium-unsure, really-unsure, dangerously-unsure per the VB-4 mapping) and a single clause phrased as drift from the North Star. Standing override still applies: if an uncertainty or decision could degrade the North Star such that the work would no longer meet it, stop and ask the user before proceeding, regardless of the uncertainty ledger or the mode."

playbook_emit_stop_nudge "$prompt"
exit 0
```

The slug list MUST match VB-4 and the engine doctrine (Task 9). The timestamp is written by `playbook_ledger_append` when the agent appends, not by this hook (the hook computes nothing, per `design.md` §4/§6; recorded in `anchor-format.md` per m6).

- [ ] **Step 3: Wire `hooks.json`**: add a `Stop` entry dispatching `run-hook.cmd uncertainty`.

- [ ] **Step 4: Make executable, run test, lint**

```bash
chmod +x hooks/uncertainty
bash -n hooks/uncertainty
bash tests/hooks/test-uncertainty.sh
```
Expected: `bash -n` silent; all `PASS:` lines.

- [ ] **Step 5: Commit**

```bash
git add hooks/uncertainty hooks/hooks.json tests/hooks/test-uncertainty.sh
git commit -m "feat: add uncertainty hook (tenet 4: end-of-turn confidant gate)"
```

---

## Task 9: `playbook:playbook` engine skill

**Depends on:** Task 6 (anchor protocol referenced by doctrine).

**Files:**
- Create: `/Users/lucas/Developer/lujstn/playbook/skills/playbook/SKILL.md`

This is the largest artifact. It is rendered faithfully from `design.md` §2, §3, §5.1, §6, §7, §8, §9, §10 and Appendix A. House style follows Superpowers (`/tmp/playbook-research/superpowers/skills/*/SKILL.md`): frontmatter is exactly `name` + `description`; `description` is third-person, "Use when…", triggering-conditions only, never a workflow summary (the CSO rule, a description that summarises the workflow makes the model follow the description instead of the skill); body uses `## Overview`, a `**Core principle:**` line, an `**Announce at start:**` line, a `dot` process-flow graph, `## Red Flags` Never/Always, `## Integration`. British English, no long dashes. Must not re-explain native plan mode/subagents/compaction; it rides on them.

- [ ] **Step 1: Write the frontmatter and trigger (CSO-correct)**

```markdown
---
name: playbook
description: Use at the start of any non-trivial work, before planning or coding, to restate what matters, ask questions once, and make one visible staffing call across five team modes.
---
```

Constraint: total frontmatter under 1024 characters; the `description` must not describe the routing mechanics (CSO).

- [ ] **Step 2: Write the Overview, Core principle, Announce line**

Body opens:

```markdown
# Playbook

## Overview

Playbook is the front door for non-trivial work. It restates the one thing that matters, asks its questions once, and makes a single visible staffing call: which of five team modes runs the work and why. It then keeps a nine-tenet overlay live on top of whichever mode was chosen. It does not replace native Claude Code, Superpowers, or GSD; it hops on top of them.

**Core principle:** Less is more, and speed is not rushing. Pick the cheapest sufficient mode, ask questions once, keep the North Star load-bearing at every decision, and fan work across agents only when it is separable.

**Announce at start:** "I'm using the playbook skill to set the North Star and make the staffing call."
```

- [ ] **Step 3: Write the engine flow** rendered faithfully from `design.md` §5.1 steps 1 to 7. Paste the standing North-Star override from **VB-1** verbatim (do not re-transcribe it).

Include a `dot` process-flow graph with the override path as an explicit node so the committed engine skill is internally complete at this task (review finding m4): `Restate North Star -> Batch questions -> Assess separability+durability -> Decompose? -> Staffing call -> Route -> [superpowers-team: writing-plans override] -> Overlay live -> Production sweep`, with a standing edge from every node to `Stop and ask user` guarded by the VB-1 condition. Questions = diamonds, actions = boxes, per the Superpowers graphviz conventions. Task 15 only enriches the GSD detection detail and the exact fork-prompt strings; the writing-plans override itself is stated here so the skill never contradicts §5.1 step 6 between Task 9 and Task 15.

- [ ] **Step 4: Write the five-mode routing table and the adjacent-mode tiebreaker**

Paste the `design.md` §2 mode table from **VB-3** verbatim and the §5.1 tiebreaker from **VB-2** verbatim (do not re-transcribe either; they are pinned to prevent drift). Include the synchronised-swimmer framing from §2 and decompose-as-judgement (no sixth mode; the three decompose meanings), rendered faithfully from §2.

- [ ] **Step 5: Write the nine-tenet doctrine**

For each tenet 1 to 9, render a short doctrine block from the `design.md` §3 table: the tenet, the native shortfall it closes, and the enforcing mechanism, phrased as instruction to the agent, not as a re-teaching of native behaviour. Cross-reference the hooks by name (`take-a-beat`, `uncertainty`) and the anchor protocol (`docs/playbook/anchor-format.md` lives in the plugin; the runtime files are `.playbook/anchor.md` and `.playbook/uncertainty-ledger.md`). Keep each block to a few sentences (tenet 8). For tenet 4, instruct the agent to write the exact band slug from **VB-4** (so ledger entries match callout-shape detection, review finding M6 consistency); reference the §6 confidant gate, three callout shapes, and one-hour window via the anchor-format doc rather than duplicating them.

- [ ] **Step 6: Write the escalation ladder and the prerequisite forks**

Render the §8 ladder faithfully (1 self, 2 take-a-beat, 3 research, 4 fresh subagent, 5 ntfy notify-and-wait, 6 external manager gated by the ledger, 7 offline-only forced call logged to HTML) with the standing override from **VB-1** pasted verbatim above it. Add the §9 graceful-degradation rule and reuse the two exact fork-prompt strings defined in Task 15 Step 1/Step 2 verbatim (the Superpowers `/plugin marketplace add obra/superpowers` then `/plugin install superpowers` prompt; the GSD `npx get-shit-done-cc@latest` prompt). Never fail; prompt at the fork.

- [ ] **Step 7: Write the `## Red Flags` and `## Integration` sections**

Red Flags (Never/Always) capturing: never silently auto-pick the mode (the staffing sentence must be visible and vetoable); never route on size; never promote the overlay back to a separate skill (persistence is the hooks + anchor, per §3/§11); never ship scaffolding vocabulary (tenet 6). Integration lists the moved-in skills `playbook:modifying-plans` and `playbook:synchronised-subagent-development`, and the prerequisites `superpowers:brainstorming`/`superpowers:writing-plans` and GSD.

- [ ] **Step 8: Verify against the design checklist (manual, with concrete observable)**

Run: `npx --yes js-yaml skills/playbook/SKILL.md 2>/dev/null || python3 -c "import sys,yaml,io; d=open('skills/playbook/SKILL.md').read().split('---')[1]; yaml.safe_load(d); print('frontmatter OK')"`
Expected: `frontmatter OK` and the description contains no workflow summary.

Then run this checklist (fix inline; this is judgement, not automatable):
- Every `design.md` §5.1 step 1 to 7 appears in the flow, including the writing-plans override node.
- VB-1 (North-Star override) appears byte-for-byte: `grep -qF "stop and ask the user before proceeding, regardless of the uncertainty ledger or the mode" skills/playbook/SKILL.md`.
- VB-2 (tiebreaker) and VB-3 (mode table) appear byte-for-byte; routing is on separability/durability, not size.
- All nine tenets present, each phrased as adherence improvement (not native re-teaching).
- Tenet-4 doctrine instructs the agent to use the exact VB-4 slugs.
- British English; zero long-dash characters: `grep -nP '\x{2014}' skills/playbook/SKILL.md` returns nothing.

- [ ] **Step 9: Commit**

```bash
git add skills/playbook/SKILL.md
git commit -m "feat: add playbook engine skill (decision engine + nine-tenet doctrine)"
```

---

## Task 10: `playbook:hackathon-team` skill

**Files:**
- Create: `/Users/lucas/Developer/lujstn/playbook/skills/hackathon-team/SKILL.md`

Rendered from `design.md` §5.2. Substrate is native agent-teams (`TeamCreate`, `SendMessage`, `Agent(team_name=...)`) per the CCSP TeammateTool reference. House style as Task 9.

- [ ] **Step 1: Frontmatter + trigger**

```markdown
---
name: hackathon-team
description: Use when coupled work in one shared codebase needs peers that talk to each other directly with lightweight coordination, after the playbook engine has chosen hackathon-team.
---
```

- [ ] **Step 2: Write the choreography body** covering, from §5.2: co-located peers in one shared working directory; peers message each other by name; the lead is a thin coordinator (partition by file ownership, assign once, step back, peers self-organise and call each other out); the lead-authority constraint stated openly (native agent-teams requires a mandatory non-delegable lead with task-assignment authority, so it cannot be a pure comms-only lead, honouring tenet 3 as closely as the primitive allows); conflict avoidance by strict file-ownership partition (two teammates never own the same file, because native agent-teams does not isolate teammates in worktrees); no shared memory (coordination is the shared task list plus direct messages); lifecycle (teammates persist until shut down, run in background, notify lead on idle; `/resume` and `/rewind` do not restore in-process teammates); sizing default conservative (native guidance 3 to 5; user-tunable per §12). Include a `dot` graph and Red Flags. Must not re-explain the native team primitive mechanics beyond what closes the tenet-3 gap.

- [ ] **Step 3: Verify and commit**

Run: `grep -nP '\x{2014}' skills/hackathon-team/SKILL.md` (expected: no output) and the frontmatter YAML check from Task 9 Step 8.
Checklist: lead-authority limitation stated openly; file-ownership rule explicit; lifecycle caveat present; British English.

```bash
git add skills/hackathon-team/SKILL.md
git commit -m "feat: add hackathon-team skill (thin choreography over native agent-teams)"
```

---

## Task 11: `playbook:offline-mode` skill

**Files:**
- Create: `/Users/lucas/Developer/lujstn/playbook/skills/offline-mode/SKILL.md`
- Create: `/Users/lucas/Developer/lujstn/playbook/skills/offline-mode/decision-log.html.tmpl`

Rendered from `design.md` §5.3 and §8. Never enabled implicitly. Per-run interactive picker via `AskUserQuestion` (custom wait window default pre-filled 10 minutes, or disable waiting; never persisted, never inferred from a previous run). Decision log accumulates only while active. HTML export to a user-chosen folder. ntfy seam is a clean `notify()` interface; the example script is user-provided during build (§12 open item).

- [ ] **Step 1: Frontmatter + trigger**

```markdown
---
name: offline-mode
description: Use only when explicitly run to enable offline behaviour for one session, declaring the wait window fresh each time and producing a morning-readable HTML decision log.
---
```

- [ ] **Step 2: Write the body** covering: the explicit per-run declaration and the exact `AskUserQuestion` picker (option A custom wait window with default pre-filled at 10 minutes; option B disable waiting; state it is never remembered and must be declared every run); the decision-log event set verbatim from §5.3 (forced-without-you decisions after the window elapses, CTO-subagent consultations, waits, ntfy sends; online runs produce no log because absence means blocked and we wait); the HTML export to the user-chosen folder (project root or an external logs folder, chosen at runtime); the escalation-ladder position from §8 (ntfy notify-and-wait the declared window, then external manager gated by the ledger, then forced call logged); and the ntfy setup flow verbatim from §8 (user creates a topic via the ntfy URL, downloads the app, hands the topic to Claude, Claude saves it under `.claude`, the skill sends to that topic).

- [ ] **Step 3: Define the ntfy seam (interface, not a placeholder)**

The skill specifies a single integration point: a documented `notify "<message>"` contract (what it receives, when it is called) and the fact that the example implementation script is supplied by the user during build and saved under `.claude`. The skill text must contain the exact behaviour and the exact `.claude` topic-file location, so wiring the user's script later is a drop-in. This is a complete interface specification, not a TODO.

- [ ] **Step 4: Write `decision-log.html.tmpl`**: a clean, single-file, dependency-free HTML document (inline CSS, readable typography, a simple table of timestamp / event-type / detail, a header showing the North Star and the session date). Morning-readable per §5.3.

- [ ] **Step 5: Verify and commit**

Checklist: picker is per-run and explicitly never remembered; log is offline-only; HTML folder chosen at runtime; ntfy seam fully specified; British English; `grep -nP '\x{2014}'` empty.

```bash
git add skills/offline-mode/SKILL.md skills/offline-mode/decision-log.html.tmpl
git commit -m "feat: add offline-mode skill (per-run picker, decision log, HTML export)"
```

---

## Task 12: Re-point `playbook:modifying-plans`

**Files:**
- Modify: `/Users/lucas/Developer/lujstn/playbook/skills/modifying-plans/SKILL.md`
- Modify: `/Users/lucas/Developer/lujstn/playbook/skills/modifying-plans/prompts/transformer.md`

Selective namespace correction only; behaviour is inherited as-is per `design.md` §5.4. The exact occurrences below were verified by `grep -n` against the current files (Pass-2 review found the earlier list missed the literal hand-off line and used unsatisfiable bare-token verification; this version is positive-count only). Three rules: (a) FLIP refs to skills now owned by Playbook to `playbook:`; (b) KEEP Superpowers-prerequisite refs as `superpowers:`; (c) DO NOT touch bare tokens that are dot-graph node/edge labels or descriptive prose, because they are not skill invocations and prefixing them is noise that also breaks graph label-matching.

**FLIP to `playbook:synchronised-subagent-development`** (now owned here; exactly 5 in `SKILL.md` + 1 in `transformer.md`):
- `SKILL.md:3`: frontmatter `description`, bare "hand off to synchronised-subagent-development" → `playbook:synchronised-subagent-development` (CSO-load-bearing; must be explicit).
- `SKILL.md:111` `superpowers:synchronised-subagent-development` → `playbook:`
- `SKILL.md:123`: the LITERAL hand-off string `> "Mode = synchronised. Invoke skill \`synchronised-subagent-development\` with plan ..."`. This is behavioural: the receiving skill is now `playbook:synchronised-subagent-development`, so the literal must read ``playbook:synchronised-subagent-development`` for the hand-off to resolve once the skill is in the playbook package. The skill's own Red Flag ("Print the hand-off line literally; the next skill matches on it") makes this edit mandatory, not optional polish.
- `SKILL.md:181` `> For agentic workers: REQUIRED SUB-SKILL: superpowers:synchronised-subagent-development` → `playbook:`
- `SKILL.md:266` `superpowers:synchronised-subagent-development` → `playbook:`
- `prompts/transformer.md:222` `> For agentic workers: REQUIRED SUB-SKILL: superpowers:synchronised-subagent-development` → `playbook:`

**NAMESPACE-FIX bare `subagent-driven-development` → `superpowers:subagent-driven-development`** (the upstream serial fallback; making it explicit so it resolves post-move, symmetric with the synchronised flip):
- `SKILL.md:3`: description, bare "hand off to upstream subagent-driven-development". Line 3 therefore carries TWO edits: the synchronised flip above AND this namespace-fix.
- `SKILL.md:131`: the LITERAL hand-off string `> "Mode = serial. Invoke skill \`subagent-driven-development\` ..."` → ``superpowers:subagent-driven-development`` (behavioural, parallel to line 123; the serial path resolves to the upstream Superpowers skill).

**KEEP `superpowers:` unchanged** (prerequisites): `superpowers:writing-plans` at `SKILL.md:3,22,174,262`; `superpowers:subagent-driven-development` already-prefixed at `SKILL.md:24,61,127,269`; `superpowers:using-git-worktrees` at `SKILL.md:263`.

**LEAVE BARE, DO NOT EDIT** (dot-graph node/edge labels, since prefixing breaks graph label matching and is not a skill invocation): `SKILL.md:43,53` bare `synchronised-subagent-development` in `"Hand off to synchronised-subagent-development"`; `SKILL.md:44,49,52` bare `subagent-driven-development` in `"Hand off to upstream subagent-driven-development"`.

- [ ] **Step 1: Snapshot current refs (failing-state record)**

Run: `grep -nE 'superpowers:(synchronised-subagent-development|subagent-driven-development|writing-plans|using-git-worktrees)|Invoke skill .(synchronised|subagent)' skills/modifying-plans/SKILL.md skills/modifying-plans/prompts/transformer.md`
Expected now: `superpowers:synchronised…` at 111,181,266; the two literal hand-off lines 123/131 bare; zero `playbook:`.

- [ ] **Step 2: Apply the edits** via exact-string edits (never blanket-replace): the 5 `SKILL.md` synchronised flips (3, 111, 123, 181, 266) + transformer.md:222, and the 2 subagent-driven namespace-fixes (3, 131). On line 3, apply BOTH edits in that one description string. Do not touch lines 43/44/49/52/53 (graph labels) or any KEEP ref.

- [ ] **Step 3: Verify the split (positive counts only, never "no bare token", which is unsatisfiable because graph labels and prose legitimately stay bare)**

```bash
S=skills/modifying-plans/SKILL.md ; T=skills/modifying-plans/prompts/transformer.md
[ "$(grep -c 'superpowers:synchronised-subagent-development' "$S")" = 0 ] && echo "PASS: no superpowers:synchronised" || echo FAIL
[ "$(grep -c 'playbook:synchronised-subagent-development' "$S")" = 5 ] && echo "PASS: 5 playbook:synchronised in SKILL" || echo FAIL
[ "$(grep -c 'playbook:synchronised-subagent-development' "$T")" = 1 ] && echo "PASS: 1 in transformer" || echo FAIL
[ "$(grep -c 'superpowers:subagent-driven-development' "$S")" = 6 ] && echo "PASS: 6 superpowers:subagent-driven (24,61,127,269 + line3 + line131)" || echo FAIL
[ "$(grep -c 'superpowers:writing-plans' "$S")" = 4 ] && echo "PASS: writing-plans intact (4)" || echo FAIL
[ "$(grep -c 'superpowers:using-git-worktrees' "$S")" = 1 ] && echo "PASS: using-git-worktrees intact (1)" || echo FAIL
# Graph labels deliberately remain bare, assert they are STILL THERE (not accidentally prefixed):
[ "$(grep -c '"Hand off to synchronised-subagent-development"' "$S")" = 2 ] && echo "PASS: 2 synchronised graph labels left bare" || echo FAIL
[ "$(grep -c '"Hand off to upstream subagent-driven-development"' "$S")" = 3 ] && echo "PASS: 3 subagent graph labels left bare" || echo FAIL
# Long-dash gate scoped to ADDED lines only: modifying-plans is inherited as-is
# (design.md §5.4) and legitimately already contains em-dashes; the no-long-dash
# constraint governs only text WE introduce here.
git diff -- skills/modifying-plans/ | grep '^+' | grep -nP '\x{2014}' ; echo "expect: no output (no long dash in added/edited lines)"
```

- [ ] **Step 4: Commit**

```bash
git add skills/modifying-plans
git commit -m "refactor: re-point modifying-plans owned refs to playbook namespace"
```

---

## Task 13: Re-point and extend `playbook:synchronised-subagent-development`

**Files:**
- Modify: `/Users/lucas/Developer/lujstn/playbook/skills/synchronised-subagent-development/SKILL.md`
- Modify: `/Users/lucas/Developer/lujstn/playbook/skills/synchronised-subagent-development/prompts/spec-reviewer.md`
- Modify: `/Users/lucas/Developer/lujstn/playbook/skills/synchronised-subagent-development/prompts/code-quality-reviewer.md`

Two changes: (a) selective namespace re-point per `design.md` §5.5, applying the SAME three rules as Task 12 (FLIP owned, KEEP prerequisite, LEAVE-BARE graph/prose) for symmetry; (b) add the agreed conductor-whistle extension. Verified by `grep -n` against the current file (Pass-2 review found the earlier KEEP list wrongly claimed line 3, omitted line 270, and used an unsatisfiable bare-token gate).

**FLIP `superpowers:modifying-plans` → `playbook:modifying-plans`** (now owned here; exactly 6 sites): `SKILL.md:3` (frontmatter `description`, "produced by superpowers:modifying-plans", CSO-load-bearing), `SKILL.md:39`, `SKILL.md:45` (this line ALSO contains `superpowers:subagent-driven-development` which is KEPT, so edit ONLY the modifying-plans token), `SKILL.md:46`, `SKILL.md:268`, `SKILL.md:285`.

**NAMESPACE-FIX bare `subagent-driven-development` → `superpowers:subagent-driven-development`** on `SKILL.md:3` (the description ends "Falls back to upstream subagent-driven-development if the plan is not wave-grouped", bare). This is the exact symmetric fix Task 12 applies to its own line-3 description; doing it here keeps the two re-point tasks consistent and the CSO string unambiguous. Line 3 therefore carries TWO edits: the `modifying-plans` flip AND this namespace-fix.

**KEEP `superpowers:` unchanged** (prerequisites; do NOT touch): `superpowers:subagent-driven-development` already-prefixed at `SKILL.md:8,45,47,102,270,271,296` and `prompts/spec-reviewer.md:3` (NOTE: line 3 is NOT in this list, it is the bare token fixed above; line 270 IS, contrary to the earlier draft); `superpowers:using-git-worktrees` (`SKILL.md:106,127,286`); `superpowers:requesting-code-review` (`SKILL.md:190,290`, `prompts/code-quality-reviewer.md:5,9,20`); `superpowers:finishing-a-development-branch` (`SKILL.md:82,96,192,293`); `superpowers:test-driven-development` (`SKILL.md:289`); `superpowers:writing-plans` (`SKILL.md:269,284`).

**LEAVE BARE, DO NOT EDIT**: `SKILL.md:2` `name: synchronised-subagent-development` (the skill's own frontmatter name, since Superpowers skill names are unprefixed; the plugin applies the namespace); `SKILL.md:16` Announce line self-reference; dot-graph node/edge labels at `SKILL.md:24` (`"synchronised-subagent-development"`, `"subagent-driven-development (serial)"`), `25,31,32,33,35` (`"Run modifying-plans first"`, edges); descriptive prose bare `modifying-plans` at `SKILL.md:41,63,104,167,275,278`. None are skill invocations.

- [ ] **Step 1: Snapshot current refs (record exact counts to compare in Step 4)**

```bash
S=skills/synchronised-subagent-development/SKILL.md
grep -c 'superpowers:modifying-plans' "$S"            # expect 6 (pre-edit)
grep -c 'superpowers:subagent-driven-development' "$S" # expect 7 (pre-edit)
grep -nE 'superpowers:|playbook:' "$S"                 # full ref list
```

- [ ] **Step 2: Apply the edits** via exact-string edits: the 6 `superpowers:modifying-plans` → `playbook:modifying-plans` flips (on line 45 touch ONLY the modifying-plans token), and the line-3 bare `subagent-driven-development` → `superpowers:subagent-driven-development`. Line 3 carries both. Touch nothing in the LEAVE-BARE list.

- [ ] **Step 3: Add the conductor-whistle extension** (faithful behaviour from `design.md` §5.5)

Insert a section so an implementer that discovers a wave-breaking problem mid-wave (a wrong contract, a broken shared assumption) raises a flag to the conductor; the conductor may halt the wave, re-plan, or broadcast a corrected constraint to the still-running siblings before merge; there is no peer-to-peer messaging, the conductor is the only hub; this closes the blind spot where a wave-breaking discovery would otherwise surface only at post-wave merge after parallel work was wasted. Place it adjacent to the existing wave-execution / failure-handling sections. British English, no long dashes. Do not re-specify the skill's other inherited mechanics.

- [ ] **Step 4: Verify the split (positive counts only, never a "no bare token" gate; bare graph labels and prose legitimately remain)**

```bash
S=skills/synchronised-subagent-development/SKILL.md
[ "$(grep -c 'superpowers:modifying-plans' "$S")" = 0 ] && echo "PASS: no superpowers:modifying-plans" || echo FAIL
[ "$(grep -c 'playbook:modifying-plans' "$S")" = 6 ] && echo "PASS: 6 playbook:modifying-plans" || echo FAIL
[ "$(grep -c 'superpowers:subagent-driven-development' "$S")" = 8 ] && echo "PASS: 8 superpowers:subagent-driven (7 kept + line3 fixed)" || echo FAIL
[ "$(grep -c 'superpowers:using-git-worktrees' "$S")" = 3 ] && echo "PASS: using-git-worktrees intact (3)" || echo FAIL
[ "$(grep -c 'superpowers:finishing-a-development-branch' "$S")" = 4 ] && echo "PASS: finishing intact (4)" || echo FAIL
[ "$(grep -c 'superpowers:requesting-code-review' "$S")" = 2 ] && echo "PASS: requesting-code-review intact (2 in SKILL)" || echo FAIL
[ "$(grep -c 'superpowers:writing-plans' "$S")" = 2 ] && echo "PASS: writing-plans intact (2)" || echo FAIL
# Graph/prose deliberately bare, assert STILL bare (not accidentally prefixed):
grep -q '^name: synchronised-subagent-development$' "$S" && echo "PASS: frontmatter name unprefixed" || echo FAIL
[ "$(grep -c '"Run modifying-plans first"' "$S")" = 4 ] && echo "PASS: 4 'Run modifying-plans first' occurrences left bare (lines 25,32,33,34)" || echo FAIL
grep -qi 'conductor whistle\|wave-breaking' "$S" && echo "PASS: whistle added" || echo FAIL
# Long-dash gate scoped to ADDED lines only: the inherited skill legitimately
# contains em-dashes (design.md §5.5 "inherited as-is"; §12/Appendix-A note
# exempt inherited/canonical text). The constraint governs text WE introduce.
git diff -- skills/synchronised-subagent-development/ | grep '^+' | grep -nP '\x{2014}' ; echo "expect: no output (no long dash in added/edited lines, e.g. the conductor-whistle section)"
```

- [ ] **Step 5: Commit**

```bash
git add skills/synchronised-subagent-development
git commit -m "feat: re-point synchronised-subagent-development and add conductor whistle"
```

---

## Task 14: SessionStart bootstrap (overlay primacy + anchor re-injection)

**Depends on:** Task 3 (harness), Task 6 (anchor), Task 7 (take-a-beat post-compact behaviour).

**Files:**
- Create: `/Users/lucas/Developer/lujstn/playbook/hooks/session-start`
- Modify: `/Users/lucas/Developer/lujstn/playbook/hooks/hooks.json` (reconcile SessionStart routing)
- Test: `tests/hooks/test-session-start.sh`

Mechanism cloned from `/tmp/playbook-research/superpowers/hooks/session-start` (proven: read content, JSON-escape, emit via the platform-branching `playbook_emit_context` fixed in Task 3 for Claude Code, Cursor and Copilot). Per review finding M4, the injection is NOT a mere pointer to `playbook:playbook`: by `design.md` §3/§11 the persistence mechanism IS the injected hook text plus the anchor (a fresh GSD/Superpowers subagent context cannot re-trigger the skill, so a pointer would carry nothing). The hook therefore injects a **compact but self-contained nine-tenet digest** plus the anchor with primacy. It stays short (tenet 8) but complete enough to stand alone. Because Superpowers and Playbook both inject at `SessionStart` and ordering is not guaranteed, the digest asserts precedence explicitly and uses a distinct sentinel tag (m2) so it does not visually collide with Superpowers' `<EXTREMELY_IMPORTANT>` block.

- [ ] **Step 1: Write the failing pipe-test (asserts the digest is self-contained, not a pointer)**

Create `tests/hooks/test-session-start.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
H="$root/hooks/session-start"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
source "$root/hooks/lib/playbook-common.sh"

# No anchor yet: still injects the self-contained digest, valid JSON.
out="$(printf '{"cwd":"%s","hook_event_name":"SessionStart","source":"startup"}' "$tmp" | bash "$H")"
ctx="$(jq -r '.hookSpecificOutput.additionalContext // .additional_context // .additionalContext' <<<"$out")"
[ -n "$ctx" ] && echo "PASS: overlay injected" || { echo FAIL; exit 1; }
grep -q "PLAYBOOK_OVERLAY" <<<"$ctx" && echo "PASS: distinct sentinel tag (m2)" || { echo "FAIL: tag"; exit 1; }
# M4: digest is self-contained, all nine tenets enumerated, not a skill pointer.
n=$(grep -cE '^[1-9]\. ' <<<"$ctx"); [ "$n" -eq 9 ] && echo "PASS: all nine tenets present" || { echo "FAIL: only $n tenets"; exit 1; }
grep -q "stop and ask the user before proceeding, regardless of the uncertainty ledger or the mode" <<<"$ctx" \
  && echo "PASS: standing override verbatim (VB-1)" || { echo "FAIL: VB-1 missing"; exit 1; }

# Anchor present: re-injected with primacy.
playbook_anchor_init "ORIG-REQ-Z" "WHAT-MATTERS-Z" "$(printf '{"cwd":"%s"}' "$tmp")"
out="$(printf '{"cwd":"%s","hook_event_name":"SessionStart","source":"compact"}' "$tmp" | bash "$H")"
grep -q "ORIG-REQ-Z" <<<"$out" && echo "PASS: anchor re-injected after compact" || { echo FAIL; exit 1; }
jq -e . <<<"$out" >/dev/null && echo "PASS: valid JSON" || { echo "FAIL invalid JSON"; exit 1; }
```

Run: `bash tests/hooks/test-session-start.sh`
Expected: FAIL (script absent).

- [ ] **Step 2: Write `hooks/session-start`**

The digest is rendered faithfully from `design.md` §3 + Appendix A (one line per tenet, instruction phrasing, not native re-teaching) and embeds VB-1 verbatim. British English, no long dashes. Keep each tenet line to one sentence (tenet 8).

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/playbook-common.sh"
stdin="$(cat 2>/dev/null || true)"
anchor="$(playbook_anchor_read "$stdin")"

overlay="<PLAYBOOK_OVERLAY>
Playbook is active. This overlay plus the .playbook/anchor.md file is the persistence mechanism, not skill text; it stays in force across subagents and compaction and takes precedence over default behaviour where they conflict, though explicit user instructions still win. For any non-trivial work the playbook:playbook engine makes one visible, vetoable staffing call before planning or coding.

The nine tenets, always live:
1. Remember what matters: keep the anchor's North Star load-bearing at every decision and restate it at checkpoints.
2. Ask questions once, upfront and batched; there are no stupid questions; do not drip-feed, though stopping to ask later is allowed.
3. Treat the team as equals: a lead or conductor holds coordination authority only, not intellectual authority; subagents push back with technical reasoning; peer sanity-check is the routine cheap path before escalating.
4. Uncertainty: append to the unease ledger only through the confidant gate; escalate the ladder on a single top-band entry, a rising staircase, or a same-theme cluster within about an hour of active development.
5. Offline behaviour is enabled only by playbook:offline-mode, explicitly and per run.
6. Production-ready: no scaffolding vocabulary (plan, wave, mission) or comment sludge in shipped code; sweep before handing work back.
7. Take a beat at about 65% context used: pause, re-read the anchor and lessons, continue with a fresh head; compaction is a steered breath, not a wipe.
8. Less is more: pick the cheapest sufficient mode; short questions, plans and comments; longer thinking and shorter output; give subagents freedom.
9. Speed via more hands, not rushing: fan separable work across agents at the same completeness bar; partial work to save time is forbidden; never rush unless the user says to rush.

Standing override, above everything: if an uncertainty or decision could degrade the North Star such that the work would no longer meet it, stop and ask the user before proceeding, regardless of the uncertainty ledger or the mode.
</PLAYBOOK_OVERLAY>"

if [ -n "$anchor" ]; then
  body="${overlay}

Playbook anchor (restored first, before any orchestration scaffolding):

${anchor}"
else
  body="$overlay"
fi

playbook_emit_context "SessionStart" "$body"
exit 0
```

- [ ] **Step 3: Reconcile `hooks.json` compaction routing (do NOT delete PostCompact)**

Per review finding C2, keep all the compaction paths; they are idempotent and belt-and-braces:
- `PreCompact` (Task 7) owns the lessons-preserving compaction steer (runs before the summary).
- `PostCompact` (Task 7) is the primary post-compaction anchor restore (the documented "after compaction, receives summary" event).
- `SessionStart` matcher `startup|clear|compact` runs `session-start` (this task): the self-contained digest on every start, plus the anchor restore when source is `compact` as a fallback if the harness re-runs SessionStart instead of firing PostCompact.

Do not remove the `PostCompact` path. Record the empirically-confirmed load-bearing post-compaction event (from Task 7 Step 3a) in `docs/playbook/decisions/2026-05-16-compaction-wiring.md`, but retain both paths regardless because double-restoring identical anchor text is harmless and the cost of missing the restore is the single worst tenet-1/tenet-7 failure.

- [ ] **Step 4: Make executable, run test, lint, full hook suite**

```bash
chmod +x hooks/session-start
bash -n hooks/session-start
bash tests/hooks/test-session-start.sh
for t in tests/hooks/test-*.sh; do bash "$t"; done
```
Expected: all `PASS:`; no `bash -n` output.

- [ ] **Step 5: Commit**

```bash
git add hooks/session-start hooks/hooks.json tests/hooks/test-session-start.sh docs/playbook/decisions/2026-05-16-compaction-wiring.md
git commit -m "feat: add SessionStart bootstrap (overlay primacy + anchor re-injection)"
```

---

## Task 15: gsd-team and superpowers-team route integration in the engine

**Depends on:** Task 9 (engine skill exists).

**Files:**
- Modify: `/Users/lucas/Developer/lujstn/playbook/skills/playbook/SKILL.md`

Encodes the detect-and-handoff contract from the GSD research and `design.md` §2/§7/§9. GSD is **not** a plugin: it is a global npm install owning `.planning/`. Playbook only detects and hands off; it never writes `.planning/`.

- [ ] **Step 1: Add the `gsd-team` route block** to the engine skill, stating exactly (corrected per review finding M7, since GSD is a global npm tool, not a discoverable plugin):
- **What GSD is**: a global npm package installed by `npx get-shit-done-cc@latest`, NOT a Claude Code plugin. A global Claude install converts its commands into `~/.claude/skills/gsd-*/SKILL.md`; a local install exposes them as `/gsd-*` slash commands. Either way the user-facing entry points are the `/gsd-*` commands.
- **Detect availability** (reliable signals, in order): `get-shit-done-cc` or `gsd-sdk` resolvable on `PATH`; or `~/.claude/get-shit-done/` exists; or `~/.claude/commands/gsd/` / `gsd-*` skills present. Do not rely on "gsd-* skills" alone (absent on local installs).
- **Detect a GSD project**: `.planning/` at the project root (optionally read `.planning/STATE.md` YAML frontmatter, `milestone`, `active_phase`, `next_action`, for position).
- **Route** (invoke the `/gsd-*` entry point; Claude Code resolves it whether GSD is installed as skills or slash commands; do NOT assert "the Skill tool exactly as ns-* routers", which only holds for global skill installs): no `.planning/` + a spec/PRD exists → `/gsd-new-project --auto @<spec>`; no `.planning/` + no spec → `/gsd-new-project` (brownfield: `/gsd-map-codebase` first); `.planning/` exists → `/gsd-progress --next` (self-routing, safe to call blindly, degrades gracefully to the bootstrap path).
- **If GSD is absent**, do not fail; emit this exact fork prompt (m1): `> gsd-team needs GSD, which is a separate tool. Install it with: npx get-shit-done-cc@latest. Then re-run, or pick a different mode.`
- **Hard rule**: Playbook never writes into `.planning/`; it is GSD-owned durable state, read-only for routing.

- [ ] **Step 2: Add the `superpowers-team` route block with the writing-plans override** (verbatim behaviour from `design.md` §7)

State the chain `superpowers:brainstorming` then `superpowers:writing-plans` then `playbook:modifying-plans` then `playbook:synchronised-subagent-development`, and that the engine explicitly does **not** follow `writing-plans`' built-in next-step pointer to `superpowers:subagent-driven-development` (the pointer lives in two literal strings in the upstream `writing-plans` skill: the plan-document header `> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development …` and the `## Execution Handoff` section's "Subagent-Driven (recommended)" option). The override is orchestration-level (we do not fork Superpowers); the engine drives the chain and the SessionStart overlay asserts precedence. If Superpowers is absent, emit this exact fork prompt (m1): `> superpowers-team needs the Superpowers plugin. Install it: /plugin marketplace add obra/superpowers then /plugin install superpowers. Then re-run, or pick a different mode.`

- [ ] **Step 3: Verify and commit**

Checklist: never-write-`.planning/` rule present; GSD described as a global npm tool (not a plugin); detection uses PATH/dir signals not "skills only"; routes invoke `/gsd-*` (not "Skill tool as ns-*"); the three GSD routes present with exact commands; both fork-prompt strings present verbatim; the writing-plans override names both upstream pointer sites and states the chain; British English; `grep -nP '\x{2014}' skills/playbook/SKILL.md` empty.

```bash
git add skills/playbook/SKILL.md
git commit -m "feat: wire gsd-team detect-and-handoff and superpowers-team override into engine"
```

---

## Task 16: Test harness, skill-triggering, aggregate runner

**Depends on:** Tasks 9 to 15 (skills + hooks exist).

**Files:**
- Create: `/Users/lucas/Developer/lujstn/playbook/tests/skill-triggering/run-test.sh`
- Create: `/Users/lucas/Developer/lujstn/playbook/tests/skill-triggering/prompts/non-trivial-work.txt`
- Create: `/Users/lucas/Developer/lujstn/playbook/tests/skill-triggering/prompts/explicit-playbook.txt`
- Create: `/Users/lucas/Developer/lujstn/playbook/tests/run-all.sh`

`run-test.sh` clones the Superpowers pattern (`/tmp/playbook-research/superpowers/tests/skill-triggering/run-test.sh`): `claude -p "$PROMPT" --plugin-dir "$ROOT" --dangerously-skip-permissions --max-turns N --output-format stream-json`, then grep the stream-json for the invoked skill id.

- [ ] **Step 1: Write `run-test.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
skill="$1"; prompt_file="$2"; max="${3:-6}"
prompt="$(cat "$root/tests/skill-triggering/prompts/$prompt_file")"
out="$(claude -p "$prompt" --plugin-dir "$root" --dangerously-skip-permissions \
  --max-turns "$max" --output-format stream-json 2>/dev/null || true)"
if grep -qE "\"(skill|name)\":\"(playbook:)?${skill}\"" <<<"$out"; then
  echo "PASS: '$prompt_file' triggered $skill"
else
  echo "FAIL: '$prompt_file' did not trigger $skill"; exit 1
fi
```

- [ ] **Step 2: Write the prompt fixtures**

`non-trivial-work.txt`: a realistic multi-part feature request that names no skill (must auto-trigger `playbook` via the engine trigger). `explicit-playbook.txt`: `/playbook help me ship a small fix` (explicit invocation).

- [ ] **Step 3: Write `tests/run-all.sh`** (aggregator)

```bash
#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")" && pwd)"
fail=0
echo "== bash -n lint ==";   for f in "$root"/../hooks/session-start "$root"/../hooks/take-a-beat "$root"/../hooks/uncertainty "$root"/../hooks/lib/playbook-common.sh; do bash -n "$f" && echo "ok $f" || fail=1; done
echo "== manifests ==";      bash "$root/manifests.sh" || fail=1
echo "== hooks ==";          for t in "$root"/hooks/test-*.sh; do bash "$t" || fail=1; done
echo "== long-dash sweep =="; if grep -rnP '\x{2014}' "$root/../skills" "$root/../hooks" 2>/dev/null; then echo "FAIL: long dash found"; fail=1; else echo "ok: no long dashes"; fi
echo "== skill triggering (network/CLI; may be skipped in CI) =="; bash "$root/skill-triggering/run-test.sh" playbook non-trivial-work.txt || echo "WARN: skill-trigger needs claude CLI + auth"
exit $fail
```

- [ ] **Step 4: Run the suite**

```bash
chmod +x tests/skill-triggering/run-test.sh tests/run-all.sh
bash tests/run-all.sh
```
Expected: lint `ok`, manifests PASS, hook pipe-tests PASS, long-dash sweep `ok`. The skill-trigger line PASSES if the `claude` CLI is authenticated; otherwise it prints the WARN (documented limitation, behavioural trigger cannot be asserted offline).

- [ ] **Step 5: Commit**

```bash
git add tests/skill-triggering tests/run-all.sh
git commit -m "test: add skill-trigger harness and aggregate runner"
```

---

## Task 17: README, dogfood docs, final review and production-ready sweep

**Files:**
- Create: `/Users/lucas/Developer/lujstn/playbook/README.md`
- Create: `/Users/lucas/Developer/lujstn/playbook/docs/playbook/README.md`

- [ ] **Step 1: Write `README.md`** covering: one-paragraph purpose (`design.md` §1); install (marketplace add + `/plugin install playbook`); the five modes table; the nine tenets one-line each; the two hooks; prerequisites and graceful degradation (§9: common path is zero-dependency; Superpowers needed only for `superpowers-team`, GSD only for `gsd-team`, prompted at the fork). Include an explicit "Runtime state" subsection: Playbook writes `.playbook/anchor.md` and `.playbook/uncertainty-ledger.md` into the working project; recommend the user add `.playbook/` to that project's `.gitignore`, and note the engine offers to add it once via AskUserQuestion on first use (this is where the M8-removed per-hook mutation responsibility now lives: documentation + one-time engine offer, never a per-turn hook side-effect). British English, no long dashes.

- [ ] **Step 2: Write `docs/playbook/README.md`**: one short page: dogfood specs/plans live under `docs/playbook/`; decisions under `docs/playbook/decisions/`; the anchor format reference is `docs/playbook/anchor-format.md`.

- [ ] **Step 3: Production-ready sweep (tenet 6) across all shipped text**

Run:
```bash
grep -rnP '\x{2014}' skills/ hooks/ README.md docs/playbook/ 2>/dev/null ; echo "expect: empty (no long dashes)"
grep -rniE '\b(wave|mission|phase) [0-9]|per the plan|TODO|TBD|FIXME' skills/playbook skills/hackathon-team skills/offline-mode hooks/ README.md ; echo "expect: empty in engine/new skills/hooks"
```
Note: `skills/synchronised-subagent-development` and `skills/modifying-plans` legitimately use "wave" as domain vocabulary (that is their subject), so exclude them from the scaffolding-vocabulary sweep but still confirm no `TODO/TBD`. Fix any hit inline.

- [ ] **Step 4: Final spec-coverage review against `design.md`**

Walk `design.md` §1 to §12 and Appendix A; for each section name the task(s) that deliver it (see the Self-Review table below). Fix any gap inline by amending the relevant skill/hook.

- [ ] **Step 5: Full suite + commit**

```bash
bash tests/run-all.sh
git add README.md docs/playbook/README.md
git commit -m "docs: add README and dogfood docs; final production-ready sweep"
```

---

## Self-Review (run after the plan, before execution)

**1. Spec coverage**: every `design.md` section maps to a task:

| design.md | Delivered by |
|---|---|
| §1 Purpose; two principles | Task 9 (Overview/Core principle), README (Task 17) |
| §2 Five modes; synchronised-swimmer; decompose-as-judgement | Task 9 (routing table), Task 15 (gsd/superpowers routes) |
| §3 Nine tenets + enforcing mechanism | Task 9 (doctrine), Tasks 7 and 8 (hooks 7 and 4), Task 14 (self-contained nine-tenet digest = the §3/§11 persistence carrier, M4) |
| §4 Component inventory (5 skills, 2 hooks) | Tasks 9,10,11,12,13 (skills); Tasks 7,8,14 (hooks); Task 2 (packaging) |
| §5.1 Engine flow + tiebreaker + standing override | Task 9 (pastes VB-1, VB-2, VB-3 verbatim) |
| §5.2 hackathon-team | Task 10 |
| §5.3 offline-mode | Task 11 |
| §5.4 modifying-plans (inherited + re-point) | Task 12 (verified line list, M1) |
| §5.5 synchronised-subagent-development (+ conductor whistle) | Task 13 (verified 6-site list, M2) |
| §6 Anchor file + uncertainty ledger | Task 6 (protocol; VB-4 slug mapping, m6 timestamp note), Task 9 (doctrine writes VB-4 slugs) |
| §7 writing-plans override | Task 9 Step 3 (stated in engine skill so it never contradicts §5.1 step 6), Task 15 Step 2 (enriched, exact fork string) |
| §8 Escalation ladder + ntfy | Task 9 Step 6: standing North-Star override (VB-1) pasted ABOVE the ladder, then the 7-rung ladder; Task 11 (ntfy seam + setup flow) |
| Verbatim invariants (drift guard) | VB-1 North-Star override; VB-2 tiebreaker; VB-3 mode table; VB-4 band slugs, pinned once, pasted by Tasks 6, 9, 14 |
| §9 Prerequisites + graceful degradation | Task 9 Step 6, Task 15, README |
| §10 End-to-end flow | Task 9 (flow), Task 16 (behavioural trigger test) |
| §11 Rejected options | Honoured as constraints (no third runtime, overlay never a skill), Task 9 Red Flags |
| §12 Build constraints + open items | Binding-constraints section; Tasks 4,5 (spikes), Task 11 (ntfy open item), Task 6 (paths open item) |
| Appendix A canonical | Binding constraint 4; verbatim renders in Tasks 9,11 |
| Packaging blueprint (Superpowers) | Tasks 2,3,14 |
| GSD detect-and-handoff | Task 15 |
| De-gitlink hazard (found in grounding) | Task 1 |

No gaps.

**2. Placeholder scan**: the open items (`ntfy` script, anchor paths, agent-teams size cap, ~65% signal, Stop channel) are not placeholders: each is a concrete spike/decision/interface task (Tasks 4, 5, 6, 11) with explicit investigation steps, a decision doc, and a drop-in seam, exactly as `design.md` §12 mandates ("settled during build"). The spikes are hardened: Task 4 records the exact used = 100 - remaining arithmetic with an inversion regression test; Task 5 must prove the Stop channel both model-visible AND turn-terminating (no infinite-continuation); Task 8 is blocked on Task 5's decision doc and asserts the decided channel shape, never a hardcoded assumption. The single `<JQ EXPR FROM DECISION DOC>` token in Task 8 is a decision-driven fill (resolved by Task 5), not an unresolved plan placeholder. No `TBD`/`implement later` remain.

**3. Type/name consistency**: names are stable across tasks: `playbook_context_percent`, `playbook_anchor_init`, `playbook_ledger_append`, `playbook_anchor_read`, `playbook_emit_context`, `playbook_emit_stop_nudge`, `playbook_ensure_dir` (defined Task 3/4/6/8, used Tasks 7,8,14); `playbook_emit_context` is the single platform-branching emitter (Cursor/Claude/Copilot, C3) used by all three hooks. Hook scripts `session-start`/`take-a-beat`/`uncertainty` (defined Tasks 7,8,14, wired in `hooks.json`, lint-aggregated Task 16). Skill ids `playbook:playbook|hackathon-team|offline-mode|modifying-plans|synchronised-subagent-development` consistent with `design.md` §4 and the verified re-point line lists in Tasks 12 and 13. Runtime paths `.playbook/anchor.md` and `.playbook/uncertainty-ledger.md` consistent Tasks 6,7,8,14. Fixture names `ctx-used-70.json`/`ctx-used-40.json`/`ctx-remaining-35.json` consistent Tasks 4,7.

**Execution dependency note for the executor:** Tasks 1→2→3 are strictly ordered (foundation). Tasks 4 and 5 are independent spikes (parallel-safe); each produces a decision doc under `docs/playbook/decisions/`. Task 6 depends on 3. Task 7 needs 4 and 6 and includes spike Step 3a (which post-compaction event fires). Task 8 is hard-blocked on Task 5's decision doc. Task 9 needs 6 and pastes VB-1/2/3. Tasks 10, 11 are independent of 7 to 9. Tasks 12, 13 are independent of everything after Task 1. Task 14 needs 3,6,7 and keeps BOTH PostCompact and SessionStart/compact restore paths (C2: never delete PostCompact). Task 15 needs 9. Task 16 needs 9 to 15. Task 17 last.

**Review pass note:** This plan has been through one adversarial fidelity-review pass against `design.md` and the transcript; 3 critical, 8 major and 7 minor findings were applied (C1 Stop-channel spike dependency; C2 PostCompact path; C3 platform-branch emitter; M1/M2 verified re-point lists; M3 used-vs-remaining inversion; M4 self-contained overlay digest; M5 pinned verbatim blocks; M6 slug mapping; M7 GSD-is-a-tool-not-a-plugin; M8 no .gitignore mutation; m1 to m7).
