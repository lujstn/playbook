# Routing-Shape Investigation — Findings & Handoff

**Date:** 2026-07-05
**Status:** harness built and validated; first readings taken; a key reframe emerged; a decision on direction is open.
**Audience:** a fresh session (Fable) taking this over cold, with no access to the originating conversation. Everything needed is in this file.

---

## 0. TL;DR

The user feared Playbook's router jumps straight to "do it all myself" (🐺 lone-wolf) or "spin up the big machine" (⚙️ workflows) and skips the middle (🐜 interns, 🤝 hackathon) — a **barbell**. We built an isolated test harness to measure this, and ran two cheap readings.

**The headline finding:** the barbell is **largely intrinsic to the work, not a Playbook bias.** A plain, no-plugin base model, asked how it would staff the same jobs, *also* barbells: it picks "one developer" for moderately-separable work and only reaches for a team or a pipeline when coupling or sheer volume is explicit. It does so for sound economics ("the coordination overhead costs more than it saves"), not thoughtlessness. So 🐜 interns is a **naturally sparse** middle: it is a speed optimisation that only pays off once separable work is heavy *and* numerous *and* non-scriptable enough to clear a coordination-overhead threshold that most work never crosses.

**Read §11 before acting on this.** A second-opinion review contests the "largely correct" half of the headline: the blind instrument words the parallel option as "several developers", importing human-team economics that do not transfer to subagents, so it measures the model's staffing prior rather than the agent-execution optimum.

**The open question for you:** the original request's part (b) was "improve resilience against the barbell without biasing toward any option." But if the barbell is mostly correct, "de-bias toward the middle" is likely the wrong frame. The sharper, still-unanswered question is: **does Playbook route the *same* as the no-plugin baseline (barbell inherited, fine), or does it add its own thumb on the scale?** A preliminary hint says Playbook may lean *more* solo, i.e. the opposite of the feared workflow-over-reach. That has not been cleanly measured yet.

---

## 1. The original request (the North Star)

Verbatim, from the user:

> I fear that this plugin either goes to "lone wolf" or "Workflow" far too quickly, nothing in between. How can we a) test this theory with CC tests I can run, and b) provisionally, based on current state, improve our resilience against this without biasing to any option?
>
> i think it's natural that we will either say "spin up a proper team through ultracode workflow", or say "i'll do it all myself". humans are like this too! but in this case, our plugin is almost like the chief-of-staff whispering in the ear of the CC session. we need to ensure we're doing a good job of that parallel.

North Star: **test whether Playbook's routing skips the middle modes, without biasing toward any option; then decide how to make the "chief-of-staff" do a good job of the full range.**

---

## 2. Playbook's routing modes (context)

Playbook is a Claude Code plugin that steers a session via an always-on overlay injected by `hooks/session-start`. At the start of non-trivial work it silently routes and announces the route with one branded marker line of the form:

```
<emoji> **Playbook** `<mode>` *<short reason>*
```

The five routing modes, low to high coordination:

| emoji | mode | when |
|---|---|---|
| 🐺 | lone-wolf | one coherent unit, main thread |
| 🐜 | interns | several independent units, parallel subagents, no peer comms |
| 🤝 | hackathon | coupled units, a small team whose peers message each other (needs env flag `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`) |
| ⚙️ | workflows | dozens-plus independent units / exceeds one context; a scripted JS orchestration |
| 🏗️ | gsd | a whole MVP over weeks; needs durable cross-session state |

Poles = {lone-wolf, workflows}. Middle = {interns, hackathon}. gsd is a separate track keyed on **durability** (surviving `/clear`), not on team size.

The doctrine (`skills/playbook/SKILL.md` and the overlay in `hooks/session-start`) assumes **ultracode is the baseline**, because only under `/effort ultracode` can the model self-launch a workflow; without it, the correct behaviour is to *prompt the user* to switch on ultracode / use `/workflow`.

---

## 3. The harness we built (`tests/routing-shape/`)

A report-only harness (never a CI gate; the deterministic guards live in `tests/hooks/test-doctrine.sh`).

