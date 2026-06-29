# Playbook: persistence and unease refactor

Package: `@lujstn/playbook`
Plugin: `playbook`

## 0. What this document is

This is the authoritative specification for the persistence, unease and
context-signal refactor of the Playbook plugin. It supersedes the mechanism in
section 6 of `plan-a-design.md` and its dependents, and it resolves the audit
recorded in Annex 1 (the embedded audit of record).

`plan-a-design.md` stays canonical for everything else. It receives only the
edits sanctioned in section 11 of this document, applied seamlessly so it reads
as though it had always said them, never as a changelog. The authoritative specification for unease is embedded
verbatim in Annex 2 and retains that authoritative status; it is not absorbed
or paraphrased.

`plan-b-implementation.md` is the build plan for the rejected model; its
persistence, unease and context-signal tasks are superseded by this document,
and the implementation plan is regenerated from here. The
`archived-docs-for-context/` decision records, including the on-disk anchor
format and the GSD-bridge and Stop-channel decisions, are historical and are
overtaken by sections 3, 5 and 9.

The document is written to be implementable directly. Every mechanism below is
stated precisely enough to build and test against.

## 1. Root cause

Every issue in the audit has one root. State that needed to survive across
turns and across compaction was written to disk, into a `.playbook/` directory
in the user's working tree, and the engine doctrine and the two hooks were then
written around those files. The anchor became a file, the unease record became
a file, and the context signal was read from a file another tool happens to
write.

A person does not write down their unease, their goal, or how full their head
is. They carry these things and let them colour the next decision. Playbook is
a light overlay that should make a language model behave that way, not a
note-taking system bolted onto the user's project.

The fix is not a better file. It is no file. The conversation is the store. The
hooks steer the compaction seam and prompt the working pulse; they never store.

## 2. The backbone

Three facts make a no-file design correct rather than merely desirable:

- The original request is the first user message in the transcript. Every hook
  receives `transcript_path` on stdin, so a hook can recover the verbatim
  original request deterministically and re-assert it with primacy after
  compaction. This is more robust than the file it replaces.
- Unease is a judgement, not a transcript fact. It cannot be recovered by a
  hook and must not be. It lives only as the agent's most recently stated
  level and movement, riding the conversation. If compaction loses it, the
  agent notices the absence quickly and re-derives a fresh reading from the
  work in front of it.
- Context used is computed by Claude Code itself, with the exact formula
  `input_tokens + cache_creation_input_tokens + cache_read_input_tokens`, and
  every assistant turn records those fields in the transcript. A hook reads the
  transcript and divides by the window the agent declares from its own
  environment.

Tenets 1 (remember what matters), 4 (unease) and 7 (take a beat) stay three
separate mechanisms. They share one plumbing idea, in-session carriage with the
conversation as the store and hooks that steer and prompt but never persist.
They are not merged into a single combined mechanism.

Nothing in this design writes any file into the user's working tree. The
transcript is Claude Code's own data, under `~/.claude`, not the user's project
and not ours; reading it is not persistence. Section 10 states this without
ambiguity.

## 3. Mechanism one: the carrier and the compaction seam (tenets 1 and 7)

### 3.1 What is carried

- The original request, verbatim. Recovered from the transcript, never stored.
- The current one-line North Star. Restated working state, carried in the
  conversation.
- The lessons and wrong turns, including silent wrong turns, not only errors
  that produced a stack trace. Carried in the conversation.
- The current unease level and last movement (mechanism two owns its content).
- The declared context window (mechanism three owns its content).

Only the original request is recoverable by a hook. The rest is restated
working state that rides the conversation and is re-derived if a compaction
loses it.

### 3.2 The seam

`PreCompact` (matcher `manual|auto`) emits a steer instructing the summary to
preserve, verbatim and ahead of orchestration scaffolding: the original
request, the current North Star, the lessons and wrong turns, the current
unease level and movement, and the declared context window.

`PostCompact` (matcher `manual|auto`) and `SessionStart` with `source` equal to
`compact` both re-inject the original request, recovered from the transcript's
first human user message, with primacy, and prompt the agent to re-establish
the North Star and unease from that recovered request and the live work. Both
paths are retained. They emit identical text, so if both fire for one
compaction the agent sees the same anchor once per firing, which is idempotent
and harmless. Retaining both covers the open question of which event a real
auto-compaction emits on the running build (section 9).

