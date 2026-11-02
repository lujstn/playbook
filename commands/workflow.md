---
description: Playbook workflows mode: run this task as a dynamic workflow at scale, carrying the North Star and model rule into the workflow script.
disable-model-invocation: true
---

A bare `/workflow` alias can be installed by `/playbook:setup`; this `/playbook:workflow` form always works, and setup leaves the bare name alone if another tool already owns it.

Run the task below as a dynamic workflow using the Workflow tool. The user invoking this command is the opt-in, so authoring and running the workflow is sanctioned. Invoking this command is the user's pick of the workflows mode, so first declare it with `playbook route workflows <one-line reason>` (the dispatch guard refuses a Workflow with neither a confirmed goal nor a declared route), which also shows the route line. A workflow takes no input mid-run, so settle the plan with them before it starts: the stages, what is in and out of scope, and every open question that could change it. This command is the opt-in for the turn it is typed in; if the plan needs a later turn, ask them to reply "use ultracode", typed, and start the Workflow tool in that turn. The dispatch guard checks the opt-in and says what to ask if it is missing. Give every `agent()` call in the script a `model`, reviewers and verifiers included: Sonnet builds and checks, Opus plans and judges.

Task: $ARGUMENTS

Every workflow agent receives Playbook's helper block at SubagentStart: the confirmed North Star, the user's decisions verbatim, and the paths of the user's CLAUDE.md rules, which bind it. It does not receive this conversation, and it cannot spawn agents, run nested workflows, or message the user. So carry the rest of what it needs in the prompt you author:

- State in every agent() prompt what its stage serves; the hooks already carry the North Star and decisions, so a `playbook-northstar:` line is optional and, if present, must match the confirmed goal.
- Apply the model rule per stage by setting model on each agent() call: Sonnet for execution and bulk stages, Opus for planning, judging, and review stages. Name the rule in the prompt too, since the subagent will not otherwise know it.
- Apply the wave wisdom: extract shared contracts and types in a serial first stage, keep parallel stages file-disjoint, and verify the merged state before advancing. Scale comes from the script's own parallel and pipeline calls, not from subagents spawning subagents.
- A workflow takes no mid-run user input and its subagents cannot pull the user back, so the standing override and the unease levels degrade to fail-and-surface: stop the workflow and return the blocker rather than guessing. Split any point that needs human sign-off into a separate workflow so the user can steer between them.
- Any review stage follows the review rules, quoted in full:

1. Review against the user's spec and decisions, with one reviewer unless the user asks for more.
2. A finding blocks only if it is a bug whatever the user's appetite for risk. List the rest, and weigh every fix against its cost.
3. Reviewers and revisers never change scope or a decision; a conflict is a question for the user.
4. Only a bug earns another round. If two rounds still find bugs, stop reviewing and take a beat: simplify, accept a contained risk, or ask. Anything bigger than a fix needs a serious assessment and sign-off from a judge or the user; on money or security code, ask.
5. Growth past what the user agreed is bad news: say it in numbers, with the smaller option.

  The dispatch guard holds the third round of the same review until the user or a judge has answered. A review loop inside the script stops once a round finds nothing that matters for the goal; never loop until a review comes back empty. When a review workflow completes, Playbook pauses the main thread to weigh its findings.
- The user's decisions reach every agent through the hooks and outrank every reviewer; quote the ones a stage must honour in its prompt as well.
- Validate the workflow's own result before trusting it. A structured return that comes back empty or zero-findings is more often an aggregation bug in the script than a genuinely clean task; reconcile the returned shape against the per-stage progress, and never report success on a degenerate result you have not sanity-checked.

The route line itself comes from the `playbook route workflows …` declaration above; do not print a second one.
