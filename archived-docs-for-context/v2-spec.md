# Playbook v2 — Consolidated Spec

The build contract for the in-place evolution to v2. Authored from the research
sweep (compaction, orchestration, GSD, notifications) and the codebase
inventory. This file is a working design artifact, not shipped plugin content.

---

## 0. Identity and principles

Playbook v2 is an **invisible-but-visible native steering layer** for Claude
Code. It is not a front door, not a wizard, and not a separate methodology you
opt into. It activates on every session and steers Claude's own behaviour with
the user's additions layered on top of native Claude Code, Superpowers, and GSD.

Standing principles, unchanged from v1 where they still hold:

- **Supports, never forces.** No new questions are required to make Playbook
  work. The user never picks a mode from a menu. Playbook routes internally and
  *shows* its choice; it does not gate the user behind a decision.
- **Native feel.** Everything is expressed in Claude Code's own vocabulary
  (subagents, agent teams, workflows, GSD), not a parallel set of concepts.
- **Visible.** Playbook always announces what it is doing with a branded marker
  (section 1). The user must be able to see it working, and notice instantly if
  it ever vanishes.
- **Zero-dependency common path.** `lone-wolf`, `interns`, `hackathon`,
  `workflows`, and all tenets need only native Claude Code. Only `gsd` mode
  needs a prerequisite, prompted at the fork, never a hard failure.
- **Hook-carried state, no working-tree files.** The North Star, model rule,
  and context calm ride in the conversation, steered by hooks (`SessionStart`,
  `SubagentStart`, `PreCompact`, `SessionStart source=compact`, `PostToolUse`).
  The one exception is opt-in offline mode's gitignored config and its log.

---

## 1. Visibility system

Every routing and every mode entry prints a single branded line that is both
the nudge and the "Playbook is alive" heartbeat:

```
🐺 Playbook · lone-wolf — single coherent change, no extra hands needed
```

Format: `<emoji> Playbook · <mode> — <≤60-char reason>`. The `Playbook ·` brand
is mandatory on every line so that, layered on Superpowers or GSD, it is
unmistakably Playbook talking, and its disappearance is obvious.

Markers:

| Emoji | Mode / state |
|---|---|
| 🐺 | `lone-wolf` |
| 🐜 | `interns` (parallel subagents) |
| 🤝 | `hackathon` (agent teams, peers talk) |
| ⚙️ | `workflows` (ultracode-driven) |
| 🏗️ | `gsd` (whole MVP, unknown area) |
| 🦞 | `fix` |
| 👾 | `debug` |
| 📚 | `offline` / notify |
| 🪙 | model downshift announced on a spawn (e.g. "executing on Sonnet") |
| 🧭 | brainstorming (explore + sharp questions) |

`/pb` (status) prints a heartbeat: active yes/no, current mode, current model
split, whether offline mode is on, and whether Playbook owns the context-calm
channel this session.

---

## 2. Command surface (dual names)

Plugin stays `playbook/playbook`. Every explicit entry point ships under two
command names: a branded `/pb-*` (canonical, collision-proof on top of
Superpowers/GSD) and a bare natural alias for newcomers. Both route into the
same skill.

| Branded | Natural | Skill | Notes |
|---|---|---|---|
| `/pb-brainstorming` | `/brainstorming` | `playbook:brainstorming` | bare may collide with Superpowers; `/pb-` canonical |
| `/pb-offline-mode` | `/offline-mode` | `playbook:offline-mode` | |
| `/pb-worktrees` | `/worktrees` | `playbook:worktrees` | new |
| `/pb-fix` | `/fix` | `playbook:fix-mode` | replaces `[fix]` token |
| `/pb-debug` | `/debug` | `playbook:debug-mode` | replaces `[debug]` token |
| `/pb` | — | status/heartbeat | no bare alias |

Implementation: a `commands/` directory with one `.md` per name. The bare
aliases defer gracefully when another installed tool already owns the name
(documented behaviour: prefer the `/pb-` form). Auto-trigger skills (engine,
brainstorming, the model rule, the overlay) still fire without a slash.

---

## 3. The routing engine (`playbook:playbook`)

The engine restates the North Star, routes internally on **separability and
durability**, prints the branded marker, and keeps the tenet overlay live. It
no longer asks routing questions or makes a visible vetoable "staffing call" as
a gate. It announces, it does not interrogate.

