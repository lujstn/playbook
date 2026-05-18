# Decision: the ~65% context-usage signal for take-a-beat

Status: accepted
Plan date: 2026-05-16 (this file pairs with that plan date and is named accordingly)
Investigation and write-up performed: 2026-05-17
Scope: Task 4 (SPIKE). Resolves the signal that `take-a-beat` (design.md tenet 7,
section 12) needs in order to fire at roughly 65 percent of the context window
**used**. Replaces the deliberate `playbook_context_percent` stub in
`hooks/lib/playbook-common.sh`. Blocks Task 7.

## Problem

`design.md` requires a beat at about 65 percent context **used**. Research had
already established there is no native hook event that fires on a context
threshold. The usage figure is observable, but only indirectly, so this spike
had to enumerate every candidate source reachable from a hook, pick the simplest
one that is actually sufficient (tenet 8, "less is more"), and nail down the
arithmetic so the beat fires at 65 percent used and not at 65 percent remaining.

## Candidate sources investigated

All four candidates from the plan were inspected on this machine on 2026-05-17.
These are real findings, not assumptions.

### 1. Hook stdin JSON

Not separately probed with a throwaway hook, because the GSD reference settles
the question definitively and a throwaway probe entry in `hooks/hooks.json`
would have violated the "no leftover probe entries" constraint. The decisive
facts, read directly from `/tmp/playbook-research/gsd/hooks/gsd-statusline.js`:

- The **Statusline** hook input carries `context_window.remaining_percentage`
  and `context_window.total_tokens`, plus `session_id` and `transcript_path`.
- The **PostToolUse** and **Stop** hook inputs do **not** carry any
  `context_window` / token-usage field. This is exactly why GSD does not read
  context from PostToolUse stdin: it cannot. GSD's statusline hook reads the
  figure and writes it to a bridge file, and a separate PostToolUse hook
  (`gsd-context-monitor.js`) reads the bridge file back.

Conclusion: stdin is only a viable source inside a Statusline hook.
`take-a-beat` is a Stop-channel concern, not a statusline, so stdin is not a
usable direct source for it. Ruled out as the primary mechanism.

### 2. Environment variables visible to hooks

`env | grep -i -E 'token|context|claude'` was run live. Findings (values
redacted): `CLAUDECODE`, `CLAUDE_CODE_ENTRYPOINT`, `CLAUDE_CODE_EXECPATH`,
`CLAUDE_CODE_SESSION_ID`, `CLAUDE_PLUGIN_DATA`, and assorted unrelated tokens
(`HOMEBREW_TAP_GITHUB_TOKEN`, `GH_EMAIL_TOKEN`). Critically:

- There is **no** environment variable that exposes a context-usage
  percentage or a token count. So env vars alone cannot answer "how full is
  the window".
- `CLAUDE_CODE_SESSION_ID` **is** exported to hooks and holds the current
  session id. This was verified to be exactly equal to the active session's
  bridge filename id and transcript id (see source 3).

Conclusion: env vars cannot supply the figure, but `CLAUDE_CODE_SESSION_ID`
gives any hook (including Stop / PostToolUse, which get no context in stdin) a
reliable key with which to locate a session-scoped bridge file without parsing
stdin at all. This is the load-bearing finding.

### 3. GSD's session-keyed bridge file (chosen source)

`gsd-statusline.js` (lines 303 to 344) reads
`data.context_window.remaining_percentage` and writes
`os.tmpdir()/claude-ctx-{session_id}.json` with this exact shape:

```json
{
  "session_id": "<uuid>",
  "remaining_percentage": 82,
  "used_pct": 18,
  "timestamp": 1779024165
}
```