### 3.3 Recovery detail

The original request is the first transcript record that is the human's own
user message, not a hook-injected or system-generated record that can precede
it. The recovery helper reads `transcript_path`, identifies that first human
message, and returns its text verbatim. The exact discriminator between a
human message and an injected or system record is pinned in the implementation
plan; the requirement is that recovery returns the user's original request
verbatim and nothing else. If the
transcript is unreadable or no user message is found, the hook emits nothing
rather than a wrong anchor. Silent degradation is mandatory throughout this
design: a wrong value or a false action is always worse than no action.

## 4. Mechanism two: the unease pulse (tenet 4)

The behaviour is fixed by Annex 2, the embedded unease specification. This
section states only how it is realised as a hook, consistent with that
specification.

- One hook, not two. The per-action update and the second-order escalation
  offer are one prompt. The escalation ladder is a conditional clause inside
  that prompt which the agent acts on only if its own restatement was an
  increase. The hook computes nothing and holds no state.
- The hook is registered on `PostToolUse` (matcher `*`) and `Stop`
  (matcher `*`), so it fires on every agent action: every tool use, and the
  end of a reply-only turn. "Every tool call" is one example of an action, not
  the governing category.
- The prompt is a single short constant. It asks the agent to restate the
  unease level and the last movement with a reason only if something changed,
  and it carries the standing North-Star hard stop and the conditional
  escalation clause.
- The no-update path is silence. When nothing changed the agent emits no
  unease line at all; absence means the level is maintained and there is no
  movement. This is the minimum possible token cost on the overwhelmingly
  common path and it inherently biases towards taking no escalation action,
  which is the balance the specification requires.
- The hook emits its prompt as a non-blocking context injection with no
  `decision`, no `continue` and no `stopReason`, so the turn always terminates
  normally and the prompt is seen on the next turn. It never forces
  continuation.

The standing override sits above all of this and is unchanged: if a decision
could degrade the North Star such that the work would no longer meet it, stop
and ask the user before proceeding, regardless of the unease level or the mode.

There is no ledger, no band slug, no callout-shape detection, no one-hour
window and no timestamp. Those were artefacts of the file model and are
removed. The eleven-level and eight-movement enums and their meanings are fixed
exactly as Annex 2 states them.

## 5. Mechanism three: the context signal (tenet 7)

`take-a-beat` must fire at about sixty-five percent of context used. It needs
two numbers, used and window.

- Used is read from the transcript. The latest assistant record carries
  `message.usage`; used equals
  `input_tokens + cache_creation_input_tokens + cache_read_input_tokens`. This
  is Claude Code's own formula, confirmed against the hooks documentation, and
  it is reproduced exactly, not estimated.
- Window is the nominal model window the agent declares once into the session
  (section 6). It is 1,000,000 for the one-million variant and 200,000 for the
  standard window.
- Percent used is `used / window`. The beat fires at about sixty-five percent.

This is aligned to Claude Code's own `/context`, verified live against the
running session: `/context` reported 200.7k of 1m as 20%, which is the raw
1,000,000 window with no reserve applied, and the synchronised transcript sum
of 190,901 was 19% of the same raw window. The roughly one point gap is
`/context`'s own by-category estimate plus reading-instant skew and is
immaterial for a soft sixty-five percent threshold. The window value is pinned:
the one-million variant divides by exactly 1,000,000, not 1,048,576, because
`/context` reported 200.7k as 20%.

The signal deliberately does not target the user's status bar. That figure
(24% at the synchronised moment) is a separate statusline applying an
auto-compact-buffer rescale, the same inflation the earlier GSD research noted.
Tracking it would re-couple Playbook to a third-party convention it does not
own, which is exactly what the audit forbids.

No GSD bridge file. No file we own. No reserve constant. No statusline slot. If
the latest usage record is absent (briefly possible immediately after a
compaction until the next turn repopulates it) or the declared window is
unknown, the hook emits no beat rather than a false one.

## 6. The agent-declared window

The running model is told its own context window by its environment. A hook is
given only the bare model id, which does not encode the window variant, so the
agent is the reliable source.

