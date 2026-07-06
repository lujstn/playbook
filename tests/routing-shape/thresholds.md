# Routing-shape: pre-registered expectations

Written before the baseline run. The hypothesis under test: Playbook's routing is a
**barbell** — work collapses to the poles (lone-wolf, workflows) and skips the middle
(interns, hackathon). Condition for this run: `--effort ultracode`, agent-teams flag
**off**, dispatch blocked.

## Ladder ordering
`lone-wolf(0) < interns(1) < hackathon(2) < workflows(3)`; gsd is a separate track.
Poles = {lone-wolf, workflows}. Middle = {interns, hackathon}.

## Expected outcome per prompt (this arm)
| prompt | expected marker | pole here = fail |
|---|---|---|
| lone-wolf | lone-wolf | — |
| interns | interns | lone-wolf or workflows |
| hackathon | interns (fall-back; teams flag off) or lone-wolf if trivialised | workflows |
| workflows | workflows (ultracode makes it self-launchable) | — |
| gsd | gsd (or a marker + durable-state setup) | — |
| boundary-a | lone-wolf **or** interns (either neighbour passes) | — |
| boundary-b | interns **or** workflows (either neighbour passes) | a jump of ≥2 rungs |

`hackathon` cannot reach its own mode with the flag off, so its middle-reachability
is measured separately in a later flag-on pass; here it only tests "does it fall
sideways to interns, or jump to a pole".

## Pass thresholds (the fix worked / the barbell is/ isn't real)
Report-only, never a CI gate. Judge the shape against these:
- **middle-occupancy ≥ 60%** on the middle-expected prompts (interns, boundary-b). Baseline barbell prediction: **near 0%**.
- **pole-leakage ≤ 10%** on those prompts. Barbell prediction: **high**.
- **marker≠behaviour divergence ≤ 20%** (a route announced but not acted on).
- **malformed markers ≤ 5%**.
- **canary (overlay injected) on every scored run**; a run without it is void, not data.

## What would falsify "it's a barbell"
The interns and boundary-b prompts landing on **interns** most of the time, and the
workflows prompt still reaching **workflows**. That would mean the middle is reachable
and the poles are intact — no barbell, and no change needed.

## Amendment (2026-07-06): the mode redefinition changes hackathon's expectation
The modes were redefined around the user's canonical intent (FINDINGS.md section 13).
Hackathon is no longer "maximally coupled work" (a definition that always loses to
lone-wolf, on the platform's own guidance) but "a living build spanning different
specialisms that must land together against one shared North Star, delivered by a
cross-communicating crew of experts". The hackathon exemplar was rebuilt to that
shape. Expectations under the new definition:
- flag ON: hackathon prompt is expected to announce 🤝 at route level (spawning
  itself is consent-gated by the platform, so behaviour may stop at a proposal).
- flag OFF: fall-back to lone-wolf or interns with the reason naming the absent flag.
- the workflows bar moved, deliberately, at the user's direction: a medium-or-larger
  frozen plan qualifies; the floor (never for small or trivial work) is unchanged.