`used_pct` is written as `Math.round(100 - remaining)` with **no**
auto-compact-buffer normalisation. The source comment (lines 330 to 333) is
explicit that the buffer-normalised value is correct for the statusline
progress bar but "inflates the context monitor warning messages by ~13 points",
so the bridge deliberately stores the raw `100 - remaining`. `gsd-context-monitor.js`
(a PostToolUse hook) reads this file via `os.tmpdir()` keyed by `session_id`
and warns at `remaining <= 35` (i.e. 65 percent used) and `remaining <= 25`.

Live verification on this machine on 2026-05-17:

- `${TMPDIR}/claude-ctx-${CLAUDE_CODE_SESSION_ID}.json` existed for the active
  session and contained
  `{"session_id":"864f6f80-...","remaining_percentage":82,"used_pct":18,"timestamp":1779024165}`.
- `CLAUDE_CODE_SESSION_ID` equalled `864f6f80-...`, exactly the bridge
  filename id and the active transcript id. The env-var-to-bridge mapping is
  real and exact, not theoretical.

Note on tmp directory: GSD uses Node's `os.tmpdir()`, which on macOS resolves
to `$TMPDIR` (a per-user `/var/folders/...` path), not `/tmp`. A shell
implementation must therefore honour `$TMPDIR` (falling back to `/tmp`) so it
looks in the same directory GSD's Node code writes to. Verified: the live
bridge files are under `$TMPDIR`, and `/tmp/claude-ctx-*.json` did not exist.

Conclusion: this is the simplest sufficient source. It is a tiny, well-defined
JSON contract; it is reachable from a Stop / PostToolUse hook purely via an
environment variable; it carries the remaining percentage directly; and it is
already populated for any user who also runs GSD's statusline. Chosen.

### 4. Session transcript .jsonl

The transcript at
`~/.claude/projects/-Users-lucas-Developer-lujstn-playbook/<session>.jsonl`
exists and is large (multi-megabyte). A grep for the native
`Token usage: <used>/<total>; <remaining> remaining` system reminder did not
return a clean machine-readable line on this machine: the only matches were
the literal string occurring inside *this task's own plan prose* embedded in
the transcript, not a real Claude Code usage reminder in a stable position.
That makes a transcript tail both fragile (format and presence are not
guaranteed and are easily confused with prose) and comparatively expensive
(tailing and regex-scanning a large file on every turn) versus a single small
JSON read.

Conclusion: documented as a possible last-ditch fallback only, and explicitly
**not verified** to be reliably parseable from this environment. Not
implemented, by tenet 8: adding a fragile, unverified, more-expensive parse
path on top of a sufficient source would be over-building. If a future change
needs it, it can be added behind the same return contract, but it is out of
scope here.

## Decision

Primary and only production source: the **session-keyed bridge file**
`${TMPDIR:-/tmp}/claude-ctx-${CLAUDE_CODE_SESSION_ID}.json`, in GSD's exact
shape. `playbook_context_percent` resolves the session id from
`CLAUDE_CODE_SESSION_ID`, reads that file, and returns the integer percent
**used**. No throwaway probe hooks were added; no other helper in
`playbook-common.sh` was touched.

A test seam env var `PLAYBOOK_CTX_FIXTURE`, when set, makes the function read
that file instead of the live bridge path. The fixture path and the live path
feed the **same** parse and return logic, so the test exercises the real
parse, not a toy path. The fixtures mirror GSD's `context_window` /
bridge-style shape so this is faithful.

### The used-from-remaining formula (the defect-prone point)

`design.md` tenet 7 and section 12 require firing at about 65 percent
**used**. GSD's bridge keys on `remaining_percentage` and its monitor warns at
`remaining <= 35`, which is 65 percent **used**. Naively "replicating GSD"
yields *remaining*, and a `remaining >= 65` comparison would fire at 35 percent
used, or never. Therefore `playbook_context_percent` returns percent **used**,
derived from remaining:

```
used = 100 - remaining_percentage
```

This is computed by Playbook itself from `remaining_percentage`, even though
the GSD bridge also writes a pre-computed `used_pct`. Deriving it ourselves
from `remaining_percentage` is what proves the inversion is handled and keeps
Playbook correct against a GSD-shaped payload that omits `used_pct`. Read
order in the implementation:

1. If `remaining_percentage` is present and numeric, return
   `round(100 - remaining_percentage)` clamped to 0..100. This is the
   authoritative path and the one the inversion regression test exercises.
2. Else, if a numeric `used_pct` (or `used_percentage`) is present, return it
   clamped to 0..100. Pure fallback for a bridge variant that only exposes
   used.
3. Else, return empty string.

The result is clamped to the integer range 0..100 and emitted with no trailing
newline, because the consumer compares with `[ "$pct" -ge 65 ]`.

### Auto-compact-buffer rescale decision

**Not applied.** Raw window is used: `used = 100 - remaining_percentage`,
with no `AUTO_COMPACT_BUFFER_PCT` rescale. Rationale:

- GSD's own bridge deliberately stores the raw, un-rescaled `100 - remaining`
  for exactly the consumer class we are (an agent-facing threshold check),
  precisely because the rescaled value inflates the figure by roughly 13
  points and would make the warning fire too early
  (`gsd-statusline.js` lines 330 to 333).
- The rescale exists only to make the statusline *progress bar* visually
  account for the autocompact reserve. `take-a-beat` is not a progress bar; it
  needs the figure that matches Claude Code's native `/context` reporting,
  which is the raw `100 - remaining`.
- Tenet 8: the raw formula is one subtraction. The rescale adds an env-var
  lookup (`CLAUDE_CODE_AUTO_COMPACT_WINDOW`), a `total_tokens` read, and a
  two-term normalisation, for a figure that would then be deliberately wrong
  for this use. Simplest sufficient wins.

### Silent degradation (mandatory)

When the signal is unavailable, `playbook_context_percent` returns an **empty
string**, never a number, and never errors. Concretely it returns empty when:
the bridge file does not exist; it exists but is not valid JSON; it is valid
JSON but exposes neither `remaining_percentage` nor a used field as a number;
`CLAUDE_CODE_SESSION_ID` is unset and no fixture is set; or `jq` is missing.
Every read is wrapped so the function cannot abort a `set -euo pipefail`
caller (no unbound-variable trip, no non-zero exit, no stderr on stdout). The
caller treats empty as "do not beat", so an unavailable signal yields no false
beat. This satisfies design.md's silent-degradation mandate: a wrong number or
a false beat is worse than no beat.

Staleness (GSD's `timestamp` / `STALE_SECONDS`) is intentionally **not**
enforced here. `playbook_context_percent` only reports the figure; deciding
whether a reading is too old or whether to beat is the caller's policy
(Task 7). Keeping this function a pure, side-effect-free reader is the tenet-8
choice and keeps the regression test deterministic.

## Consequences

- `take-a-beat` (Task 7) can rely on `playbook_context_percent` returning an
  integer percent **used**, or empty when unknown, and can simply compare
  `[ "$pct" -ge 65 ]`.
- Playbook gains a soft, no-new-dependency interop with GSD: if a user runs
  GSD's statusline, the bridge is populated and Playbook reads it for free. If
  not, Playbook degrades silently (no beat) rather than misfiring. Should
  Playbook later need to self-populate the bridge from its own statusline,
  that is an additive change behind this same return contract and is out of
  scope for this spike.
- The transcript-tail fallback is documented but deliberately unimplemented;
  revisit only if the bridge proves insufficient in practice.

## Verification artefacts

`tests/hooks/test-context-percent.sh` with fixtures
`tests/hooks/fixtures/ctx-used-70.json` (yields 70) and
`tests/hooks/fixtures/ctx-remaining-35.json` (a GSD-shaped payload with
`remaining_percentage: 35`, which must yield 65, proving
`used = 100 - remaining` and guarding the inversion). The unset-signal case
must yield empty. The test was run RED against the stub (the 70 case returned
empty) before implementation and GREEN after.