Engine doctrine instructs the agent, once at the start of work, to state its
context window into the conversation as a single line with a fixed prefix the
hook can match, of the form `playbook-window: <integer>`, for example
`playbook-window: 1000000`. `take-a-beat` reads `transcript_path` for two
things: the latest usage sum, and the most recent line matching that prefix. It
divides the first by the second. The exact prefix token is finalised in the
implementation plan; the requirement is a fixed, unambiguous, single-line form
the hook matches deterministically and the agent restates after a compaction.

The declared window is restated working state, exactly like the North Star. It
is carried in the conversation, preserved by the `PreCompact` steer, and
re-declared if a compaction loses it. Each session declares its own, so a
subagent or teammate holds its own window just as it holds its own unease. If
no declared window can be found, the hook emits no beat.

## 7. Component inventory after the refactor

### Hooks

- `hooks/unease` (renamed from `hooks/uncertainty`). One hook on `PostToolUse`
  and `Stop`. Emits the single constant pulse prompt. Computes nothing, reads
  nothing, writes nothing.
- `hooks/take-a-beat`. Recovers the original request from the transcript and
  re-injects it with primacy on the post-compaction events; emits the
  `PreCompact` steer; computes the context percent from the transcript usage
  sum and the declared window and beats at about sixty-five percent.
- `hooks/session-start`. Emits the overlay. The overlay no longer claims a file
  is the persistence mechanism; it states the in-session model.

### Helpers in `hooks/lib/playbook-common.sh`

- Removed: `playbook_dir`, `playbook_anchor`, `playbook_ledger`,
  `playbook_ensure_dir`, `playbook_anchor_init`, `playbook_ledger_append`,
  `playbook_anchor_read`, and the GSD-bridge `playbook_context_percent`.
- Added: a transcript reader keyed on `transcript_path`, an original-request
  recovery helper, a transcript usage-sum helper, and a declared-window parse
  helper.
- Kept: the cross-platform context-injection emitter, unchanged.

### Wiring in `hooks/hooks.json`

- `unease` on `PostToolUse` (`*`) and `Stop` (`*`).
- `take-a-beat` on `PreCompact` (`manual|auto`), `PostCompact`
  (`manual|auto`), `SessionStart` (`startup|clear|compact`, as a sibling to
  `session-start`), and `PostToolUse` (`*`) for the context check.
- `session-start` on `SessionStart` (`startup|clear|compact`), unchanged.

### Doctrine

- `skills/playbook/SKILL.md`. Tenets 1, 4 and 7 currently embed the rejected
  model inline: the `.playbook/anchor.md` and `.playbook/uncertainty-ledger.md`
  files, `playbook_anchor_init` and `playbook_ledger_append` with the heredoc
  shell-safety note, the one-time `.gitignore` offer, the band slugs, the
  callout shapes, the one-hour window, the `uncertainty` Stop hook, and three
  cross-references to `docs/playbook/anchor-format.md` (a doc that does not
  ship; its content is the archived `archived-docs-for-context/anchor-format.md`,
  superseded per section 0). All of that is removed and the tenet 1, 4 and 7
  doctrine rewritten to the in-session no-file model; the agent-declared-window
  instruction added; the recovered-request behaviour stated; every Red Flags
  and Integration reference, and every `docs/playbook/anchor-format.md`
  cross-reference, updated or removed so no dangling pointer remains. The
  roughly ten stale `design.md` self-references are corrected to
  `plan-a-design.md` in the same rewrite.
- `skills/offline-mode/SKILL.md`. The "uncertainty ledger" appears about
  twelve times, across the prose, the diagram nodes, the Red Flags and the
  integration list, not once. Each is updated to the no-ledger unease model:
  the external-manager gating that keeps it never routine is re-expressed as
  gated by the in-session unease rather than by a ledger, preserving that
  sanctioned adaptation; and the standing North-Star override keeps its rule
  but its phrasing changes from "regardless of the uncertainty ledger" to
  "regardless of the unease level or the mode". The offline behaviour itself,
  the ntfy notify-and-wait, the per-run wait window, the external manager and
  the HTML log, is unchanged.
- `plan-a-design.md`. The sanctioned edits in section 11.

### Tests

The test suite currently encodes the rejected model and is rewritten with it.
These files reference the removed helpers, the `.playbook/` paths or the old
hook name, confirmed by grep:

- `tests/hooks/test-anchor.sh` and `tests/hooks/test-coverage-supplement.sh`
  assert the removed file helpers and the `.playbook/` anchor and ledger
  paths. Removed, with any still-relevant coverage rewritten against the
  in-session model.
