# Decision: the Stop-hook output channel for the uncertainty prompt

Status: accepted
Plan date: 2026-05-16 (this file pairs with that plan date and is named accordingly)
Investigation and write-up performed: 2026-05-17
Scope: Task 5 (SPIKE). Resolves which `Stop`-hook output channel the
`uncertainty` hook (design.md tenet 4, sections 4 and 6) will use to surface
its one-line confidant-gate prompt. Blocks Task 8; Task 8 must implement
strictly to the channel and the exact JSON shape decided here.

## Problem

`design.md` section 4 (line 78) says the `uncertainty` hook "Fires at the end
of every turn", "performs no computation and maintains no score", and that the
"default and expected answer is almost always no". Section 6 (line 169) adds:
"The hook is only a prompt to apply the confidant test; it never logs anything
by itself." So on the overwhelming majority of turns the correct outcome is:
the agent sees a one-line nudge, applies the confidant test, decides there is
nothing to log, and **the turn ends normally**.

This makes the channel choice a hard correctness problem, not a cosmetic one.
The chosen `Stop` output channel must be BOTH:

- **(a) model-visible**: the agent actually sees the confidant-gate nudge as
  context on the next turn (a user-UI-only message would never reach the
  agent's reasoning and the hook would be inert); AND
- **(b) termination-safe**: emitting the nudge on *every* turn must NOT trap
  the agent in forced or infinite continuation. Because the hook performs no
  computation (design.md section 4), it cannot conditionally emit; whatever it
  emits, it emits on every single turn end.

`type: prompt` and `type: agent` are not available for `Stop` (command only),
so this is purely about which JSON the `command` hook prints to stdout.

## Evidence (documented; ccsp reference, exact file and line refs)

All citations are from the Claude Code system-prompts reference clone at
`/tmp/playbook-research/ccsp`. Primary file:
`system-prompts/system-prompt-hooks-configuration.md` (ccVersion 2.1.77).

### E1. `Stop` is a command-only hook and fires on stop/clear/resume/compact

- `system-prompt-hooks-configuration.md:40`: table row:
  "`Stop` | - | Run when Claude stops (including clear, resume, compact)".
- `system-prompt-hooks-configuration.md:55-65`: the `prompt` and `agent` hook
  types are documented "Only available for tool events: PreToolUse,
  PostToolUse, PermissionRequest." `Stop` is therefore `type: command` only;
  the decision is solely about the stdout JSON shape.

### E2. `hookSpecificOutput.additionalContext` is injected into the model

- `system-prompt-hooks-configuration.md:91`: in the JSON output example:
  `"additionalContext": "Context injected back to model"`.
- `system-prompt-hooks-configuration.md:103-104`: field reference:
  "`hookSpecificOutput` - Event-specific output (must include `hookEventName`):
  `additionalContext` - Text injected into model context".
- `system-reminder-hook-additional-context.md:8` (ccVersion 2.1.18): the
  template that materialises an `additionalContext` payload into the
  conversation is:
  `${ATTACHMENT_OBJECT.hookName} hook additional context: ${ATTACHMENT_OBJECT.content.join("\n")}`.
  This is a model-visible system reminder, not a user-only surface: it is the
  same delivery mechanism `additionalContext` uses for the tool/compact events
  whose worked examples are documented.

The reference describes `additionalContext` generically for all hooks that
carry `hookSpecificOutput` and does not carve `Stop` out of it. The field
contract is event-agnostic except for the `hookEventName` discriminator, which
for this hook is `"Stop"`.

### E3. `systemMessage` is explicitly user-UI-only

- `system-prompt-hooks-configuration.md:97`: field reference:
  "`systemMessage` - Display a message to the **user** (all hooks)".
- `system-prompt-hooks-configuration.md:141-147`: the only worked `Stop`
  example in the entire reference is captioned "**Stop hook that displays
  message to user**" and its sole mechanism is
  `echo '{"systemMessage": "Session complete!"}'`. The reference's own and
  only Stop example uses `systemMessage` precisely and exclusively for a
  user-facing message, not for feeding the model.

`systemMessage` therefore fails requirement (a): it does not reach the agent's
reasoning. It is disqualified as the carrier for a nudge whose entire purpose
is to make the agent apply the confidant test.

### E4. `decision:"block"` + `reason` forces continuation (disqualified)

- `system-prompt-hooks-configuration.md:87-88`: JSON output example pairs
  `"decision": "block"` with `"reason": "Explanation for decision"`.
- `system-prompt-hooks-configuration.md:101-102`: field reference:
  "`decision` - "block" for PostToolUse/Stop/UserPromptSubmit hooks ...
  `reason` - Explanation for decision".
- `system-reminder-hook-stopped-continuation.md:8` (ccVersion 2.1.18) and
  `system-reminder-hook-stopped-continuation-prefix.md:6` (ccVersion 2.1.31):
  a blocked stop is surfaced to the model as
  `${hookName} hook stopped continuation: ${message}`. The semantic of this
  channel is exactly "the turn did NOT end; the agent must keep going". That
  is the prefix the plan (Task 5 brief) calls the "hook stopped continuation"
  reminder.

`decision:"block"` is the one documented `Stop` channel that is model-visible
*by way of forcing the turn to continue*. Emitting it on every turn end would
re-engage the model every single time and trap it in unbounded continuation:
it can never reach a clean turn end because the very act of trying to stop
re-triggers the `Stop` hook, which blocks again. It is model-visible but
violates requirement (b). It remains theoretically usable only if emitted
*conditionally* (block sometimes, stay silent otherwise), but design.md
section 4 forbids that: the hook performs no computation and holds no score,
so it has nothing on which to branch. **`decision:"block"` is disqualified as
the every-turn channel.**

### E5. `additionalContext` does NOT force continuation (termination-safe)

Continuation under `Stop` is controlled by exactly two documented switches,
neither of which `additionalContext` sets:

- `system-prompt-hooks-configuration.md:98`: "`continue` - Set to `false` to
  block/stop (default: **true**)". A payload that omits `continue` leaves it
  at its default `true`: the turn is permitted to end.
- `system-prompt-hooks-configuration.md:99,101`: `stopReason` only matters
  "when `continue` is false", and `decision:"block"` is the separate
  block switch dissected in E4.

A payload of the form
`{"hookSpecificOutput":{"hookEventName":"Stop","additionalContext":"..."}}`
contains no `decision`, no `continue:false`, and no `stopReason`. By the
documented field semantics it cannot block the stop. The documented behaviour
is: the turn terminates normally, and the `additionalContext` string is
delivered to the model as a system reminder (E2) that it sees on its **next**
turn. This is precisely the "inject a one-line nudge the agent sees on the
next turn while the current turn still terminates" outcome the Task 5 hard
constraint demands.

### E6. Production precedent for the exact shape (real, not assumed)

GSD ships two advisory hooks that use this exact pattern for an every-event
nudge that must never trap the agent:

- `/tmp/playbook-research/gsd/hooks/gsd-context-monitor.js:181-187`: a
  `PostToolUse` hook emits
  `{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":<message>}}`
  and never sets `decision`/`continue`. `gsd/docs/ARCHITECTURE.md:655` and
  `gsd/docs/context-monitor.md:13,43,115` state it "injects a warning as
  `additionalContext`, which the agent sees" and "never blocks".
- `/tmp/playbook-research/gsd/hooks/gsd-prompt-guard.js:82-92`: same envelope,
  "Advisory warning (does not block)".

GSD deliberately attaches its recurring advisory nudge to `PostToolUse`, not
`Stop`. That is an engineering choice about cadence (a tool-step boundary),
not evidence that `additionalContext` is invalid on `Stop`. The field
contract (E2) is event-agnostic apart from the `hookEventName` discriminator.
This precedent confirms the envelope shape and its non-blocking property in a
shipped, every-event production hook; it is corroboration, and the live
Stop-specific delivery confirmation is the one item explicitly deferred below.

## Decision

**Chosen channel:** `Stop` hook prints, to stdout, the
`hookSpecificOutput.additionalContext` envelope with
`hookEventName: "Stop"`. No `decision`, no `continue`, no `stopReason`, no
`systemMessage`.

**Exact JSON shape Task 8's hook will emit** (Claude Code platform):

```json
{
  "hookSpecificOutput": {
    "hookEventName": "Stop",
    "additionalContext": "<one-line confidant-gate prompt>"
  }
}
```

The `<one-line confidant-gate prompt>` is a single sentence asking the agent
to apply the confidant test from design.md section 6 (would a competent
colleague bother flagging this to the lead in passing? if not, log nothing)
and to append to the uncertainty ledger via `playbook_ledger_append` only if
the answer is yes. The hook neither reads nor writes the ledger and holds no
score (see "Hook only prompts" below).

This is already the native output of the existing
`playbook_emit_context "Stop" "<body>"` helper in
`hooks/lib/playbook-common.sh:39-49` (Task 3), which prints exactly this
envelope on the Claude Code branch (line 45), the `additional_context` form on
Cursor (line 43), and the bare `additionalContext` form on the Copilot / other
branch (line 47). Task 8 therefore does not invent a new emitter: it builds
its body string and calls the existing helper (the plan already scaffolds a
`playbook_emit_stop_nudge` wrapper around it at plan lines 797 to 804). The
cross-platform branching is reused verbatim, so the same nudge degrades
correctly off Claude Code without a second decision.

### The concrete `jq -e` assertion for Task 8

Task 8's plan has a single `<JQ EXPR FROM DECISION DOC>` token (plan lines
782, 793). It is filled with exactly this expression:

```
.hookSpecificOutput.additionalContext
```

So Task 8's test asserts the decided channel shape with:

```sh
jq -e '.hookSpecificOutput.additionalContext' <<<"$out" >/dev/null \
  && echo "PASS: decided channel shape" || { echo FAIL channel; exit 1; }
```

A stricter form, also satisfied by the chosen shape and recommended for the
Task 8 test so it pins the discriminator too, is:

```
.hookSpecificOutput.hookEventName == "Stop" and (.hookSpecificOutput.additionalContext | type == "string" and length > 0)
```

Both expressions were exercised here against the probe output for trial (a)
and both return success; see "Empirical shape verification" below. Task 8
must use the `.hookSpecificOutput.additionalContext` expression as the literal
`<JQ EXPR FROM DECISION DOC>` fill (the stricter form is an additive extra
assertion, not the placeholder substitution, so the plan's single-token
contract is honoured exactly).

### Hard-constraint analysis (termination safety, proven)

On a log-nothing turn (the overwhelming common case):

1. The `uncertainty` hook fires on `Stop`. It performs no computation
   (design.md section 4) and prints the fixed envelope above. The
   `additionalContext` string is constant; it does not depend on any
   ledger state or score.
2. The emitted JSON contains no `decision`, no `continue:false`, and no
   `stopReason`. Per `system-prompt-hooks-configuration.md:98` `continue`
   defaults to `true`, and per E4 only `decision:"block"` (absent here) or
   `continue:false` (absent here) can block a stop. Therefore the stop is
   **not** blocked: the turn terminates normally.