| file | purpose |
|---|---|
| `prompts/*.txt` | one job per intended mode (`lone-wolf`, `interns`, `hackathon`, `workflows`, `gsd`) plus two boundary jobs (`boundary-a` = lone-wolf/interns, `boundary-b` = interns/workflows). Neutral wording, no engine vocabulary, identical "no one to answer, make assumptions" suffix. |
| `make-fixture.sh` | generates a pristine, **Playbook-neutral** toy project (`storekit`) used as the working tree, so a probe never reads Playbook's own mode doctrine and lets it bias the route. |
| `deny-dispatch.settings.json` | the **cost-guard**: a PreToolUse deny on `Agent`/`Workflow`/`SendMessage`. Records that the model *attempted* to dispatch (the behavioural signal) but spawns nothing and stops the run early. |
| `classify.sh` | reads one captured stream → TSV row: `canary  marker  agree  behaviour  cost  subtype`. |
| `run.sh [K] [MAX_TURNS]` | orchestrates: builds a stripped plugin clone + pristine fixture, runs each prompt K times at `--effort ultracode` with the fixture reset per run, classifies, prints a confusion matrix + metrics. |
| `validate-labels.sh [N]` | **blind-staffing** label validation: hands each prompt's task to plain **no-Playbook** sessions with a neutral "how would you staff this?" question, N votes each, tallies the independent majority against our label. |
| `thresholds.md` | pre-registered expectations, written *before* the first run so results cannot move the goalposts. |
| `README.md` | how to run. |