- `tests/hooks/test-uncertainty.sh` targets the renamed hook and the
  `.playbook/uncertainty-ledger.md`. Renamed to `tests/hooks/test-unease.sh`
  and rewritten against the constant-prompt, no-state hook.
- `tests/hooks/test-context-percent.sh` and the fixtures
  `tests/hooks/fixtures/ctx-used-40.json`, `ctx-used-70.json` and
  `ctx-remaining-35.json` exercise the removed GSD-bridge helper. Removed and
  replaced by transcript usage-sum and declared-window fixtures and a test of
  the new helpers.
- `tests/hooks/test-take-a-beat.sh`, `tests/hooks/test-session-start.sh` and
  `tests/run-all.sh` reference the removed helpers, the `.playbook/` paths or
  the old hook name. Updated to the in-session model and the renamed hook.
  `tests/run-all.sh`'s long-dash sweep currently targets two non-existent
  paths, `../design.md` and `../docs/playbook`; the first is corrected to
  `plan-a-design.md` and the second is dropped, so the gate covers the
  canonical spec and carries no dead target.
- Added: tests for original-request recovery from the transcript, the
  transcript usage-sum, the declared-window parse, the constant unease prompt
  shape, and the non-blocking emission that lets the turn terminate. The full
  suite is brought green against the new model.

### Documentation

- `README.md`. Its "Runtime state" section documents the `.playbook/` two-file
  model as the shipped contract and tells users to add `.playbook/` to their
  `.gitignore`. That section is rewritten to the in-session, no-file
  statement, matching section 10. The tenet 1, 4 and 7 bullets, the
  "enforced by ... the pinned anchor file" line, and the two-hooks section
  name the anchor file, the append-only ledger and the old `uncertainty`
  hook; these are rewritten to the in-session model, the every-action unease
  pulse, and the renamed `unease` hook. After the rewrite the README states
  that no file is written into the user's tree.
- `.gitignore`. The repo's own `.gitignore` carries a `.playbook/` line, a
  vestige of the rejected model. It is removed; the plugin no longer writes
  that directory, so nothing needs ignoring.

### Left untouched (sound, per the audit)

The five-mode routing, the tiebreaker, the staffing call,
decompose-as-judgement, the `gsd-team` and `superpowers-team` routes, the
`writing-plans` override, and the skills `hackathon-team`,
`modifying-plans`, `synchronised-subagent-development`, the routing core of
`playbook`. `offline-mode`'s offline behaviour is unchanged; only its ledger
references are updated, per the Doctrine entry above. The standing North-Star
hard stop is kept; it is the correct surviving core of tenet 4.

## 8. Audit closure map

- Issue 1, no ledger file. The unease state is restated working state in the
  conversation, re-derived if lost. No file. Closed by sections 2 and 4.
- Issue 2, no anchor file. The original request is recovered from the
  transcript with primacy; the North Star is restated working state. No file.
  Closed by sections 2 and 3.
- Issue 3, no dependency on other plugins for native behaviour. The context
  signal is the transcript usage sum over the agent-declared window, Claude
  Code native, no GSD. Closed by sections 5 and 6.
- Issue 4, rethink the unease index. Replaced wholesale by Annex 2:
  an in-session pulse, every action, silence as no-update, the ladder offered
  only on an increase, no per-turn prompting pattern, no ledger. Closed by
  section 4.
- Issue 5, post-compaction re-anchoring and the unverified-on-live-build gap.
  Re-anchoring is kept and done in-session from the transcript with primacy.
  The live checks become real build steps in this live session, not permanent
  caveats. Closed in design by sections 3 and 9; the named checks are owned in
  section 9.
- Issue 6, scope of the refactor. Section 7 is the change-versus-leave
  inventory. It deliberately extends beyond the audit's named
  source-of-defect scope to the downstream consumers that also encode the
  rejected model, the test suite and the README, while leaving the sound
  parts untouched. Closed by section 7.

## 9. Live-verification status

Verified in this live session, not assumed:

- The transcript usage formula and that those three fields are present on every
  assistant record.
- That Claude Code's `/context` divides by the raw nominal window with no
  reserve, so the transcript-derived percent tracks native `/context` within
  about one point.