3. The `additionalContext` string is delivered to the model as the
   `... hook additional context: ...` system reminder
   (`system-reminder-hook-additional-context.md:8`) and is seen by the agent
   on the **next** turn. The agent applies the confidant test, concludes
   "nothing to log" (the expected answer on almost every turn, design.md
   sections 4 and 6), writes nothing, and that next turn also ends cleanly,
   emitting the same constant nudge again. There is no accumulation, no
   score, and no growth: the nudge is idempotent and stateless.
4. Because step 2 never blocks, there is no continuation loop. Contrast
   `decision:"block"` (E4), which re-engages the model on every stop and can
   never reach a clean end. `additionalContext` reaches a clean end on every
   turn while still being seen next turn. Requirement (a) is met by E2;
   requirement (b) is met by steps 2 and 4. `decision:"block"` is rejected
   because it fails (b); `systemMessage` is rejected because it fails (a).

Conclusion: a log-nothing turn still terminates with this channel. No
infinite or forced continuation. The hard constraint is satisfied.

### Hook only prompts; it never computes, scores, or timestamps

Per design.md section 4 (line 78) and section 6 (lines 168 to 169), the
`uncertainty` hook is purely a prompt. It does not read the ledger, does not
write the ledger, computes nothing, and holds no score. The wall-clock
timestamp on any ledger entry is written by `playbook_ledger_append` at the
moment the agent itself decides the confidant test is met and appends an
entry on a later turn, NOT by the `uncertainty` hook process.