Modes (CC primitive in parentheses):

- **`lone-wolf`** (main thread) — one coherent unit, no benefit from hands.
- **`interns`** (parallel subagents) — several independent sub-tasks; helpers do
  not talk to each other; star topology; includes the named **joint-leads →
  workers** nested fan-out (e.g. 5 leads × 5 workers = 25 at depth 2, inside the
  hard depth-5 cap).
- **`hackathon`** (agent teams) — coupled work in one shared codebase; peers
  message each other; thin coordinating lead.
- **`workflows`** (ultracode dynamic workflows) — the default for substantive
  separable work; the script holds the loop, results stay out of main context.
- **`gsd`** (GSD) — only for "whole MVP in an unknown area"; durable
  cross-session state; driven the front-loaded + parallel way (section 9).

Routing rules:

- Separability decides interns vs hackathon vs workflows. Durability decides
  workflows vs gsd. Size only triggers decompose-as-judgement (recognise too
  big, propose the cut, recurse), never which mode runs the work.
- **The ultracode nudge (S4):** if substantive separable work is detected and
  `/effort ultracode` is not set, Playbook surfaces one non-blocking line
  ("not in ultracode; want me to set it before planning?"). It never gates.
- **Decompose-as-judgement** stays in the engine. The v1 `modifying-plans` and
  `synchronised-subagent-development` decompose paths are dropped; their wave
  wisdom moves into the workflows-mode guidance (section 3a).

Relaxed rule: the v1 hard rule "Playbook never writes into `.planning/`" becomes
"Playbook writes into `.planning/` only via the declared GSD pre-seed and
post-process touches in section 9," everything else read-only.

### 3a. workflows-mode guidance (distilled wave wisdom)

When routing to workflows, Playbook carries the durable lessons from the dropped
synchronised-development skill, expressed as guidance for the workflow author:
extract shared contracts/types first (a serial Wave 0 equivalent), keep parallel
stages file-disjoint, verify the merged state per stage, and never reduce
parallelism on a hunch once disjointness is established. This is doctrine in the
engine, not a separate skill.

---

## 4. The nine tenets v2

Kept at nine for identity. Changes flagged.

1. **Remember what matters.** Original request verbatim + the one-line North
   Star, load-bearing at every decision, re-anchored after compaction. **New:**
   the North Star travels into workflow `agent()` stages and nested subagents
   (via the `SubagentStart` overlay and a `playbook-northstar:` dispatch line),
   not only native `Agent` dispatch.
2. **Front-load the questions.** Brainstorm to explore (section 7); ask the
   batch once, early, so downstream runs unattended. **New:** this is also the
   GSD front-load (ask early, write the stage file, skip GSD's interactive pass).
3. **Team of equals.** Coordination authority, not intellectual authority.
   **New:** applies to subagents, workflow stages, agent-team peers, and nested
   joint-leads; the one forced exception remains the agent-teams lead.
4. **Unease.** **Slimmed:** an in-session sense restated only on increase, not a
   per-tool-use pulse that competes with the calm-compaction voice. Standing
   North-Star override unchanged (stop and ask if a decision would drop the work
   below meeting the North Star).
5. **Offline mode.** **Expanded:** Pushover or ntfy, `info/action/critical`,
   agent-chosen priority, the `/goal` division of labour (section 10).
6. **Ready for production.** No scaffolding vocabulary (plan, wave, mission) or
   comment sludge in shipped code; final sweep before handing back. Unchanged.
7. **Ride the compaction, don't fear it.** **Reworked take-a-beat (note 2,
   section 5):** auto-compact is seamless and the session continues; agents must
   not wrap up early, do less, break offline mode, or stop because context is
   tight. Re-anchor and resume after compaction; never panic before it.
8. **Less is more.** Cheapest sufficient mode, short output, long thinking.
   **Houses the model rule (section 6):** Sonnet executes, Opus plans/reviews,
   bump up when stuck.
9. **Speed via more hands, not rushing.** Fan separable work across
   subagents/workflows at the same completeness bar; nudge ultracode; partial
   work to save time is forbidden; rush only if told to.

---

## 5. The compaction system (note 2 — keystone)

### 5.1 The problem, established first-hand