Remaining live checks, owned as real steps during the build, runnable here
because execution is a live session and not a subagent:

- That `Stop`-sourced and `PostToolUse`-sourced context injection reaches the
  model on the next turn on the running build. `PostToolUse` has shipped
  precedent; `Stop` is the residual. Fallback if it does not: move the unease
  carrier to `UserPromptSubmit`, same envelope, same non-blocking property.
- Which event a real auto-compaction emits, `PostCompact` or `SessionStart`
  with `source` `compact` or both. Both paths are retained regardless, so the
  behaviour is correct either way; the check only records which is
  load-bearing.
- That the declared-window line survives a real compaction via the `PreCompact`
  steer, and that the agent re-declares cleanly when it does not.

## 10. For the avoidance of doubt

Playbook writes no file into the user's working tree. There is no `.playbook/`
directory, no anchor file, no unease or ledger file, and no bridge file that
Playbook owns. Nothing in this specification implies, requires or permits any
state file in the user's project.

Reading the transcript is not persistence. The transcript is Claude Code's own
data under `~/.claude`, authored by Claude Code, not by Playbook and not in the
user's working tree. Playbook only reads it through the `transcript_path` every
hook is already given.

What matters, the unease sense, the North Star and the declared window are held
in-session: carried in the conversation, restated as the work proceeds, steered
through compaction in-session, never written to disk. A fresh session begins
without them: unease at its lowest level with no movement, the North Star
re-established from the recovered original request, the window re-declared from
the environment.

## 11. Sanctioned edits to the immutable document

`plan-a-design.md` is canonical. The only edits it receives are:

- The unease naming directive applied everywhere, including Appendix A: the
  concept is `unease`, never `uncertainty` or `anxiety`.
- Section 6 and its dependents rewritten to the no-file in-session mechanism
  specified here, with the file-based anchor and ledger removed and the
  context signal stated as the transcript-derived, agent-declared-window
  model.
- The three sanctioned adaptations of Appendix A preserved exactly: tenet 3's
  external-manager check-in gated rather than routine, tenet 5's SMS becoming
  ntfy, tenet 7's "65% of the day" becoming about sixty-five percent of context
  used.

Every edit is applied seamlessly, so the document reads as though it had always
said it, never as a changelog. Everything else in `plan-a-design.md`, including
the rest of Appendix A's intent and lens, is preserved and remains canonical.

## 12. Embedded source documents

This document is self-contained. Two binding source documents are embedded
verbatim, each under its own annex:

- Annex 1 is the project audit of record. Section 8 of this document is the
  closure map against it.
- Annex 2 is the authoritative unease specification, retaining that
  authoritative status. Its own section 14, numbered within Annex 2, holds
  the governing directives of record.

Each annex is byte-for-byte the source it embeds. The standalone files were
removed after a content-integrity check confirmed exact preservation.

## 13. Build constraints carried forward

- British English throughout. Zero long dashes (no U+2014, no U+2013) in every
  shipped and spec file, with no inherited exemption.
- The unease naming directive, including Appendix A. Pestering or
  repetitive-prompting behaviour is an implementation failure, not a design
  option.
- Generated skill and hook text improves adherence where native Claude Code
  falls short; it does not re-explain native planning, todos, subagents,
  compaction or code hygiene from scratch.
- The implementation plan is reviewed by fresh adversarial subagents, a new
  one per pass, fixing critical and major findings between passes, until a
  pass returns zero critical and zero major.

## Annex 1: audit of record (verbatim)

The project audit that motivated this refactor, embedded verbatim. Section 8 is the closure map against it; the original heading and numbering are preserved.

<!-- BEGIN VERBATIM ISSUES.md -->
# Open issues

1. **No `.playbook/` files written into user projects.** The uncertainty ledger
   must not be persisted to disk in the user's working tree (no `.playbook/`
   directory, no ledger file). It needs to be kept in-session and the agent
   nudged to maintain it, not stored. Find another way to hold the ledger of
   uncertainty without writing user files.

2. **No persistent anchor file.** The North Star / anchor must not be saved to
   disk. Persisting it causes file bloat and is not how a person works: you keep
   the core goal in your head, you do not write a note for it. The anchor must
   be carried explicitly in-session, passed clearly enough between steps that it
   survives compaction, with the agent nudged to remember it rather than reading
   it back from a stored file.

