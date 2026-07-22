---
description: Playbook review panel: four independent reviewers (architect, CTPO, junior, devil's advocate) over a plan, design doc, diff or PR.
---

A bare `/review-panel` alias can be installed by `/playbook:setup`; this `/playbook:review-panel` form always works, and setup leaves the bare name alone if another tool already owns it.

Invoke the `playbook:review-panel` skill.

Ask the scope questions interactively before launching anything. Do not infer the scope from context and proceed, even when the artefact under review seems obvious: the exclusions and the out-of-scope answer are the parts that cannot be guessed, and getting them wrong wastes four high-effort agents.

Subject, if given: $ARGUMENTS
