---
name: setup
description: Checks a machine once for things that fight or starve Playbook, plugins whose hooks re-prompt on Stop or inject context-limit warnings, a missing jq, unconfigured offline notifications, and offers consented fixes one at a time. Runs on the first /playbook on a machine, when the enabled plugin set has changed since the last check, when invoked directly as /playbook:setup, or whenever the user asks for a conflict or setup check.
---

# Setup

## Overview

A one-time (and on-demand) check that the machine Playbook just landed on is not fighting it. The output is a short list of findings with evidence, each with an offered fix you apply only with the user's consent, one at a time. The bias is to keep things: most plugins coexist with Playbook perfectly well, and a setup pass that tells people to rip out half their plugins would be the exact over-reach Playbook preaches against.

**Announce at start:** "🧰 **Playbook** `setup` *checking this machine for plugin conflicts and prerequisites*"

## Step 1: gather the facts

Run these read-only checks. If `jq` is missing, that is finding number one: offer to install it first (see step 4), then continue the audit with it.

```bash
command -v jq && uname -s
jq -r '.enabledPlugins | to_entries[] | select(.value) | .key' ~/.claude/settings.json
```

For each enabled plugin, resolve its install path and read its hook registrations:

```bash
jq -r --arg p "name@marketplace" '.plugins[$p][0].installPath // empty' ~/.claude/plugins/installed_plugins.json
cat "<installPath>/hooks/hooks.json"
```

Where a hooks.json registers an event that matters (see the rubric), read the hook script it points at before judging. Read-only, always: never execute another plugin's script, and say so plainly if you cannot tell what a script does from reading it.

Also list each plugin's `commands/*.md` basenames to spot collisions with Playbook's plain command names (`fix`, `debug`, `brainstorming`, `workflow`, `worktrees`, `offline-mode`).

## Step 2: judge by the rubric, not the name

The tell is the hook event signature plus what the script actually emits. Plugin names mean nothing; a plugin you have never heard of gets exactly the same reasoning.

- **Stop or SubagentStop injectors are the headline conflict.** Playbook deliberately abandoned that seam: anything a hook emits there is delivered as feedback and forces a whole extra model response, and several stacked Stop hooks produce walls of forced turns. Read the script: one that re-prompts, judges whether to continue, or injects instructions is a genuine conflict, and it is also redundant now because Playbook's pulse and unease do that job on cheaper seams. One that only logs, notifies a phone, or emits nothing to the model is harmless; leave it alone and say why.
- **Context-limit warners** (scripts matching context-monitor or context-warning, or injecting "running low, prepare to pause" language) fight the compaction calm directly. Route these through the existing context-calm flow: quiet them only with consent, and record the choice in the context-calm marker so the offer never repeats.
- **A second SessionStart overlay** that hands down its own standing doctrine usually coexists; Playbook is built to ride on top of them. Flag it only if it directly contradicts Playbook (for example, ordering the agent to stop near the context limit).
- **Per-tool hooks** (PreToolUse or PostToolUse) cost a little latency on every tool call. Note the cost, recommend keeping unless the user complains about speed.
- **Command-name collisions** are advice only: point at the `/playbook:*` aliases, change nothing.

**Never recommend disabling** language servers, MCP integrations, formatters, or anything with no hooks or SessionEnd-only hooks. Every flag needs quoted evidence (the event plus what the script does) and an honest confidence level.

Worked examples, as illustrations of the reasoning rather than a list to match against: a plugin whose Stop hook runs a "judge whether Claude should continue" script is the classic re-prompter, recommend disabling it; GSD's `gsd-context-monitor` is the classic context warner, handled via context-calm; Superpowers registers only a SessionStart overlay and coexists by design, keep it and mention the `/playbook:*` aliases if its command names collide.

## Step 3: resolve, one consented change at a time

- Present all findings first, short, with evidence. Then offer fixes one at a time; never batch-apply.
- Before the first settings edit, back up: `cp ~/.claude/settings.json ~/.claude/settings.json.playbook-backup-<YYYYMMDD-HHMMSS>`.
- Disabling a plugin means flipping its `enabledPlugins` value to `false` in `~/.claude/settings.json`. Never uninstall anything; if the user wants a plugin gone entirely, point them at `/plugin`.
- Never edit any settings file without the user's explicit consent to that specific change.
- Finish with a one-screen summary: what changed, the backup path, how to re-enable (flip the value back or use `/plugin`), and that plugin changes take effect after restarting Claude Code.

## Step 4: prerequisites and notifications

- **jq**: if missing, offer the installer for the detected OS (`brew install jq`, `apt-get install jq`, `dnf install jq`, `pacman -S jq`, or `winget install jqlang.jq`), and run it only with consent.
- **GSD**: only mention it if it is absent and the user cares about the `gsd` mode (`npx get-shit-done-cc@latest`). It is not a Playbook prerequisite.
- **Offline notifications**: check the project's `.claude/playbook/` for a `notify-provider` (with `ntfy-topic` or `pushover-token` and `pushover-user`). If unconfigured, offer to set up Pushover or ntfy now, following `scripts/notify`, or to defer; deferring is a fine answer, and offline mode will prompt again when it is actually enabled. Note that this config is per project, so set it up in the project the user will run offline mode from.

## Step 5: record the check

Write the marker so `/playbook` knows setup has run and can spot plugin changes later:

```bash
mkdir -p ~/.claude/playbook
{ echo "checked=<YYYY-MM-DD>"; echo "plugins=<sorted comma-separated enabled plugin list>"; } > ~/.claude/playbook/setup
```

## Step 6: offer the health check

Setup proper ends there. Close by offering an optional, wider Claude Code health check, and run it only if the user says yes: plugin updates available (`/plugin`), duplicate or dead marketplaces, long-disabled plugins worth uninstalling, whether a statusline is configured, and whether auto-updates are on. All of it is advice; the consent rules above still apply to any change.

## Red flags

**Never:** disable anything without quoted evidence of a genuine conflict; batch-apply changes; run another plugin's scripts; uninstall anything; edit settings without explicit consent to that specific edit; nag, the check runs once and then only when plugins change or the user asks.