3. **No dependency on other plugins for native behaviour.** The context-usage
   signal that `take-a-beat` needs currently relies on GSD's statusline bridge
   file. That is not acceptable: Playbook may point to GSD/Superpowers for big
   projects, but our own rules and hooks must be standalone. Remove the
   GSD-dependent code and explore a native way to get context used, for example:
   (a) clone the claude-code prompts folder again and investigate what is
   available natively, or whether a hook can ask Claude itself to report it;
   (b) derive it another way, such as reading the model name to infer the window
   size (`opus` default vs `opus[1m]` explicit 1m vs `claude-opus-4-7` explicit
   300k, etc.).

4. **Rethink the uncertainty index entirely.** The framing was lost. The
   original idea was a person feeling increasingly unsure over time until they
   decide to ask for help, then running a ladder of cheap-to-expensive
   responses (take a breath, research, ask a subagent, grill the user), with one
   hard rule: if the uncertainty could degrade the North Star such that the work
   no longer meets it, stop and ask the user. The early "just a number, 0 to
   100" idea was floated as optional and was said up front to not necessarily be
   right. What was built instead is the opposite model: a hook that nags every
   single turn, and the agent only reacts once the nagging forms a pattern. That
   is wrong too. Both the numeric-score version and the append-only
   ledger-with-bands version miss the point. This needs a redesign from the
   canonical tenet 4: a rising internal sense of unease that triggers the
   escalation ladder and the hard North-Star stop, held in-session, not as a
   file and not as a per-turn nag. The downstream Stop-channel plumbing
   decisions are moot until this is settled.

5. **Post-compaction re-anchoring and the unverified-on-live-build gap.** Two
   things to carry into the redesign. First, the intent that after a compaction
   the original request is re-asserted with primacy, so it is not outranked by
   planning and orchestration scaffolding, is correct and must be kept, but it
   has to be done in-session, not by reading a persisted anchor file back. The
   "which post-compaction event fires" decision is moot only in its file-based
   mechanism, not in its intent. Second, all three build decisions (the context
   signal, the Stop channel, and the post-compaction event) were settled from
   Claude Code documentation only and were never verified on a live run, because
   a subagent cannot observe a real compaction or a real cross-turn hook
   delivery. Closing that live-verification gap is part of the redesign, not an
   afterthought.

6. **Scope of the redesign: what to change and what to leave alone.** An audit
   confirmed the damage is contained. Leave alone, these are sound: the
   five-mode routing, tiebreaker and staffing call, decompose-as-judgement, the
   gsd-team and superpowers-team routes, the writing-plans override, the
   hackathon-team skill, the modifying-plans skill, the
   synchronised-subagent-development skill, and the standing North-Star
   hard-stop ("if it could degrade what matters, stop and ask the user"), which
   is the correct surviving core of tenet 4 and the thing the redesign should
   build around rather than replace. Change: design.md section 6 (the root
   defect) and its dependents, namely the two hooks (take-a-beat, uncertainty),
   the four helpers in hooks/lib/playbook-common.sh (anchor init, ledger append,
   anchor read, context percent), the tenet 1, 4 and 7 doctrine text in the
   engine skill plus its matching Red Flags and Integration references, and the
   single "gated by the uncertainty ledger" phrase in the offline-mode skill
   (a light touch-up, not a redesign of that skill).
<!-- END VERBATIM ISSUES.md -->

## Annex 2: unease specification (verbatim)

The authoritative specification for unease, embedded verbatim and retaining that authoritative status. Its section 14 items are governing directives of record. Its internal references to other files and to its own sections are preserved exactly as written.

<!-- BEGIN VERBATIM unease-spec.md -->
# Unease: design specification

This is the authoritative specification for `unease`: an in-session signal an AI agent maintains and surfaces to track how uneasy it feels about delivering the work, so it can judge when to seek help. It replaces the mechanism in section 6 of the main design document `plan-a-design.md`, together with the governing directives that accompany it. Indented quotations are exact and binding; two changes are applied to them throughout and not re-flagged at each site: the concept is always written `unease` (section 1), and obvious typos are fixed, with any omission inside a quotation shown by an ellipsis. Section 15 lists the points that are still open.

## 1. Naming directive

Rename the concept to `unease`, not `uncertainty` or `anxiety`.