- **Native auto-compact** (~77-80% used, override `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`
  1-100) is *seamless*: it compacts and the session continues. The "Context left
  until auto-compact" line is a UI progress bar. The platform never stops the
  agent.
- **`gsd-context-monitor.js`** (installed by GSD into the user's own
  `~/.claude/settings.json`, `PostToolUse` on Bash|Edit|Write|MultiEdit|Agent|Task)
  injects into the **model's** context: at used ≥65% "CONTEXT WARNING … avoid
  starting new complex work … prepare to pause"; at ≥75% "CONTEXT CRITICAL …
  nearly exhausted … ask the user how to proceed." This is the fear that makes
  agents do less and stop. Off-switch: `hooks.context_warnings:false` in a GSD
  project's `.planning/config.json` only.
- Playbook v1's own `take-a-beat` *also* fires at 65%, compounding the noise.

### 5.2 Mechanics confirmed

- `PreCompact` exists (matcher manual|auto, input `compaction_trigger`); it can
  block but does **not** reliably shape the summary content. Use for logging,
  not for steering the summary.
- `SessionStart` with `source=compact` is the **dependable re-anchor seam**: it
  injects `additionalContext` the model reads and re-runs on resume.
- There is **no supported way for an agent to self-trigger `/compact`** mid-task.
  "Self-compaction + auto-restart" is therefore achieved by native auto-compact
  (which already rides through) plus a strong `SessionStart(compact)` re-anchor
  that explicitly resumes the in-flight work, not by a programmatic compact call.

### 5.3 The fix (decision: detect + disable/replace, one-time consent)

A single Playbook routine, "own the context-calm channel":

1. **Detect** other context-anxiety sources on `SessionStart`: scan
   `~/.claude/settings.json` (and project `.claude/settings.json`) for
   `gsd-context-monitor.js` or any `PostToolUse` hook injecting low-context
   warnings.
2. **Offer once** (consent, persisted so it is not re-asked every session, with
   a timestamped backup of any edited file):
   - GSD projects: set `hooks.context_warnings:false` in `.planning/config.json`.
   - Globally: comment out / remove the `gsd-context-monitor.js` registration in
     `settings.json` (backup first). Optionally set
     `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` if the user wants a later auto-compact.
   - Persisted opt-in marker: `.claude/playbook/context-calm` (gitignored) or a
     global equivalent, so the consent is remembered.
3. **Replace** with Playbook as the single calm voice:
   - `take-a-beat` no longer emits a work-reducing message at 65%.
   - Near real auto-compact only, it emits a calm line: "context is tight; auto-
     compact is seamless and you will keep what matters via the re-anchor; keep
     going, do not wrap up early."
   - `SessionStart(source=compact)` re-injects the original request + North Star
     + lessons with primacy and an explicit "resume the in-flight work: <next>".
   - The overlay tells every agent (and subagent via `SubagentStart`) not to
     fear context, not to break offline mode, not to do less near the limit.
4. **All-in-one:** detect → neutralise (with consent) → emit Playbook's own
   calm message. This is exactly the user's preferred shape.

Editing `~/.claude/settings.json` is a hard-to-reverse change to the user's own
machine config: only with explicit consent, always with a backup, never silent.

### 5.4 Threshold change

Drop the 65% scare. Playbook's calm beat aligns near the real auto-compact
threshold (configurable). The `playbook-window` self-declaration stays as the
percent source but the self-healing notice becomes calmer and is not framed as a
failure.

---

## 6. The model rule (F4, always-on)

Replaces `reduce-cost-mode`. Always on, no `[budget]` token.

