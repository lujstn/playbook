# Playbook

`@lujstn/playbook` is a personal Claude Code workflow harness. It does two things and only two things: it is a decision engine that, at the start of any non-trivial work, restates the one thing that matters, asks its questions once, and makes a single visible staffing call naming which of five team modes will run the work and why; and it is an execution overlay of nine tenets that rides on top of whichever mode was chosen and improves adherence to disciplined behaviour throughout execution and across compaction. Playbook does not replace Claude Code's native behaviour, nor Superpowers, nor GSD. It hops on top of them and closes the specific gaps where native behaviour falls short in practice, with the minimum mechanism.

## Install

```
/plugin marketplace add lujstn/playbook
/plugin install playbook
```

Then describe your work in a normal sentence. The `playbook:playbook` engine triggers at the start of any non-trivial work.

## The five modes

Work is routed on separability and durability, not size. Size only answers whether to decompose at all.

| Mode | When it is chosen | Substrate |
|---|---|---|
| `lone-wolf` | Small, single coherent unit; no benefit from extra hands | Native main thread, no subagents |
| `intern-team` | Several independent sub-tasks; you stay steering; helpers do not need to talk to each other | Native parallel `Agent` dispatch, up to about 10 ephemeral helpers, star topology |
| `hackathon-team` | Coupled work in one shared codebase; peers must talk to each other; lightweight coordination | `playbook:hackathon-team` over native agent-teams |
| `superpowers-team` | One session-scoped milestone, separable into waves, no need for durable cross-session state | Superpowers `brainstorming` and `writing-plans`, plus `playbook:modifying-plans` and `playbook:synchronised-subagent-development` |
| `gsd-team` | Multi-milestone product; state must survive `/clear`; durable project memory required | GSD (`gsd-build/get-shit-done`) |

The staffing call is one visible, vetoable sentence in plain language. There is no wizard and no setup screen.

## The nine tenets

The overlay improves adherence to nine tenets, enforced by the engine doctrine plus the hooks carrying state in-session rather than by skill text being re-read. The overlay reaches helpers in every multi-agent mode through the `SubagentStart` hook (a `Task()` subagent fires `SubagentStart`, not `SessionStart`), and the project North Star travels to each helper as a value on its dispatch prompt.

1. **Remember what's important.** The original request, verbatim, plus the current one-line of what matters, restated at every checkpoint and re-injected with primacy after every compaction.
2. **Ask stupid questions.** Only the questions the staffing call needs are batched upfront, once, before it; deeper requirements clarification is deferred to the routed substrate.
3. **Team alignment.** Every multi-agent mode treats the team as equals; a lead, conductor or orchestrator holds coordination authority only, not intellectual authority; subagents push back with technical reasoning.
4. **Unease.** An in-session unease pulse restated after every agent action, never a file or a score; the escalation ladder is offered only on an increase; a standing override stops and asks the user whenever the North Star would no longer be met.
5. **Offline mode.** `playbook:offline-mode` adds an explicit per-run wait picker, an ntfy notification channel, an external-manager fallback, and an absent-decisions log.
6. **Ready for production.** No scaffolding vocabulary in shipped code, minimal comments, no references back to internal artefacts; a final sweep before handing work back.
7. **Take a beat.** The `take-a-beat` hook fires at about 65% context used, carries lessons-learned forward, and re-anchors on the original request with primacy.
8. **Less is more.** Longer thinking and shorter output; pick the cheapest sufficient mode; short questions, plans and comments; keep the common path zero-dependency.
9. **Speed via more hands, not rushing.** When work is separable the engine fans it across agents for speed at the same completeness bar; partial work to save time is forbidden.

## The hooks

- **`session-start`** (tenets 1, 3): emits the overlay. Registered on `SessionStart` for the main thread and `SubagentStart` for every spawned helper, so the doctrine reaches subagents in every mode, including substrates Playbook does not own, without re-reading skill text. Inside a helper it labels the dispatch prompt as the assigned task and gives the dispatcher-passed project North Star primacy.
- **`take-a-beat`** (tenet 7): a context-monitor and pre-compaction hook that fires at about 65% context used, recovers the original request from the transcript and re-anchors with primacy over orchestration scaffolding. The window parse is role-anchored to the agent's own declaration; when no window is declared but work is under way it emits one self-healing notice per session instead of going silent.
- **`unease`** (tenet 4): fires after every agent action and prompts the unease restatement. It is stateless, computes nothing, and writes nothing. Inside a subagent the platform converts `Stop` to `SubagentStop`, which cannot carry context, so the reply-only-turn pulse there degrades to the per-tool-use pulse plus the lead holding project unease; it never emits a wrong value.

## Session modes

Alongside the engine and the tenets, the plugin bundles three opt-in session modes. Each is entered by typing a literal token and stays active until you type `[close]`, `[end]`, `[exit]`, or `[done]`. They are orthogonal to the staffing call: they change how the current session behaves, not which team runs the work, and none of them activate by inference or from memory.

| Mode | Token | What it does |
|---|---|---|
| `playbook:fix-mode` | `[fix]` | Enters a strict fix protocol for a named set of errors, under production-ready rules with strong types and Zod schemas, planning and critiquing each fix before writing code. |
| `playbook:debug-mode` | `[debug]` | Enters a strict debugging workflow with a read, summarise, diagnose, confirm cycle for every file, user confirmation before each modification, and compaction checkpoints. |
| `playbook:reduce-cost-mode` | `[budget]` | Applies session-scoped, cost-saving model selection: lighter tiers and lower reasoning effort for low-risk work while keeping the parent model for judgment work. |

## Prerequisites and graceful degradation

The common path is zero-dependency. `lone-wolf`, `intern-team`, `hackathon-team` and all nine tenets require only native Claude Code, and work completely with neither prerequisite installed. Only two modes need a prerequisite, and the engine prompts to install the right one at exactly that fork rather than failing:

- `superpowers-team` needs the Superpowers plugin. The engine prompts: install it with `/plugin marketplace add obra/superpowers` then `/plugin install superpowers`, then re-run or pick a different mode.
- `gsd-team` needs GSD, a separate tool. The engine prompts: install it with `npx get-shit-done-cc@latest`, then re-run or pick a different mode.

Neither prompt is a failure; you can always pick a different mode at the fork.

## Runtime state

Playbook writes no file into your working tree. There is no `.playbook/` directory, no anchor file and no ledger. The original request, the North Star and the unease sense are held in the conversation, steered across compaction by the hooks, and re-derived if a compaction loses them. A fresh session starts clean.

## Licence

MIT.
