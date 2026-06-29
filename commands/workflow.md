---
description: Playbook workflows mode: run this task as a dynamic workflow at scale, carrying the North Star and model rule into the workflow script.
disable-model-invocation: true
---

The `/pb-workflow` form is canonical and collision-proof; use it if another tool defines `/workflow`. Behaviour is identical.

Run the task below as a dynamic workflow using the Workflow tool. The user invoking this command is the opt-in, so authoring and running the workflow is sanctioned.

Task: $ARGUMENTS

A workflow subagent receives only its own prompt. It does not receive the project North Star, CLAUDE.md, Playbook's overlay, or the session hooks, and it cannot spawn agents, run nested workflows, or message the user. So carry everything it needs in the prompt you author:

- Put the one-line project North Star verbatim at the top of every agent() prompt the script authors, and state that the stage serves it.
- Apply the model rule per stage by setting model on each agent() call: Sonnet for execution and bulk stages, Opus for planning, judging, and review stages. Name the rule in the prompt too, since the subagent will not otherwise know it.
- Apply the wave wisdom: extract shared contracts and types in a serial first stage, keep parallel stages file-disjoint, and verify the merged state before advancing. Scale comes from the script's own parallel and pipeline calls, not from subagents spawning subagents.
- A workflow takes no mid-run user input and its subagents cannot pull the user back, so the standing North-Star override and the escalation ladder degrade to fail-and-surface: stop the workflow and return the blocker rather than guessing. Split any point that needs human sign-off into a separate workflow so the user can steer between them.

Announce once the workflow is actually running: a single line of the form ⚙️ Playbook · workflows: <one-line reason>.
