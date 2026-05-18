# Decision: which post-compaction event restores the anchor

Status: accepted (with one item deferred to live validation)
Plan date: 2026-05-16 (this file pairs with that plan date and is named accordingly)
Investigation and write-up performed: 2026-05-17
Scope: Task 7, Step 3a (SPIKE sub-step). Resolves which Claude Code lifecycle
event fires after an auto-compaction, so the `take-a-beat` hook (design.md
tenet 7, sections 3 and 6) can re-inject the Playbook anchor first and let the
original user request outrank orchestration scaffolding. Blocks Task 14 Step 3
(the SessionStart bootstrap must not delete the wrong post-compaction path).

## Problem

design.md tenet 7 (line 61) and section 6 (line 162) require that, after
compaction, the anchor is re-injected **first**, before planning and
orchestration scaffolding, so the original intent is not outranked by the
continuation summary. To realise that, `take-a-beat` must run on whatever
event Claude Code fires once a compaction has completed.

There are two candidate post-compaction entry points:

- **`PostCompact`**: a documented first-class event "After compaction
  (receives summary)".
- **`SessionStart` with source `compact`**: the convention, used by
  Superpowers' shipped `hooks.json`, of matching `startup|clear|compact` on
  `SessionStart` so the session-start hook also runs when a session resumes
  through a compaction boundary.

It is not self-evident which of these actually fires after an **auto**
compaction (the unattended case that matters most for tenet 7, since the hook
must ride the wave without the user present). A subagent cannot trigger a real
auto-compaction nor observe which event Claude Code fires across a real
compaction boundary, so this decision is grounded in the documented hook
semantics and the shipped Superpowers precedent, with the residual explicitly
deferred to a live check and a precise procedure given to close it.

The belt-and-braces requirement is independent of which event is load-bearing:
review finding C2 mandates that BOTH the `PostCompact` path and the
`SessionStart`/`compact` path are retained. They emit the identical anchor
text, so running both is idempotent (the model sees the same anchor once per
event that actually fires; if both fire, it is the same text and harmless).
This document records which path is documentation-indicated to be load-bearing
purely so Task 14 does not delete the path that is actually carrying the
behaviour. Task 14 must delete neither path regardless of this finding.

## Evidence (documented; ccsp reference, exact file and line refs)

All citations are from the Claude Code system-prompts reference clone at
`/tmp/playbook-research/ccsp`. Primary file:
`system-prompts/system-prompt-hooks-configuration.md` (ccVersion 2.1.77, per
its front matter line 4).

### E1. `PreCompact` is a documented before-compaction event

- `system-prompt-hooks-configuration.md:41`: event-table row:
  "`PreCompact` | "manual"/"auto" | Before compaction".

So `PreCompact` fires before the compaction runs, and its two documented
matcher values are `manual` and `auto`. This is the event on which
`take-a-beat` injects its `## Compact Instructions` block to steer the native
summary (the lessons-preserving, re-anchoring steer; design.md tenet 7 and
section 6 line 162). It is not a post-compaction restore point; it is the
pre-compaction steer and is uncontested.

### E2. `PostCompact` is the documented first-class post-compaction event and it receives the summary

- `system-prompt-hooks-configuration.md:42`: event-table row:
  "`PostCompact` | "manual"/"auto" | After compaction (receives summary)".

This is the single most load-bearing line in this decision. The reference
explicitly enumerates a dedicated event whose documented purpose is "After
compaction", and explicitly notes it "receives summary" (it runs once the
continuation summary exists). Its two documented matcher values are `manual`
and `auto`, so it is documented to fire after an auto-compaction as well as a
manual `/compact`. By the reference's own event table, `PostCompact` is the
event designed for exactly the post-compaction anchor-restore that tenet 7
needs.

### E3. The documented `SessionStart` row does NOT enumerate a `compact` source

- `system-prompt-hooks-configuration.md:44`: event-table row:
  "`SessionStart` | - | When session starts".

The reference describes `SessionStart` only as "When session starts" and lists
its matcher column as `-` (no enumerated source values, in contrast to
`PreCompact` and `PostCompact` on lines 41 and 42, which DO enumerate
`"manual"/"auto"`). The ccsp hooks reference at ccVersion 2.1.77 does not
document a `SessionStart` source value of `compact` (nor `startup`, nor
`clear`). The `startup|clear|compact` matcher is a convention observed in a
shipped plugin, not a value enumerated in this reference (see E4). On the
documented evidence alone, `SessionStart` is "session starts" and is not the
reference-designated post-compaction hook; `PostCompact` is (E2).

### E4. The `SessionStart` `compact` matcher is a shipped Superpowers convention, not ccsp-documented

- `/tmp/playbook-research/superpowers/hooks/hooks.json:5`: Superpowers' shipped
  `SessionStart` entry uses `"matcher": "startup|clear|compact"`.
- `/tmp/playbook-research/superpowers/hooks/session-start:2,46-53`: the
  Superpowers session-start hook is a real, shipped hook that this plugin
  mirrors verbatim for its cross-platform emit branch (replicated at
  `hooks/lib/playbook-common.sh:42-48`).