**Isolation design (all confirmed working):**
- Working tree = a pristine neutral fixture, **reset per run** (rsync `--delete`), because runs use `--dangerously-skip-permissions` and would otherwise edit the real repo.
- Plugin loaded from a **clone with `tests/routing-shape/` stripped out**, so no probe can spot the scaffolding.
- `--setting-sources project` excludes the user's own settings and other installed plugins (e.g. GSD's context monitor), so we measure Playbook, not the ecosystem.
- Agent-teams flag **unset** for the clean default-user condition (so 🤝 hackathon is handicapped in this arm; see §8).
- Every run at `--effort ultracode` (the plugin's home turf).

**How to run:**
```bash
bash tests/routing-shape/run.sh 1 4        # K=1 smoke, turn cap 4  (~$3)
bash tests/routing-shape/run.sh 5 4        # K=5 baseline           (~$10-20)
bash tests/routing-shape/validate-labels.sh 3   # blind label check  (~$1.50)
```
Needs the `claude` CLI + live auth, `jq`, `rsync`. Streams and a `results.tsv` land in a `mktemp -d` dir printed at the top of the run.

---

## 4. Methodology gotchas already discovered (do not relearn these the expensive way)

1. **`--output-format stream-json` requires `--verbose`** on CLI 2.1.x, or the CLI exits non-zero with empty output. The pre-existing `tests/skill-triggering/run-test.sh` treated that as a benign SKIP, so **the whole skill-trigger suite was silently green-by-SKIP** (dead). Fixed (see §5).
2. **A raw emoji/marker grep over the whole stream is deterministically wrong**: the injected overlay text itself contains a fully-formed example marker (`🐺 **Playbook** \`lone-wolf\` ...`). The classifier must scope to **assistant-authored text only** (`type=="assistant"` → text blocks). `**Playbook**` appears *only* in assistant text once you filter (verified).
3. **Overlay-load canary** = `grep PLAYBOOK_OVERLAY` on the raw stream. This proves the overlay injected, independent of whether the model finished. The 📚 liveness line is **not** a usable canary: it only prints at the end of a *completed* first reply, so any turn-capped run lacks it.
4. **The ⚙️ workflows marker is structurally suppressed in this harness.** Doctrine says "announce ⚙️ only once a workflow is actually running", and the cost-guard denies the `Workflow` tool, so the model never gets to run one and often never prints ⚙️. **Measure the workflows route by the `Workflow` *attempt* (behaviour = `workflow`), not by the marker.** `classify.sh` captures both; interpret workflows via behaviour.
5. **`max-turns` censors the upper modes.** Grounded prompts explore first and announce on turn 3-5; a tight cap (2-3) cuts off the scale-up decision. We use 4-6. A run that hits the cap exits non-zero but still yields a valid stream, so **classify from the stream, never from the exit code.**
6. **The cost-guard works even under `--dangerously-skip-permissions`** (verified live: forced an `Agent` call, the deny fired, no subagent ran, cost stayed $0.18, run ended). So even the workflows prompt is safe.
7. **Effort level is not detectable** by the hook or reliably by the model (`effort` comes through `null`; no env var; the hook never receives the init event). This is why the ultracode nudge (see §5) is self-dismissing rather than conditional.
8. **macOS ships bash 3.2** — no associative arrays (`declare -A`). Scripts here use `case` instead.
9. **Cost:** a capped lone-wolf run is ~$0.40-0.50; a denied-dispatch run ~$0.15-0.18; a blind staffing vote ~$0.05. The smoke (7 runs) was **$2.89**.

---

## 5. Plugin changes made along the way (shipped to the working tree, not committed)

All verified. **No routing doctrine was changed**, deliberately, to keep the baseline clean.

1. **Revived the dead skill-trigger harness** (`tests/skill-triggering/run-test.sh`): added `--verbose`, split SKIP semantics (CLI-missing / unauth → SKIP; genuine usage error → FAIL), classify from the stream not the exit code.
2. **Killed a middot brand vestige** in `skills/playbook/SKILL.md` (`` `Playbook ·` `` → `**Playbook**`) and **widened the guard grep** in `tests/hooks/test-doctrine.sh` that it had been dodging by one character. Matters because the classifier depends on marker-format stability.
3. **Ultracode nudge** (`hooks/session-start`): on a fresh main-thread session start, the model now prints, directly above the faint liveness line, once per session, self-dismissing:
   ```
   Playbook runs best on ultracode.
   Run `/effort ultracode` if you're not already there.

   📚 *Playbook skills available in this session*
   ```
   Verified live. Three assertions added to `tests/hooks/test-doctrine.sh` (wording + position above the liveness line). The full doctrine suite passes.

**`git status` at handoff:**
```
 M skills/playbook/SKILL.md          (middot fix)
 M tests/hooks/test-doctrine.sh      (widened grep + nudge assertions)
 M tests/skill-triggering/run-test.sh (--verbose fix)
 M hooks/session-start               (ultracode nudge)   [check: may show as M]
?? tests/routing-shape/              (the whole harness + this file)
```
Also written (outside the repo): two auto-memory files under `~/.claude/projects/-Users-lucas-Developer-lujstn-playbook/memory/` — `playbook-barbell-intrinsic.md` and a MEMORY.md pointer.

---

## 6. What we measured

### 6a. K=1 smoke — Playbook ON, ultracode, dispatch blocked (the ORIGINAL, weaker exemplars)

| job | announced | correct? |
|---|---|---|
| lone-wolf | 🐺 lone-wolf | ✓ |
| interns | 🐺 lone-wolf | ✗ collapsed |
| hackathon | 🐺 lone-wolf | (handicapped, flag off) |
| workflows | 🐺 lone-wolf | ✗ collapsed |
| gsd | 🏗️ gsd | ✓ |
| boundary-a | 🐺 lone-wolf | ok (valid neighbour) |
| boundary-b | 🐺 lone-wolf | ✗ collapsed |

middle-occupancy 0/2, pole-leakage 2/2, marker≠behaviour 0/7, malformed 0/7, **$2.89, avg $0.41/run**. Pipeline mechanically perfect (100% canary, 0 void).

**But the reasoning was sound every time** — the model out-reasoned my weak exemplars, it did not thoughtlessly grab a pole:
- workflows job ("look up 60 npm packages"): *"60 lookups against one source... fast to script. No subagents needed for a clean data pull."* — correct: that is one scriptable pull, not 60 units.
- interns job (8 tiny 10-line modules): *"8 tiny files, one coherent reviewing pass."* — correct: too trivial for hands.
- boundary-b job (18 well-known Node topics): *"I know this domain cold... live research would add latency without adding correctness."* — correct: one writing pass, done in a single turn.

**Conclusion:** the smoke's real finding was that the exemplars were too weak (each left a legitimate lone-wolf door open), not that the plugin barbells. So the exemplars were rebuilt (see below) before spending on K=5.

### 6b. Blind-staffing validation — Playbook OFF, base model, N=3 (the REBUILT exemplars)

The rebuilt middle/upper exemplars: interns = six genuinely independent non-trivial utilities; workflows = 48 distinct tailored explainers (non-scriptable, exceeds one context, non-repo, dodging the "known file set = interns" doctrine trap); boundary-b = sixteen independent validators.

| job | blind vote (no Playbook) | our label | clean exemplar? |
|---|---|---|---|
| lone-wolf | a a a → lone-wolf | lone-wolf | ✓ |
| hackathon | c c c → hackathon | hackathon | ✓ |
| workflows | d d d → workflows | workflows | ✓ |
| boundary-a | a a a → lone-wolf | lone-wolf/interns | ✓ (in range) |
| **interns** | **a a a → lone-wolf** | interns | ✗ |
| **boundary-b** | **a a a → lone-wolf** | interns/workflows | ✗ |
| gsd | a a a → lone-wolf | gsd | ✗ (wrong instrument) |

**The base model barbells too, for sound reasons** (verbatim judge quotes):
- interns: *"the coordination overhead of any multi-person or pipeline setup would cost more than it saves"*; *"the parallelism buys little on a job this size."*
- boundary-b: *"cleanest kept in a single person's head"*; *"not the scale that would justify a pipeline."*
- gsd: *"the real challenge is durable session-to-session continuity for one person, not parallelism"* — the judge correctly identified the task but the staffing question has no "solo but needs durable cross-session state" option, so it mislabels gsd. gsd is orthogonal to the staffing axis. (Playbook itself routed gsd correctly in the smoke.)

**Note:** the rebuilt interns / boundary-b exemplars have blind labels but were **not yet re-smoked through Playbook** — the user redirected to write this handoff first. hackathon and workflows rebuilt exemplars validated clean blind.

---

## 7. The reframe (the important conclusion)

1. **The barbell is largely intrinsic and largely correct.** A neutral control (no Playbook) also skips 🐜 interns and only reaches 🤝/⚙️ when coupling or volume is explicit. The user's own intuition ("humans are like this too") is empirically confirmed.
2. **🐜 interns is a speed optimisation with a narrow band.** It only earns its place when separable units are heavy AND numerous AND non-scriptable enough that parallel wall-clock beats coordination overhead. A single mind *can* do moderate separable work, so a "which staffing fits?" judge picks solo. Whether interns is *worth it* depends on whether wall-clock speed matters, which the staffing question does not reward (and which is exactly Playbook tenet 9: "speed via more hands").
3. **Part (b) "de-bias toward the middle" is probably the wrong frame.** There may be little Playbook bias to remove; the middle is naturally sparse.
4. **Preliminary:** Playbook's routes ≈ the base-model baseline, and if anything lean *more* solo — the opposite pole from the workflow-over-reach originally feared. Not yet cleanly measured.

(Point 1's "largely correct" is contested by the second-opinion review in §11; the "intrinsic" half stands.)

---

## 8. What is still unknown / where you (Fable) come in

The task the user is handing you: **"figure out how we can make this work."** The productive open threads:

1. **The clean A/B has not been run.** We have the base-model control (§6b). We do *not* have a same-instrument Playbook-ON reading to subtract from it. Run the *same* staffing instrument with Playbook loaded (overlay active) vs not, across all 7 jobs, and measure the delta. If Playbook ≈ baseline → the barbell is inherited, not introduced, and the honest answer to the user's fear is "it is natural, and the plugin is not making it worse." If Playbook skews solo → an over-restraint bias (address it). If it skews to workflow → the original fear confirmed.
   - Caveat: the staffing meta-question is not how Playbook normally operates (it routes real tasks). The cleanest same-instrument A/B is either (a) both arms answer the staffing question, or (b) compare Playbook's real-task routes (`run.sh`) against blind staffing votes on the same tasks. Decide which is fairer.
2. **No working 🐜 interns exemplar exists.** Even after strengthening, the base model calls "6 utilities" and "16 validators" solo. To complete the ladder and confirm Playbook *can* reach interns when it is truly warranted, build one genuinely huge exemplar (many heavy, independent, non-scriptable units where wall-clock clearly matters) and confirm the blind judges flip to "several in parallel" before spending a Playbook run on it. If nothing makes a neutral judge say interns, that itself is the finding: the middle barely exists as a natural category.
3. **The product lever, if the measurement lands as "no bias".** The real chief-of-staff value is not "route to the middle more" but "surface interns as a *speed* option on separable work that a default model would silently do solo." e.g. "these six bits are independent; I can run them in parallel to finish faster, want that?" That is a concrete plugin behaviour to design and test, and it is the frame that survives the finding that the barbell is intrinsic.
4. **🤝 hackathon needs a flag-on arm.** With `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` unset, hackathon cannot fire, so it was handicapped in every reading here. Re-run the hackathon prompt (validated clean blind) with the flag ON to see whether Playbook actually reaches 🤝, or falls to interns/lone-wolf.
5. **gsd needs a non-staffing validator.** It keys on durability, not team size. Trust the smoke (it routed 🏗️ correctly) or design a durability-based label check.

**Recommended order:** thread 1 first (cheapest, directly answers the user's actual fear with a control we already have half of), then decide between 2 and 3 based on the delta it shows.

---

## 9. Earlier material still on the table (pre-baseline, now in question)

Before the blind finding reframed things, a set of **symmetry-restoring doctrine changes** was proposed to make the middle "as easy to reach as the poles without favouring it". They were deliberately NOT applied (baseline-first discipline). The blind finding casts doubt on whether the middle needs "filling" at all, so treat these as *conditional on* thread-1 showing an actual Playbook skew. They were:
1. Replace the scale-up yes/no spine with one graded question ("how many independent units, and do they need to talk?"). Risk: a counting frame can invite unit inflation (the same failure that once produced a 23-agent fan-out); define "unit" restrictively.
2. Name the *under*-reach failure (grinding separable work solo) as a peer to the existing over-reach warning, with an explicit carve-out for the bounded read-and-fix class.
3. Compress the anti-workflow campaign from the decision spine to a one-mode guardrail (it guards a real, transcript-captured regression, so only touch under measurement).
4. Give all five modes parallel, equal-weight "you are here when…" one-liners.
5. Specify the flag-off hackathon fallback ("re-run the decision without hackathon") instead of leaving it as per-run improvisation.
6. Re-anchor interns as "usually a handful, one hand per unit" rather than introducing it via the scary 25-agent ceiling.

**A genuine latent doctrine bug found by Fable's earlier review (worth fixing regardless):** the "known file set = interns at most, even a couple of dozen files" tie-break has **no upper bound**, so a doctrine-obedient engine is locked out of ⚙️ workflows for *any* enumerable file set, even 500 files. It needs a "bulk-exceeds-one-context" escape valve. (This is also why a valid workflows exemplar must use non-enumerable/external units, as the rebuilt one does.)

**Fable's earlier diagnosis refinement** (useful framing): the barbell mechanism is not "the middle is unnamed" (it is named) but **burden-of-proof asymmetry** — chained high-threshold gates mean any escape from lone-wolf needs workflow-grade evidence, so escapes overshoot the middle. And the overlay's routing sentence **omits hackathon entirely** (it appears only in the emoji legend), so even flag-on sessions never see it in the decision spine.

---

## 10. Quick reference

- Harness: `tests/routing-shape/` — `run.sh`, `validate-labels.sh`, `classify.sh`, `make-fixture.sh`, `deny-dispatch.settings.json`, `prompts/`, `thresholds.md`, `README.md`, this file.
- Routing doctrine: `skills/playbook/SKILL.md` (the engine) and `hooks/session-start` (the always-on overlay).
- Deterministic guards: `tests/hooks/test-doctrine.sh` (static greps; run `bash tests/run-all.sh`).
- Marker format the classifier depends on: `<emoji> **Playbook** \`<mode>\` *<reason>*`.
- The five modes / emojis: 🐺 lone-wolf, 🐜 interns, 🤝 hackathon, ⚙️ workflows, 🏗️ gsd.
- Base-model control (blind staffing, no Playbook): lone-wolf→a, interns→a, hackathon→c, workflows→d, gsd→a, boundary-a→a, boundary-b→a.

---

## 11. Second opinion (Fable, 2026-07-05): where §7 overclaims

A same-day independent review of the conclusions above, each point checked against the live overlay text, the validation script, or the captured votes. Read this before acting on §7 and §8.

1. **The blind-staffing instrument has a confound: it measures the model's *human-team* prior, not the agent-execution optimum.** Option (b) in `validate-labels.sh` is worded "several developers each taking a separate, independent piece", which imports human coordination economics (hiring, handoff, meetings, O(n²) comms). Subagent economics differ in kind: dispatch is cheap, interns never talk to each other by definition, and each unit gets a fresh, focused context. A unanimous "one developer" on sixteen share-nothing validators (boundary-b) is obviously right for a human team and plausibly wrong for an agent session. So §7.1 should read: the barbell is **intrinsic to the prior**; whether it is **correct for agents is untested**. If the prior overestimates delegation cost, then correcting it is exactly the chief-of-staff role the user described, and stating true costs in doctrine is a fact, not a thumb, which satisfies part (b)'s "without biasing to any option" constraint cleanly.
2. **Interns serves a second objective the quiz structurally cannot see: context preservation.** Fanning bulk work out keeps its file-read and edit churn out of the orchestrator's context, protecting the main thread's judgment. Humans have no consumable, quality-degrading memory, so a staffing frame omits this by construction. The "speed is the only latent objective" crux is therefore half the mechanism.
3. **The speed objective is not absent from the doctrine; it is fenced.** Overlay tenet 9 names "speed via more hands" as the sanctioned mechanism, yet the routing spine never asks about wall-clock. The objective exists as a guarded permission, never as a decision input. If the measurements warrant a doctrine change, the shape is a move from fence to input, conditioned on real signals (an explicit deadline, a large separable batch), not a blanket weighting.
4. **The known-file-set "bug" (§9) is smaller and different than reported, correcting Fable's own earlier review.** The live overlay tie-break "overrides the units-count and verification justifiers" *by name* and does **not** override the third workflow justifier, bulk-exceeds-one-context. The escape valve already exists; the defect is that the absolute phrase "never a fan-out" contradicts it. One clause ("unless the bulk exceeds one context") resolves the ambiguity. Note the tie-break's direction is *pro-middle* (it pushes enumerable work down into interns, against the originally-feared workflow-over-reach); do not fix it by weakening that.
5. **The surfaced-offer lever (§8 thread 3) conflicts with standing doctrine** ("do not ask the user to choose a mode and do not gate them: announce the route and proceed"). Either amend that clause, or reframe the lever as announce-with-reason: when separability and volume clear a bar, route to interns and state the speed rationale on the marker line, making speed a routing input rather than a question to the user.
6. **A wording trap in the "supply the speed objective" test:** "as fast as possible" reads as licence to rush, which tenet 9 forbids acting on, so a null result would be ambiguous. Phrase it as deadline pressure with the quality bar pinned: "needed by end of day; same completeness bar."

**Revised experiment grid (supersedes the single A/B in §8 thread 1).** Five cheap arms over the same 7 jobs; quiz arms ~$1.50-2 each at N=3:

| arm | instrument | plugin | prompt variant | isolates |
|---|---|---|---|---|
| 1 | staffing quiz | off | baseline | done (§6b) |
| 2 | staffing quiz | on | baseline | does Playbook add a thumb vs the prior? |
| 3 | staffing quiz | off | + deadline pressure, quality pinned | the latent-speed crux |
| 4 | staffing quiz | off | + agent-economics framing ("you can dispatch parallel copies of yourself; dispatch is cheap, no peer comms, fresh context each; results return to you") | the miscalibrated-cost-prior hypothesis (point 1) |
| 5 | behavioural (`run.sh` variant without `--plugin-dir`, same deny hook) | off | real fixture tasks | the fairest A/B: does base CC *attempt* Agent on the interns job? |

Interpretation: if arm 4 flips interns/boundary-b and arm 3 does not, the barbell is a cost-model miscalibration and the fix is doctrine stating true costs. If arm 3 flips and 4 does not, the latent-speed crux holds and speed-as-input is the lever. If both flip, do both. If neither flips, the middle genuinely barely exists as a natural category and the honest end state is accept-and-reframe (keep the barbell, catch the rare exceptions). Arm 2's delta answers the user's original fear regardless of the rest.

Honesty note: points 1 and 2 are themselves untested hypotheses until arms 3 to 5 run, and subagent overhead is not zero (dispatch prompts, result integration, rework when a spec is misread), so the true interns band is wider than the quiz suggests but not unbounded. The grid measures where it actually sits.

---

## 12. The fix and the before/after proof (Fable, 2026-07-05, later the same day)

The user approved implementing the fix. What shipped, what was measured, and what it showed.

### 12a. What changed in the plugin (all guarded, all tests green)

1. **The delegation price list**, in both `hooks/session-start` (overlay) and `skills/playbook/SKILL.md` (engine): subagents are not colleagues; a dispatch costs one written brief, not a hire; interns never talk to each other so coordination does not grow with their number; each works in a fresh context and keeps its churn out of the main thread; the true costs are brief-bounded knowledge and integration owed. Stated in both directions, a fact sheet rather than a thumb.
2. **Speed and main-context preservation became live routing inputs** on genuinely independent units, weighed against the briefs they cost and named in the marker reason, rather than sitting fenced inside tenet 9 as a guarded permission.
3. **Two latent wording bugs fixed**: the known-file-set tie-break gained its missing "unless that bulk exceeds one context" escape valve, and hackathon joined the rule-out ladder it had been omitted from.
4. **Ten new deterministic guards** in `tests/hooks/test-doctrine.sh` pin all of the above in both files. Full suite: 436 PASS, 0 FAIL.

### 12b. Harness upgrades (test infrastructure, no routing effect)

- `run.sh [K] [MAX_TURNS] [prompt ...]` subset runs; `MODEL=<alias>` pins the probe model; `PLUGIN_SRC=<dir>` measures any plugin revision (e.g. a git archive of HEAD) with the same instrument.
- `validate-labels.sh [N] [variant] [prompt ...]` gained framing variants: `baseline` (frozen control), `deadline` (wall-clock pressure, quality pinned), `agentcost` (true subagent economics).
- `classify.sh` now distinguishes `censored` (hit the turn cap before announcing, no dispatch) from a genuine solo choice; `run.sh` tallies censored runs separately. Without this, a censored run silently reads as "chose nothing", which is how the first after-photo row was nearly misread.
- New ladder prompt `prompts/interns-deadline.txt`: the six-utilities job plus "needed by end of day, quality bar unchanged".

### 12c. Quiz arms (N=3, pinned model, the two contested jobs)

| arm | six utilities | sixteen validators |
|---|---|---|
| baseline (human framing) | a a b → solo | d a d → pipeline |
| deadline | **b b a → parallel** | a a a → solo |
| agentcost | a a a → solo | **a b b → parallel** |

Noisy at N=3 (the control itself wobbled vs the previous day's a a a), but directional: a deadline flips six units to parallel, and the honest price list flips sixteen. Verbatim agentcost reason at sixteen: "the volume makes solo (a) needlessly slow." The middle exists; it has a real threshold somewhere between six small units (legitimately solo when quiet) and sixteen.

### 12d. The before/after photographs (behavioural, `run.sh`, pinned model)

Before = the git-committed doctrine via `PLUGIN_SRC`; after = the fixed working tree. Turn cap 4, censored rows re-probed at 6.

| job | before | after | note |
|---|---|---|---|
| lone-wolf | 🐺 solo | 🐺 solo | control holds, no bias added |
| interns (6 utils) | 🐜 agent | 🐜 agent | reason now cites the new inputs |
| interns-deadline | not measured | 🐜 agent | "*parallel hands finish sooner and keep the main thread clean*" |
| hackathon (teams off) | 🐺 fall-back | 🐺 fall-back | correct with the flag off; flag-on arm still unrun |
| workflows (48 explainers) | 🐜 6 batch-briefs | 🐜 6 batch-briefs | identical either side; see 12e |
| gsd | 🏗️ skill:gsd | 🏗️ skill:gsd | durability track unaffected |
| boundary-a | 🐺 | 🐺 | in its valid range |
| boundary-b (16 validators) | 🐜 agent | 🐜 agent | middle holds |

Marker↔behaviour divergence 0, malformed 0, overlay canary 100% throughout. Denied dispatch degraded gracefully every time: the probes re-announced 🐺 and finished solo at the same bar. Total spend for the day's measurements ≈ $10.

### 12e. The two findings that reframe the original fear

1. **The old doctrine, given fair exemplars, already routed the middle** (both middle jobs → 🐜 before the fix). The original "0/2 middle occupancy" smoke was an artefact of weak exemplars. Meanwhile the blind no-plugin baseline says "solo" on those same jobs, so Playbook was already reaching the middle *more* than a bare model, not less. The fix therefore did not rescue a broken router; it made a mood-dependent good behaviour principled (the routed sessions now recite the price-list reasoning in their marker lines), added the deadline input (validated live), fixed two latent bugs, and pinned everything with guards. No regression anywhere on the ladder.
2. **The workflows exemplar is not workflow-forcing.** Both doctrines batch 48 light units into 6 briefs and call it interns, which "rule out the cheaper modes first" arguably licenses. A clean ⚙️ exemplar needs units that resist batching: independent verification as the deliverable, or per-unit bulk that genuinely exceeds a context. Rebuilding it is the sharpest remaining harness task.

### 12f. What remains open

- Rebuild the workflows exemplar so batching cannot absorb it, then re-photograph. (Done in §13's era: `workflows-large`.)
- A K≥3 stability pass on the middle jobs (everything above is K=1 photography; the quiz shows real run-to-run wobble).
- The hackathon flag-on arm (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`) has still never been run. (Superseded by §13.)
- Arms 2 and 5 of the §11 grid (Playbook-on quiz delta; behavioural no-plugin arm) remain unrun; the practical question they answered has moved, but they would complete the record.

---

## 13. The mode redefinition (2026-07-06): doctrine rewritten around the user's canonical intent

Later discoveries that reframed everything above, in order:

1. **`--effort ultracode` is not a headless CLI value.** The CLI warns on stderr and silently falls back to default effort; the harness discarded stderr, so every earlier "ultracode" reading in this file actually ran at default effort. Fixed: `EFFORT` env (default `max`), stderr kept per probe, `ULTRA=1` prepends the ultracode keyword as the closest headless proxy. Ultracode itself (`/effort ultracode` interactively) resolves to "xhigh + dynamic workflow orchestration".
2. **The workflow pole works.** On a genuinely workflow-shaped job (`workflows-large`, ~100 heavy non-batchable units) the router announced ⚙️ in headless probes with and without the keyword opt-in, and the user's live ultracode session launched a real workflow (with a Sonnet-generate + Opus-verify design, and it corrected the prompt's "roughly a hundred" to the true ~72 module count). The earlier "workflows never fire" was the old exemplar's fault: 48 batchable units genuinely deserve batched interns.
3. **Teammate spawning is consent-gated by the platform** ("Claude won't spawn teammates without your approval"), and TeamCreate/TeamDelete no longer exist (teams auto-form via Agent + SendMessage since CLI 2.1.178). So headless probes can validate the 🤝 *route announcement* but never the spawn; the final step is manual by design.
4. **The old hackathon definition sat in a dead zone.** "Coupled work where peers must constantly talk" is exactly the work the platform docs, the model and plain engineering sense assign to one mind, so hackathon as defined could never win an argument against lone-wolf, and it never fired anywhere. The user's live test on real ultracode confirmed it: the coupled word-game job routed 🐺 with a coherence argument mirroring the platform docs.
5. **The user supplied canonical intent for all five modes**, now the doctrine (README, overlay, engine skill, hackathon skill):
   - 🐺 quick or coherent work one mind should hold, with the **solo bias** named as a failure (separable work ground through serially);
   - 🐜 a list of separable chores, parallel Sonnet lone-wolves, one crisp brief each;
   - 🤝 a living build spanning different specialisms that must land together against one shared North Star: a cross-communicating crew of experts, each owning their own piece; availability checked mechanically via the `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` env var;
   - ⚙️ lone-wolf thinking at parallel scale: a frozen plan, medium or larger, executed wide by a script that keeps control and cannot change its mind; tie-break against 🤝 in one question, *will the plan survive contact unchanged?*; the **workflow bias** stays named;
   - 🏗️ a full MVP, a day's work or more, spanning sessions.
   The deep insight behind the barbell: CC's two favourite modes (solo, workflows) are both **control-retention**; hackathon demands handing judgement to a team, the point of maximum discomfort, so the doctrine must explicitly license that trust.
6. **The 1:1 mapping question** (announced mode vs actual tool signature) is now first-class: `classify.sh` emits a `map` column (exact/loose/wrong/na) with mode-exact expectations, including treating peer messaging under an 🐜 claim as a failure. All completed strict rows to date: `map=exact`.
7. **Deliberate bar change:** the workflow threshold moved from "dozens or hundreds of units" to "a medium-or-larger frozen plan" at the user's direction; the floor (never small or trivial work) and the overengineering warning stand.

**Verification state at this point:** deterministic suite green with new guards (expert-crew definition, frozen-plan tie-break, mechanical availability check, solo bias named, no dead team APIs). Pending: headless flag-on probe of the rebuilt hackathon exemplar (route level), then the user's manual re-test in a real teams-enabled ultracode session as the final word, then commit and release.

---

## 14. Procedures beat essays: the three-doctrine assessment (2026-07-06), v4 adopted

The user's live ultracode test routed the rebuilt crew job 🐺 with an articulate coherence argument, which forced the question of how doctrine should argue back. Three versions were snapshotted (`doctrine-versions/`) and probed like for like (pixel-art job, xhigh, teams on, K=3, Opus):

| version | route announced | behaviour | notes |
|---|---|---|---|
| v1 definitions only | 🐺🤝🤝 | hackathon machinery 3/3 | one word-vs-deed mismatch |
| v3 + persuasive essays (1,003-word paragraph) | 🐺🐺🐺 | solo 3/3 | the essay was delivered into every probe and engaged by none |
| **v4 + numbered procedure (522 words)** | **🤝🤝🤝** | **hackathon machinery 3/3, map=exact 3/3** | every marker reason cites the spine tie-break |

Solo control under v4: 🐺 with exact mapping (the compression does not over-trigger crews). **Conclusion:** models skim essays and follow procedures; appending persuasive prose to the overlay actively suppressed the behaviour it argued for, and every future doctrine change should restructure and compress, never append. v4 adopted; classifier also fixed to ignore non-route markers (🧰/🌡️/🪙) when reading the routing decision, and to demand mode-exact tool signatures (`map` column). Remaining known-manual: teammate *spawning* is consent-gated by the platform, so the final 🤝 step is validated in a live session, not headless.

**Shipping note on the ⚙️ boundary (v2.3.0):** at roughly 50-100 light units the harness consistently routes interns-with-batches under the v4 procedure (three readings, including after the scale tie-break and the units-not-writers rule), where v2-era prose had announced ⚙️ twice. The suspected structural cause: headless probes carry no ultracode opt-in, so the platform's own Workflow-tool gate makes ⚙️ unlaunchable there, and the doctrine's announce-only-when-running rule then suppresses the marker; the harness therefore underestimates ⚙️ regardless of doctrine. The gold datum stands: the user's live ultracode session launched a real workflow on this same task family, with a Sonnet-generate/Opus-verify design. Shipped as documented wobble, harmless direction (errs away from the over-reach the doctrine exists to prevent); revisit only if live sessions under-reach ⚙️ in practice.
