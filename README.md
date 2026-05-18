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

The overlay improves adherence to nine tenets, enforced by the engine doctrine plus the two hooks and the pinned anchor file rather than by skill text being re-read.

1. **Remember what's important.** The original request, verbatim, plus the current one-line of what matters, restated at every checkpoint and re-injected with primacy after every compaction.
2. **Ask stupid questions.** All clarifying questions are batched upfront, once, before the staffing call; ask as many as needed until confident.
3. **Team alignment.** Every multi-agent mode treats the team as equals; a lead, conductor or orchestrator holds coordination authority only, not intellectual authority; subagents push back with technical reasoning.
4. **Uncertainty.** An append-only unease ledger, gated by the confidant test, escalating up the ladder on three callout shapes; a standing override stops and asks the user whenever the North Star would no longer be met.
5. **Offline mode.** `playbook:offline-mode` adds an explicit per-run wait picker, an ntfy notification channel, an external-manager fallback, and an absent-decisions log.
6. **Ready for production.** No scaffolding vocabulary in shipped code, minimal comments, no references back to internal artefacts; a final sweep before handing work back.
7. **Take a beat.** The `take-a-beat` hook fires at about 65% context used, carries lessons-learned forward, and re-anchors on the original request with primacy.
8. **Less is more.** Longer thinking and shorter output; pick the cheapest sufficient mode; short questions, plans and comments; keep the common path zero-dependency.
9. **Speed via more hands, not rushing.** When work is separable the engine fans it across agents for speed at the same completeness bar; partial work to save time is forbidden.

## The two hooks

- **`take-a-beat`** (tenet 7): a context-monitor and pre-compaction hook that fires at about 65% context used, re-reads the anchor and lessons ledger, and re-anchors on the original request with primacy over orchestration scaffolding.
- **`uncertainty`** (tenet 4): fires at the end of every turn and asks the agent one thing, whether anything should go in the unease ledger. The expected answer is almost always no; logging is the rare exception, gated by the confidant test. It writes a wall-clock timestamp on any entry added, performs no computation, and maintains no score.

## Prerequisites and graceful degradation

The common path is zero-dependency. `lone-wolf`, `intern-team`, `hackathon-team` and all nine tenets require only native Claude Code, and work completely with neither prerequisite installed. Only two modes need a prerequisite, and the engine prompts to install the right one at exactly that fork rather than failing:

- `superpowers-team` needs the Superpowers plugin. The engine prompts: install it with `/plugin marketplace add obra/superpowers` then `/plugin install superpowers`, then re-run or pick a different mode.
- `gsd-team` needs GSD, a separate tool. The engine prompts: install it with `npx get-shit-done-cc@latest`, then re-run or pick a different mode.

Neither prompt is a failure; you can always pick a different mode at the fork.

## Runtime state

Playbook maintains two engine files inside the working project, both in a `.playbook/` directory at the project root:

- `.playbook/anchor.md`: the original request verbatim, the current one-line of what matters, a running lessons-and-wrong-turns ledger, and the next work.
- `.playbook/uncertainty-ledger.md`: the append-only unease ledger for tenet 4.

This location is deliberately distinct from GSD's `.planning/` so the two harnesses never collide. You should add `.playbook/` to the consuming project's `.gitignore`; the engine offers to do this once via `AskUserQuestion` on first use. That one-time offer is the only place this lives: it is documentation plus a single engine offer, never a per-turn hook side-effect.

## Licence

MIT.
