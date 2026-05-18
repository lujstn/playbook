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