Superpowers ships a `SessionStart` hook that matches `compact` and, by
shipping it, treats `SessionStart` as also firing when a session resumes
through a compaction. This is strong ecosystem precedent that the
`SessionStart`/`compact` path is real and worth wiring. It is precedent from a
shipped production plugin, not a clause in the ccsp hooks reference; the ccsp
reference (E3) does not enumerate the value. It is therefore corroborating
evidence for retaining the belt-and-braces `SessionStart`/`compact` path, but
it is not documentation that `SessionStart`/`compact` is the primary or only
post-compaction event. `PostCompact` remains the reference-designated event
(E2).

### E5. `Stop` also fires on compaction, but is not an anchor-restore point

- `system-prompt-hooks-configuration.md:40`: event-table row:
  "`Stop` | - | Run when Claude stops (including clear, resume, compact)".

`Stop` is documented to run on compaction too, but `Stop` fires when Claude
stops, before/around the compaction boundary, not as the post-compaction
"receives summary" event. `Stop` is already owned by the `uncertainty` hook
(Task 5 / Task 8 decision, `2026-05-16-stop-channel.md`) and is not a
post-compaction anchor-restore carrier. It is noted here only to record that it
was considered and is out of scope for post-compaction restore; `PostCompact`
(E2) is the post-compaction event.

### E6. `additionalContext` is the model-visible injection field for these events

- `system-prompt-hooks-configuration.md:91`: JSON output example:
  `"additionalContext": "Context injected back to model"`.
- `system-prompt-hooks-configuration.md:103-104`: field reference:
  "`hookSpecificOutput` - Event-specific output (must include `hookEventName`):
  `additionalContext` - Text injected into model context".

The anchor restore is delivered via the same `hookSpecificOutput`
`additionalContext` envelope used elsewhere in this plugin (the shared
`playbook_emit_context` helper at `hooks/lib/playbook-common.sh:39-49`, which
emits the Claude Code `hookSpecificOutput` form, the Cursor `additional_context`
form, and the Copilot/other bare form). The field contract is event-agnostic
apart from the `hookEventName` discriminator, so the same emitter serves the
`PreCompact`, `PostCompact`, and `SessionStart` branches without a new emitter
and degrades correctly off Claude Code.

## Decision

**Documentation-indicated load-bearing post-compaction event: `PostCompact`.**

On the documented evidence (E2), `PostCompact` is the reference-designated
"After compaction (receives summary)" event, enumerated with `manual` and
`auto` matcher values, so it is documented to fire after an auto-compaction.
`take-a-beat`'s `PostCompact` branch is therefore the path that is
documentation-indicated to carry the post-compaction anchor restore for tenet
7. `hooks.json` registers `take-a-beat` under `PostCompact` with matcher
`manual|auto`.

**`SessionStart`/`compact` is retained as a belt-and-braces secondary path.**
Per review finding C2, and corroborated by the shipped Superpowers convention
(E4), `take-a-beat` also restores the anchor in its `SessionStart` branch when
`.source == "compact"`. This is wired as a SECOND hook object in the existing
`SessionStart` matcher block in `hooks/hooks.json` (the block keeps its
original `run-hook.cmd session-start` dispatch untouched and gains a sibling
`run-hook.cmd take-a-beat` dispatch; multiple hooks under one event is the
documented Claude Code shape, `system-prompt-hooks-configuration.md:13-28`).
Both restores emit byte-identical anchor text, so if both `PostCompact` and
`SessionStart`/`compact` fire for one compaction the model simply sees the same
anchor; the operation is idempotent and there is no double-charging of distinct
content.

**`PreCompact` is the uncontested pre-compaction steer** (E1): matcher
`manual|auto`, emits the `## Compact Instructions` block that tells native
compaction to preserve the Lessons and wrong turns ledger verbatim and
re-anchor on the original request and next work.

**Mandate for Task 14 (the reason this doc exists): delete neither path.**
Task 14 (SessionStart bootstrap) MUST NOT remove the `PostCompact` branch or
the `SessionStart`/`compact` branch from `take-a-beat`, and MUST NOT remove
either event wiring from `hooks/hooks.json`. The documentation-indicated
load-bearing event is `PostCompact`; the `SessionStart`/`compact` path is the
intentional, idempotent, C2-mandated redundancy that covers the deferred risk
described next. Removing the redundant path would only be safe AFTER the live
check below has positively confirmed `PostCompact` fires on auto-compaction on
the target build, and even then C2 mandates retention, so Task 14 keeps both.

## Verified here vs deferred (live validation)

This sub-step was performed by a subagent that cannot trigger or observe a real
auto-compaction boundary. Conclusions are labelled by basis. No throwaway
sentinel or probe file was introduced into `hooks/hooks.json` or `/tmp`
(unlike a live operator, a subagent cannot make the probe fire, so writing a
probe would only have produced an empty `/tmp/pb-compact-probe` and misleading
residue; the honest artefact is this documentation-grounded reasoning plus the
precise live procedure below). The full `take-a-beat` test suite
(`tests/hooks/test-take-a-beat.sh`) does drive the `PreCompact`,
`SessionStart`/`compact`, monitor, and unrelated-event branches deterministically
and offline, and all six assertions pass; that verifies the hook's branch
dispatch and output shapes. What it does not and cannot verify is which event
Claude Code actually fires across a live auto-compaction.