This reconciles design.md section 6's literal phrase "a wall-clock timestamp
(written by the `uncertainty` hook)" with section 4's "performs no
computation". The literal phrase is physically unrealisable: the hook fires
on `Stop`, after the turn, and section 4 forbids it from computing or writing
anything, so it cannot author an entry that the agent writes during a later
turn. The timestamp is therefore materialised by `playbook_ledger_append`
when the agent appends. This is a mechanism-realisation of an unrealisable
literal, governed by design.md section 12's own principle that canonicity
governs intent and lens, not literal mechanism; the intent (every entry is
wall-clock timestamped; the hook holds no score) is fully preserved. It is
NOT a fourth section 12 adaptation. The plan already records this same
reconciliation as Task 6 review note m6 / MINOR-1 (plan line 593); this
decision doc is consistent with it. Task 8 must not "correct" the mechanism
back toward the literal wording.

## Empirical shape verification (verified here) vs deferred (live validation)

This was performed by a subagent that cannot restart Claude Code or observe
real cross-turn `Stop`-hook delivery. Conclusions are labelled by basis.

**Verified here (shape and no-op control):** A throwaway probe script plus a
temporary `Stop` entry in `hooks/hooks.json` were built and exercised with a
synthesised `Stop` stdin payload
(`{"session_id":"probe-sid","transcript_path":"...","stop_hook_active":false,"hook_event_name":"Stop"}`),
discarded by the probe exactly as a no-compute Stop hook would. Results:

- Trial (a) emitted exactly
  `{"hookSpecificOutput":{"hookEventName":"Stop","additionalContext":"PB-PROBE-A"}}`;
  it is well-formed JSON, satisfies
  `jq -e '.hookSpecificOutput.additionalContext'` and the stricter
  `hookEventName == "Stop"` assertion, and contains no `decision` key.
- Trial (b) emitted `{"systemMessage":"PB-PROBE-B"}` (well-formed; carries no
  `hookSpecificOutput`, consistent with E3 that this is a user-UI-only
  surface and not model-injected).
- Trial (c) emitted `{"decision":"block","reason":"PB-PROBE-C"}` (well-formed
  block shape; disqualified per E4 as the every-turn channel).
- Trial (d), the control, emitted exactly `{}`: a clean no-op that, per E5,
  blocks nothing and lets the turn end. This empirically confirms the
  log-nothing structural baseline (no output keys implies no block).

The temporary `Stop` probe entry and the throwaway script
(`hooks/_pb-probe-stop`) were removed before commit; `hooks/hooks.json` was
restored with `git checkout -- hooks/hooks.json` and ends with ONLY the
`SessionStart` entry.

**Documentation-grounded (not separately re-derived empirically):** that
`additionalContext` on a `Stop` payload is injected into the model's context
on the next turn, and that an `additionalContext`-only payload does not block
the stop. Basis: E2, E5, plus the GSD production precedent E6 for the
identical envelope shape on an every-event non-blocking advisory hook.

**Deferred to live validation (one item):** a subagent cannot prove, in a
live multi-turn session, that the `additionalContext` string emitted by a
`Stop` hook specifically appears as a model-visible system reminder on the
next turn (the documented settings-watcher caveat also applies: `Stop` fires
outside the turn, so a freshly added `Stop` hook cannot be proven in-turn;
`/hooks` reload or a restart is required). The documentation (E2) describes
`additionalContext` generically across `hookSpecificOutput`-bearing hooks
without excluding `Stop`, and the worked injecting examples in the reference
are for tool/compact events. The remaining residual risk is solely whether
the Claude Code build delivers `Stop`-sourced `additionalContext` to the
model with the same fidelity as the tool/compact-sourced cases.

