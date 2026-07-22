---
name: time-rule
description: Always-on time-estimation doctrine; never entered or exited, never inferred off. Agent intuition for its own work runs about ten times too high; form the human-engineer estimate, divide by ten, give a range. External-system waits and already-observed command durations are never divided. This skill is the detailed reference; the rule itself is stated in the overlay for every agent and subagent.
user-invocable: false
---

This is always-live doctrine, not a mode. It is carried in the session overlay and the SubagentStart overlay so every agent, subagent, and workflow stage estimates under it automatically. Nothing here is turned on or off.

### The rule

Form the ordinary human-engineer estimate, divide by ten, and present a range: a two-hour feel becomes 10-15 minutes.

### Why a scalar works

An agent's felt estimate pattern-matches its training data, which is humans estimating human effort; execution runs at machine speed. Measured on 2026-07-22: a five-step plan estimated at about 2 hours landed in 12m52s, and the bias was uniform across subtasks, with each prose-anchored step running 5-10x over and the total 8.5x. A uniform multiplier means the intuition ranks tasks correctly relative to each other and is wrong by a constant absolute factor, and a constant bias takes a scalar correction rather than an estimation framework. The same incident showed that the one accurate step estimate was anchored to a named command with a known duration, which is why observed durations are exempt below.

### What is never divided

1. **Waits on external systems.** CI runs, deploys, rate-limited APIs, paid crawl or LLM pipelines: these are items times rate plus overhead, and hours are a legitimate answer. The divisor corrects felt effort, and these are arithmetic, not feel.
2. **Commands whose duration has been observed.** A test suite or build already timed in this repo is added at face value.
3. **Human turnaround.** Report user round-trips as a count, never a duration; the user's latency is not the agent's to estimate.

### Recalibration

When an actual lands outside the stated range, say so plainly rather than absorbing the miss, and update the divisor wherever the user keeps it written down, such as a CLAUDE.md rule or a project memory. The constant stays honest only if misses surface.