- `uncertainty` is rejected because it sounds epistemic ("How likely am I to be wrong?").
- `anxiety` is rejected in the actual interface because it may over-emotionalise the agent.
- `unease` everywhere, including the appendix. No references to `uncertainty` or `anxiety` anywhere.

## 2. What unease is (concept and intent)

- Escalation is pure agent judgement: the agent "observes the north star, options available, and makes the call". It decides for itself; nothing mechanical forces it.
- Alongside that, a separate idea: "how uneasy am I feeling right now?".
- The user's definition of the thing being replicated:

> it's more like the sense that as a human works, they start feeling a little uneasy about multiple things and that can build to the point where they stop and ask, even if just looking at that one event means they would do nothing. This is what I am trying to replicate.

- It is hard to quantify. The user: "It's hard to quantify and I don't think a 0-100 number is the way to go about it, but we need to explore options from this."
- The user's framing:

> we need the LLM to treat "unease" as another variable that it maintains and can observe, but it is not a deterministic value. It may influence an escalation decision but they are two totally different things; the only idea is to expose to help with an LLM's judgement.

- Building on that pure-judgement approach, the user's list of what the agent has available:
  - The agent decides itself
  - The agent sees the one sentence North Star always and the hooks reflects on that
  - The agent can see the ladder of help options it has available

  Then, set apart by the user as a separate need ("But we need something else:"):
  - The agent can also see how uneasy it's been recently

  Note: sections 3 and 6 refine this list. The state the agent sees and answers each time is only the three parts in section 3; the escalation ladder is not part of it and appears only when unease increases (section 6).

## 3. The per-action state and answer

The user's explicit request:

> Every tool call, the agent sees the state and must answer it:
> §1 North Star sentence, 280 chars max. This is what unease is measured against.
> §2 unease level: exactly one of your 11 fixed words, meanings exactly as you wrote them.
> §3 last movement: exactly one of your 8 fixed words, then : reason, 50 chars max.
>
> After performing an action (e.g. replying to the user, editing a file, etc) it MUST return a new: unease enum label + last movement enum label + concise reason (max 50 chars) [or to say no update]. This determines the "last movement" state.

Additional statements by the user about this loop:

> every tool it sees the state and has to update it (even if the update is "stay the same and do not update unease or reason" / null / similar)

> The unease measure should happen every single turn IMO (e.g. editing files etc). It can happen quite a lot and be updated a lot and that is ok because it does not do much.

The agent sees only the values it most recently stated (the single current §2 level and §3 last movement); there is no history or trail. The user: "the agent to simply see the last values it most recently stated".

## 4. The unease level enum (§2), fixed exactly as the user stated

Eleven fixed words, meanings exactly as the user wrote them:

| Level | Meaning of level |
| ---------------- | ------------------------------------------------------------ |
| `clear` | No meaningful unease. The path feels straightforward. |
| `settled` | Some normal unease exists, but nothing is pulling attention. |
| `attentive` | The agent is aware of possible risk, but it feels ordinary and contained. |
| `watchful` | There are live concerns worth monitoring, though not yet troubling. |
| `faintly_uneasy` | A small unresolved discomfort is present. It may accumulate. |
| `uneasy` | The agent feels real concern about delivering the north star cleanly. |
| `concerned` | Multiple or significant concerns are now affecting judgement. |
| `strained` | The agent can proceed, but the work feels cognitively or directionally fragile. |
| `troubled` | The agent suspects it may be drifting from the north star or missing something material. |
| `alarmed` | The agent feels a serious risk to the north star, even if it may still continue. |
| `near_breaking` | The agent is close to needing a stop, escalation, or major reset. |

## 5. The unease movement enum (§3), fixed exactly as the user stated

