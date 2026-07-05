---
name: brainstorming
description: Auto-triggers on fuzzy, open-ended, or ideation-first prompts ("let's explore", "what should we build", "I'm not sure how to approach", "help me think through") and on /brainstorming. Explores options, surfaces trade-offs, asks sharp batched questions, paints the picture, and converges to a clear shape before handing off into the engine's routed mode. Does not write a design-doc artefact unless asked, and never starts building inside brainstorming.
---

# Brainstorming

## Overview

Brainstorming is the explore-and-converge phase that runs before routing. It establishes shared understanding in-conversation: what the work actually is, which trade-offs matter, and what shape the solution should take. Once the shape is clear, it hands off cleanly into the routing engine and the work begins.

Announce at entry:

```
🧭 **Playbook** `brainstorming` *<one-line summary of what is being explored>*
```

## When it triggers

**Auto:** the prompt is fuzzy, open-ended, or explicitly ideation-first: the user says "let's explore", "I'm not sure how to approach this", "what should we build", "help me think through", or otherwise opens with a question rather than a specification. If the intent is clear and buildable immediately, skip brainstorming and route directly.

**Explicit:** `/brainstorming` (alias `/playbook:brainstorming`, for when another tool owns the bare name).

## The method

### 1. Explore

Map the option space honestly. For each credible path, state what it enables, what it costs, and what it forecloses. Do not advocate prematurely; the goal at this stage is breadth, not convergence. Surface the non-obvious alternatives alongside the obvious ones.

### 2. Ask sharp questions

Batch all clarifying questions into a single ask, early. Do not drip-feed one question at a time. Ask only questions whose answers would materially change the direction; skip anything derivable from context or resolvable by a sensible default. Fewer, sharper questions are better than an exhaustive list.

### 3. Paint the picture

Once enough signal exists, describe what the chosen direction actually looks like when it works: what the user experiences, what the code structure implies, what the integration points are, what can go wrong and how. Make the shape tangible.

### 4. Converge

Drive towards a clear enough shape that the routing engine can take over. The shape does not need to be a detailed spec; it needs to be specific enough that "separable or not" and "durable or not" can be answered. State the convergence explicitly: "the shape is X; routing to the engine now."

## Red Flags

**Never:**
- Force a design-doc artefact. Brainstorming produces shared understanding in-conversation; it does not write a document unless the user asks for one.
- Drip-feed questions across multiple turns. Batch them once, early.
- Start building inside brainstorming. The first line of code is written after hand-off, not before.
- Stay open-ended indefinitely. If the user signals readiness or the shape is clear, converge and hand off.
- Skip brainstorming when the prompt is genuinely fuzzy just because building feels faster.

## Integration

After convergence, hand off into `playbook:playbook` (the routing engine). The engine receives the clarified shape and routes on separability and durability as usual. The North Star derived during brainstorming travels forward as the session North Star.

If the user wants to capture the outcome as a document, offer to write one after convergence, not during. Writing mid-explore interrupts the thinking before the shape is clear.
