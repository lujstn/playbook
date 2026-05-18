# The pinned anchor file and the uncertainty ledger: format reference

Scope: this document specifies the on-disk format of the two engine-maintained
files described in `design.md` section 6, tenets 1, 4 and 7. It is the
reference the engine doctrine (Task 9) and the `take-a-beat` and `uncertainty`
hooks build against. It renders the schemas, the band slugs, the callout
shapes, the reading window and the standing override from section 6; it does
not add scope beyond that.

Both files live in a `.playbook/` directory at the root of the working
project. This location is deliberately distinct from GSD's `.planning/` so the
two harnesses never collide. The helpers that create and maintain these files
are `playbook_anchor_init`, `playbook_anchor_read` and
`playbook_ledger_append` in `hooks/lib/playbook-common.sh`.

## 1. The pinned anchor file

Path: `.playbook/anchor.md`.

A single file maintained by the engine and the hooks. It holds, in this order:

- The original user request, verbatim.
- The current one-line statement of what matters.
- A running lessons-and-wrong-turns ledger. This explicitly includes silent
  wrong turns, not only errors that produced a stack trace.
- The next work.

The `take-a-beat` hook feeds the lessons ledger into the compaction prompt and
re-injects the anchor first after compaction, so the original intent outranks
orchestration scaffolding.

On-disk schema, as written by `playbook_anchor_init`:

```markdown
# Playbook anchor

## Original request (verbatim)
<the user's request, byte-for-byte as they wrote it>

## What matters now (one line)
<the current one-line North Star>

## Lessons and wrong turns
(none yet)

## Next work
(set by the engine)
```

`playbook_anchor_init` never clobbers an existing anchor: if
`.playbook/anchor.md` already exists it returns without writing, so the
original-request line and the accumulated lessons survive across turns and
across compaction. The "Lessons and wrong turns" and "Next work" sections are
seeded with placeholder text and are filled in by the engine over the life of
the work.

## 2. The uncertainty ledger

Path: `.playbook/uncertainty-ledger.md`.

A second engine-maintained plain-text file, sibling to the anchor. It is how
tenet 4 is realised: not a numeric score, but a human-style record of
accumulating unease measured against the North Star. There is no score and
nothing is summed.

It is an append-only log. Each entry is exactly one line with three
pipe-separated fields:

```
ISO-8601 timestamp | band-slug | single clause phrased as drift from the North Star
```

For example:

```
2026-05-17T14:31:09Z | really-unsure | less sure I am still delivering X, because schema Y changed
```

Nothing else goes on the line. The clause is always phrased as drift from the
North Star, in the shape "less sure I am still delivering X, because Y".

### When to log: the confidant gate

Before adding an entry, one test: would a competent colleague bother flagging
this to the lead if they walked past? If no, log nothing. On almost every turn
this means zero entries. The `uncertainty` hook asks at the end of every turn
whether anything should be logged; the default and expected answer is almost
always no, and on the large majority of turns nothing is logged. The hook is
only a prompt to apply the confidant test; it never logs anything by itself.

### The five bands: a deliberate, documented slugification

`design.md` section 6 names the five severity bands with prose labels. The
ledger does not write those prose labels; it writes a stable lower-case slug
per band. This is a deliberate, documented slugification and is explicitly
**not** verbatim section 6 text: section 6 carries the prose labels, while the
ledger encodes them as the slugs below so that callout-shape detection can read
the band of each line reliably. The engine doctrine (Task 9) must instruct the
agent to write the exact slug from the left column, so that ledger entries match
callout-shape detection. The mapping is the contract:

| Slug (written to ledger) | design.md §6 prose label | What it instructs |
|---|---|---|
| `minorly-unsure` | Minorly unsure | note it, carry on |
| `starting-unsure` | Starting to become unsure | note it; glance at the ledger next time you pause |
| `medium-unsure` | Medium unsure | glance now; if an earlier entry shares the theme, research or ask a subagent |
| `really-unsure` | Really unsure | stop, re-read the North Star, take a beat or get a second pair of eyes before continuing |
| `dangerously-unsure` | Dangerously unsure | stop now, escalate to the user or a CTO subagent; a single entry at this band trips escalation on its own |

### When to escalate: the three callout shapes

When the agent glances, it reads the ledger as a human would and moves up the
escalation ladder (`design.md` section 8) if it sees any one of these three
shapes:

1. **A single top-band entry.** One `dangerously-unsure` line trips escalation
   on its own.
2. **A rising staircase.** Each new entry is a higher band than the last.
3. **A same-theme cluster.** A cluster of small entries on the same theme close
   together within the window.

It is quantity plus severity plus trajectory, judged, never calculated.

### The window: about one hour of active development time

The timestamps give elapsed wall-clock. The agent discounts from that only the
stretches that were plainly not active development (idle, or waiting on the
user), so the window tracks effort rather than the clock. Within that hour
every entry still counts, even if it feels stale. An entry is deliberately not
dropped early on the judgement that its concern is no longer relevant: that
judgement is itself unreliable, a model can decide something no longer matters
when it still does, and a still-live worry would then be lost. One hour of
active development is the deliberately safe and simple measure. Compaction and
take-a-beat are explicitly not the boundary. There is no timer and no
accumulator; the window is a reading-time judgement applied to the timestamped
lines.

## 3. The standing North-Star override

The standing North-Star override sits above all of this and is independent of
the ledger:

> if an uncertainty or decision could degrade the North Star such that the work would no longer meet it, stop and ask the user before proceeding, regardless of the uncertainty ledger or the mode.

## 4. Note: timestamp authority

The ISO-8601 stamp is written by `playbook_ledger_append` at the moment the
agent appends an entry, not by the `uncertainty` hook process. This is NOT a
fourth section 12 adaptation: section 6's literal phrase "written by the
uncertainty hook" is physically unrealisable (the hook fires on Stop, after the
turn, and `design.md` section 4 forbids it from computing anything, so it
cannot author an entry the agent writes during a later turn). This is therefore
a mechanism-realisation of an unrealisable literal, governed by section 12's own
principle that canonicity governs intent and lens, not literal mechanism; the
intent (every entry is wall-clock timestamped, the hook holds no score) is
fully preserved. Do not later "correct" the mechanism toward the literal
wording.