Eight fixed words, followed by a colon, followed by a brief explanation (50
char limit). The two column headers and the example reason strings are as the
user wrote them; the words are shown in code style for readability, matching
section 4 (the user's source table did not code-format them):

| Level | Example of reason string |
| ------------------ | ------------------------------------ |
| `maintained` | risks unchanged after type review |
| `slightly_increased` | API surface still ambiguous |
| `increased` | north-star fit now less clear |
| `sharply_increased` | found conflicting design assumptions |
| `barely_reduced` | narrowed one open question |
| `slightly_reduced` | TSEnum path looks workable |
| `reduced` | user clarified escalation boundary |
| `sharply_reduced` | failing approach replaced cleanly |

The user confirmed these two enums: "Yes they are fixed as I stated exactly."

## 6. The second-order escalation offer

The user's explicit request:

> If the action is an increase in unease, we then nudge the escalation options available via the escalation ladder.

Supporting statements by the user:

> if the agent then ever increases unease, we then offer the escalation pathways if it wants to (even if the unease measure is only small!). That is a second-order option we give.

> I think these are two things, but the second is triggered by the first. There is pretty much no way to reduce unease and trigger escalation, so we can tie these together neatly. Totally ok for a small unease increase, we prompt, agent will probably say no. That's the likely path.

## 7. Decoupling of level and escalation

The user's statements:

> We jump to much higher unease enums because we feel that must mean escalation. Instead, unease level should be like a human's (i.e. can be high and you still decide not to trigger!) and is in reference to the entire project's north star, not just your current task. E.g. you can escalate with low unease that peaks slightly because you are unsure about something.

> It may influence an escalation decision but they are two totally different things; the only idea is to expose to help with an LLM's judgement.

## 8. Token minimisation

The two common exchange paths must be optimised for minimal possible token
usage. The user's statement of the two paths:

> a) "no change"/"keep last reason" and b) slight enum increase => opens escalation ladder => agent returns no escalation needed

## 9. The balance requirement

> we need it to be architected in such a way that the default encourages not taking escalation action whilst its very nature of course being there to encourage it. Does this make sense? These default/inherent qualities must balance each other out or we are biasing the model.

## 10. Lifecycle

The user's statement:

> Unease always exists, carried in compaction etc, not expired, but also never persisted. If it does not exist it must be set, and if it is set it might be outdated (the agent should be able to tell that quite quickly!)

Also stated by the user:

> This should not be something that needs to persist when sessions totally restart etc ...

## 11. Scope across sessions and agents

The user's statement:

> North star unease is whole project, correct. Each LLM session (call that agent, session, team member, whatever you'd like) holds its own unease. That means for example the team lead is unlikely to do much beyond coordination but will effectively end up holding overall unease for work being done as an inherent result of its role.

## 12. The one hard rule above unease

This rule comes from the project audit (`ISSUES.md`), not from the unease design itself, and it overrides everything above. It is the one hard stop the redesign keeps: if a decision could degrade the North Star such that the work would no longer meet it, stop and ask the user before proceeding, regardless of the unease level.

## 13. Tenets are separate

`plan-a-design.md` defines several tenets and `unease` is one of them. It must not be merged with the others into a single combined mechanism: they are separate concerns and stay separate. The user's words: "The tenets are totally different things."

## 14. Governing directives given alongside this spec

- plan-a-design.md is an immutable document. It must not read like a rolling or updatable doc that records "we decided X on Y date". The user: "It is the same" (the corrected text must read as though the document had always said it, not as a changelog).
- A "for the avoidance of doubt" or FAQ style section is acceptable.
- The user never asked for the `.playbook/` files. An LLM misinterpreted an under-specified section. The remedy is to make the document clearer and more explicit, and a "for the avoidance of doubt, this is not implied" style note may be added.
- If the document has other rolling updates, those are to be refactored too.
- The word "nag" is banned, and any nagging behaviour is an implementation failure, not a design option. The user: "stop saying \"nag\" ... I don't want to nag anyway, that would be a failure of implementation."
- The user makes the decisions on this redesign. Propose options; do not self-authorise design or implementation choices. The user's words: "you do not judge, i do."

## 15. Open points (must be settled before implementation)

These are undecided. Do not resolve them unilaterally.

- Separate or combined: whether the per-action unease update and the escalation offer are built as two hooks or one. The behaviour is fixed (the escalation offer is triggered by an increase, section 6); only the implementation form is open. The user's words: "Perhaps we even separate these concepts as separate hooks or something like that? ... Let's discuss options."
- Compact encoding of the no-update path. The behaviour is fixed: the unease state updates after every agent action. An action is any observable step the agent takes, including replying to the user, editing a file, or running a tool. "Every tool call" is one example of an action, not the governing category. The only open point is how to encode the update as cheaply as possible, above all the common "no update" path, whether as a `null`, an omitted output, or another minimal sentinel. The encoding is settled at implementation; the every-action behaviour is not in question.
<!-- END VERBATIM unease-spec.md -->