**Live-validation step for Task 8 / the human to close this residual:** with
the Task 8 `uncertainty` hook installed, in a real (non-subagent) Claude Code
session, open `/hooks` once (or restart) so the new `Stop` entry is loaded,
then end a turn and begin the next one. Confirm the next turn's context
contains the `uncertainty hook additional context: <one-line confidant-gate
prompt>` system reminder AND that the prior turn ended normally (no "hook
stopped continuation" reminder, no forced continuation). If confirmed, this
channel is fully validated and no code changes are needed (the shape is
already correct and asserted). If, and only if, the live check shows
`Stop`-sourced `additionalContext` is NOT model-delivered on that build, fall
back as specified next.

## Fallback (only if the deferred live check fails)

The documented evidence does NOT show that "no Stop channel is both
model-visible and termination-safe": `additionalContext` is documented as
model-injected (E2) and is termination-safe (E5), so the primary decision
stands and no fallback is invoked now. The following is a contingency,
specified concretely so Task 8 is unambiguously buildable even in the
unlikely event the live check (above) fails.

If live validation shows `Stop`-sourced `additionalContext` is not delivered
to the model on the target build, the uncertainty nudge moves OFF `Stop` to a
`UserPromptSubmit` carrier:

- **Carrier:** a `UserPromptSubmit` hook (event listed at
  `system-prompt-hooks-configuration.md:43`: "When user submits").
  `UserPromptSubmit` supports `hookSpecificOutput.additionalContext` by the
  same event-agnostic field contract (E2), and `additionalContext` from
  `UserPromptSubmit` injecting into the model is the better-trodden path in
  the reference and ecosystem.
- **Exact emitted shape (Claude Code branch):**

  ```json
  {
    "hookSpecificOutput": {
      "hookEventName": "UserPromptSubmit",
      "additionalContext": "<one-line confidant-gate prompt>"
    }
  }
  ```

- **`jq -e` expression (unchanged):** `.hookSpecificOutput.additionalContext`
  (the same `<JQ EXPR FROM DECISION DOC>` fill; only `hookEventName` differs,
  and the stricter optional assertion becomes
  `.hookSpecificOutput.hookEventName == "UserPromptSubmit"`).
- **How Task 8 must change:** register the hook under `UserPromptSubmit`
  instead of `Stop` in `hooks/hooks.json`; call
  `playbook_emit_context "UserPromptSubmit" "$body"` instead of
  `playbook_emit_context "Stop" "$body"` (the helper at
  `playbook-common.sh:39-49` already parameterises `hookEventName`, so only
  the event-name argument and the `hooks.json` event key change). Cadence
  shifts from "end of every turn" to "start of every user turn"; this still
  satisfies design.md sections 4 and 6 because the confidant test is applied
  once per turn boundary and the default answer remains "log nothing".
  `UserPromptSubmit` does not have a continuation-forcing semantic for an
  `additionalContext`-only payload, so the termination-safety argument in the
  hard-constraint section carries over unchanged (no `decision`/`continue`,
  so nothing is blocked). A `PostToolUse`-adjacent carrier (the GSD pattern,
  E6) is the second-choice fallback if a turn-boundary cadence is later judged
  preferable; it uses the identical envelope with
  `hookEventName: "PostToolUse"` and the same `jq -e` expression.

Either fallback keeps the `jq -e` placeholder fill identical
(`.hookSpecificOutput.additionalContext`), so Task 8's test does not change
shape; only the `hookEventName` string and the `hooks.json` event key change.
Task 8 is buildable from this document alone in all three cases (primary
`Stop`; `UserPromptSubmit` fallback; `PostToolUse` second fallback).

## Consequences

- Task 8 implements the `uncertainty` hook as a `Stop` `command` hook that
  calls the existing `playbook_emit_context "Stop" "$body"` (via the planned
  `playbook_emit_stop_nudge` wrapper) and emits the exact envelope above. Its test
  asserts the channel with `jq -e '.hookSpecificOutput.additionalContext'`
  (the `<JQ EXPR FROM DECISION DOC>` fill), and additionally that an empty /
  log-nothing structural baseline does not block. No hardcoded channel
  assumption beyond what this doc decides.
- The hook stays a pure, stateless prompt: no ledger read, no ledger write,
  no score, no timestamp. `playbook_ledger_append` owns the timestamp at
  append time.
- Cross-platform behaviour is inherited from the shared emitter, so the same
  nudge degrades correctly off Claude Code with no further decision.
- One residual is explicitly open and owned: live confirmation that
  `Stop`-sourced `additionalContext` is model-delivered on the target build,
  with the precise validation step and the concrete `UserPromptSubmit`
  fallback both specified above so closing it (either way) requires no
  re-investigation.