**Verified here (branch dispatch and output shape, offline):**
`tests/hooks/test-take-a-beat.sh` confirms `take-a-beat` emits the
`## Compact Instructions` steer with the Lessons ledger named on `PreCompact`;
re-injects the verbatim anchor on `SessionStart` with `source:"compact"`;
announces the beat with the live percent on the monitor event at/above 65%
used and stays silent below it; and emits nothing on unrelated events
(`Stop`). The `PostCompact` branch emits the same anchor envelope as the
`SessionStart`/`compact` branch by construction (identical helper call, same
anchor text); this is verified by code inspection and the shared-emitter tests,
not by a live `PostCompact` firing.

**Documentation-grounded (not separately re-derived empirically):** that
`PostCompact` is the post-compaction event that "receives summary" and fires
for both `manual` and `auto` compactions. Basis: E2
(`system-prompt-hooks-configuration.md:42`). That `SessionStart`'s documented
contract is "when session starts" and the ccsp reference does not enumerate a
`compact` source for it. Basis: E3 (`system-prompt-hooks-configuration.md:44`).
That the `SessionStart`/`compact` matcher is a real, shipped convention worth
retaining as redundancy. Basis: E4 (Superpowers shipped `hooks.json:5`).

**Deferred to live validation (one item):** a subagent cannot prove, across a
real auto-compaction in a live Claude Code session, whether the target build
fires `PostCompact` (as the reference's event table indicates), or re-fires
`SessionStart` with `source == "compact"`, or both, after an unattended
auto-compaction specifically (as opposed to a manual `/compact`). The
documented event table (E2) indicates `PostCompact` with an `auto` matcher
value, so the documentation-indicated answer is `PostCompact`; the residual is
solely whether the running build's auto-compaction path emits `PostCompact`
with the same fidelity the table describes, and whether it additionally
re-fires `SessionStart`/`compact`. Both paths are retained (C2), so the
behaviour is correct regardless of which one fires; the only thing the live
check changes is which path is recorded as load-bearing, and that only matters
for documentation accuracy, never for correctness, because neither path may be
deleted.

**Live-validation step to close this residual (for Task 14 / the human):**
in a real (non-subagent) Claude Code session with the Playbook plugin loaded
and an anchor present (`.playbook/anchor.md` populated), add a one-line
sentinel to each post-compaction branch of `hooks/take-a-beat` for the
duration of the check only, for example
`echo "$(date -u +%FT%TZ) POSTCOMPACT" >> /tmp/pb-compact-probe` at the top of
the `PostCompact` branch and
`echo "$(date -u +%FT%TZ) SESSIONSTART-COMPACT" >> /tmp/pb-compact-probe` inside
the `SessionStart` `src = compact` branch. Open `/hooks` once (or restart) so
the edited hook and the `PostCompact`/`SessionStart` entries are loaded, then
drive the context up until an auto-compaction fires (or force `/compact` to
exercise the manual path as well, noting the matcher value differs). Inspect
`/tmp/pb-compact-probe`: the line(s) present record which branch(es) actually
fired on this build. Record the observation inline in this document under a new
"Live observation" heading (date, build version, which branch fired on auto vs
on manual). Then REMOVE the sentinel lines and delete `/tmp/pb-compact-probe`
(they are throwaway; no probe residue may remain in the hook, `hooks.json`, or
`/tmp`). Whatever the observation, BOTH branches remain wired per C2; the
observation only updates the "load-bearing" label in this doc, and Task 14
still deletes neither path.

## Consequences

- `hooks/hooks.json` registers `take-a-beat` under four events: `PreCompact`
  (matcher `manual|auto`, the steer), `PostCompact` (matcher `manual|auto`,
  the documentation-indicated load-bearing post-compaction restore), the Task-4
  monitor event `PostToolUse` (matcher `*`, the 65% beat), and as a second
  hook object inside the existing `SessionStart` `startup|clear|compact` block
  (the belt-and-braces post-compaction restore). The original
  `run-hook.cmd session-start` dispatch in that `SessionStart` block is
  unchanged and remains the first hook in the array.
- `take-a-beat` keeps both the `PostCompact` branch and the
  `SessionStart`/`compact` branch. They are idempotent (identical anchor
  text), so running both for one compaction is harmless. Per review finding
  C2, neither is removed.
- Task 14 (SessionStart bootstrap) is bound by the explicit mandate above:
  it must not delete either post-compaction path or either event wiring. The
  load-bearing path is `PostCompact` on the documented evidence; the live
  check, when run, only confirms or refines that label and never licenses
  deleting a path.
- One residual is explicitly open and owned: live confirmation of which event
  fires across a real auto-compaction on the target build, with the precise
  sentinel procedure above so closing it requires no re-investigation and no
  code change (only a label update in this doc; both paths stay).