- **Sonnet executes. Opus plans, reviews, and thinks hard. Bump up when stuck.**
- Risk-profile classification (kept from v1's reduce-cost logic): mechanical/
  bounded/cheaply-verifiable → lightweight; bulk implementation under a locked
  spec with a reviewer above → Sonnet; judgment/validation/contract-authorship/
  sign-off → Opus. Classify by what happens when the agent is wrong (loud+local
  = downgrade; quiet+propagating = keep flagship).
- **Propagation across all nesting levels:** model resolution order is env var >
  per-spawn param > frontmatter > main. Enforce via (a) the `SubagentStart`
  overlay carrying the rule into every level, (b) `model:` on each dispatch /
  workflow `agent()` stage, (c) shipped subagent definitions with locked models
  where Playbook owns them. For GSD, use `model_overrides` (section 9).
- **Visible:** announce the tier on each spawn that downshifts, e.g.
  `🪙 executing on Sonnet — bulk implementation under locked spec`.

---

## 7. Brainstorming-native (S1)

The Superpowers brainstorming *style* without Superpowers and without a forced
design doc. Trigger: **auto for fuzzy/open-ended ideation, and on
`/brainstorming` / `/pb-brainstorming`.** Behaviour: explore options, surface
trade-offs, ask genuinely sharp questions (batched, not drip-fed), paint the
picture, converge. Marker: `🧭 Playbook · brainstorming`. It produces a shared
understanding in-conversation; it does not write a design-doc artifact unless
asked. Hands off cleanly into the routed mode once the shape is clear.

---

## 8. Worktrees-for-sessions (S2)

For genuinely separate work launched as distinct Claude Code sessions (not
subagents). Skill `playbook:worktrees`, commands `/worktrees` + `/pb-worktrees`.

- Create worktrees under `.worktrees/` in the project, each on a dedicated
  branch.
- Assign each active worktree an **instance number** so parallel worktrees can
  stand up isolated resources without collision: e.g. a per-instance Docker DB
  (port/volume/name offset by instance number). Generalise: the same pattern for
  whatever isolated resource the stack needs (DB, dev server port, cache
  namespace), language/platform agnostic.
- Detect project type to derive the right isolation (compose file, package
  manager, etc.); degrade gracefully when no isolatable resource is found.
- Mirrors Superpowers' "using git worktrees" intent natively, no dependency.

---

## 9. GSD wrapper (S3 / C3)

Playbook makes GSD right-size user involvement and parallelise execution.

- **Front-load + skip the interactive pass.** Playbook runs its own richer
  discussion + research up front, writes `.planning/phases/XX-slug/XX-CONTEXT.md`
  (documented schema: domain/decisions/code_context/specifics/deferred) and
  optionally `XX-RESEARCH.md`, then runs `/gsd:plan-phase XX --skip-research`.
  GSD sees CONTEXT present and the researcher bypassed: no gray-areas pass, no
  over-research. (Express alt: `--prd <file>` / `--ingest <glob>`.) Decide how
  much user involvement is actually needed first; only ask what the phase needs.
- **Force parallel execution.** Post-process generated `XX-YY-PLAN.md`
  frontmatter to group independent, file-disjoint plans into the same `wave:`;
  set `parallelization:{enabled:true, plan_level:true, max_concurrent_agents:↑,
  min_plans_for_parallel:2}` and `workflow.use_worktrees:true`. For cross-phase
  parallelism, `/gsd:manager --analyze-deps` or `/gsd:workstreams`.
- **Tame doc over-investigation.** Avoid unscoped `map-codebase` 4-way fan-outs;
  prefer `--fast`/`--focus`; supply RESEARCH.md and `--skip-research`.
- **Model rule via GSD's own knobs:** `model_overrides.gsd-executor:sonnet`,
  `model_overrides.gsd-planner/gsd-verifier:opus` (or `model_profile`).
- **Write policy:** Playbook may write only `XX-CONTEXT.md`, `XX-RESEARCH.md`,
  `config.json` keys above, and `XX-YY-PLAN.md` wave frontmatter. Everything
  else in `.planning/` stays read-only. This is the declared relaxation of the
  v1 hard rule.

---

## 10. Offline mode + notify (F5 / C4)

- **Providers:** Pushover *or* ntfy, chosen at setup, recommend Pushover for
  guaranteed iOS DND/Focus bypass (Apple Critical Alerts entitlement, priority
  1/2). ntfy stays for free/Android/self-host (max priority is best-effort on
  iOS as of mid-2026, documented honestly).
- **Unified abstraction:** `notify --level info|action|critical --link <url>
  "<headline>" ["<detail>"]`.
  - `info` → ntfy `3` / Pushover `0`.
  - `action` → ntfy `4` / Pushover `1` (attention, attach link).
  - `critical` → ntfy `5` / Pushover `2` (`retry=60 expire=1800 sound=siren`,
    capture receipt). Gated behind an explicit reason so it is not over-used.
- **Agent latitude:** the running agent chooses the level per event and may fire
  a critical alert when warranted.
- **Setup:** per-provider checklist; for Pushover, instruct the user to enable
  Critical Alerts in the app (High and/or Emergency) and accept the iOS prompt.
  Config under `.claude/playbook/` (gitignored): provider, credentials, server.
- **Remote-control deep link:** keep the Click/url deep-link when
  `/remote-control` is active (already supported).
- **`/goal` division of labour (C4):** `/goal` owns the "am I actually done?"
  loop. Playbook offline mode owns the North Star, the per-run wait picker, the
  notify pull-back, the escalation ladder (self → beat → research → fresh
  subagent → notify+wait → external manager → forced+logged), and the morning
  HTML decision log. No duplication; Playbook can suggest `/goal` for the done-
  loop while it handles absence and escalation.

---

## 11. fix / debug (F3)

Keep the v1 content; change the trigger from literal `[fix]`/`[debug]` tokens to
slash skills with dual names (`/fix` + `/pb-fix`, `/debug` + `/pb-debug`).
Markers 🦞 / 👾. Exit on a slash or natural completion rather than the
`[close]/[end]/[exit]/[done]` tokens (keep token exit as a courtesy alias).
`fix` keeps its strict production-ready + Zod rules; `debug` keeps its
read-summarise-diagnose-confirm cycle and now defers context handling to the
section 5 calm system rather than its own ad-hoc `/compact` checkpoints.

---

## 12. Hooks architecture

- `SessionStart` (startup|clear|compact): overlay (tenets + North Star + model
  rule + context-calm doctrine) on the main thread; re-anchor + resume on
  `source=compact`; run the context-anxiety detection/offer on startup.
- `SubagentStart`: overlay into every helper, carrying North Star + model rule +
  context-calm into every nesting level.
- `PreCompact` (manual|auto): log only (cannot reliably shape the summary).
- `PostToolUse`: the slimmed unease pulse + the calm context beat (near real
  threshold only, never the 65% scare).
- `Stop` / `SubagentStop`: unease (degraded inside subagents as today).

Remove the dead `PostCompact` registration unless re-confirmed real; rely on
`SessionStart(source=compact)` as the post-compaction seam.

---

## 13. Drops

- `superpowers-team` route (engine).
- `skills/modifying-plans/` (+ prompts).
- `skills/synchronised-subagent-development/` (+ prompts).
- `skills/reduce-cost-mode/` (transformed into the always-on model rule).
- The `[fix]`/`[debug]`/`[budget]`/`[close]` literal-token mechanism.
- The v1 visible staffing-call gate and mode menu.

---

## 14. Docs & tests

- Rewrite `docs/`: `engine.md` (silent routing + markers), `tenets.md` (v2
  nine), `in-session-model.md` (calm compaction + re-anchor), `escalation-and-
  offline.md` (Pushover+ntfy+critical+/goal), `skills.md`, `rationale.md`
  (record the v1→v2 pivot and rejected options).
- Rewrite `README.md` to the v2 story (invisible-but-visible, five modes in CC
  terms, the model rule, the compaction fix, dual commands, markers).
- Tests: update `test-design-invariants.sh` (it currently *enforces* the visible
  staffing call and the never-write-`.planning/` rule, both now changed); update
  `test-doctrine.sh` for the v2 tenets; update `test-notify.sh` for Pushover +
  levels; add tests for the context-anxiety detection and the calm beat;
  `manifests.sh` for the new commands/skills; `skill-triggering` for the new
  trigger set. Keep the hook unit tests + fixtures, adapt thresholds.

---

## 15. Manifests

- `plugin.json`: bump to `2.0.0`, refresh description + keywords.
- `marketplace.json`: refresh description.
- `hooks/hooks.json`: per section 12.
- `commands/`: dual-named command files routing into skills.

---

## 16. Build sequence (waves, file-disjoint where possible)

- **Wave 0 (contract):** the overlay text (`hooks/session-start`), the shared
  lib helpers (`hooks/lib/playbook-common.sh`) for detection + calm + model
  rule, the marker/brand convention. Everything imports from these.
- **Wave 1 (parallel, file-disjoint):** engine SKILL rewrite; take-a-beat
  rework; model-rule skill; offline-mode + notify; hackathon reframe; fix/debug
  conversion; new brainstorming; new worktrees; commands/ dual names; drops.
- **Wave 2 (integration):** docs rewrite; tests update; manifests; final
  production sweep; `/pb` status; end-to-end check.
