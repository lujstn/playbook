---
description: Playbook's hello and status pulse: say hello, report whether Playbook is active plus the current mode, model split, offline and context-calm state, and on a machine's first run offer a one-time read-only check for plugin conflicts. Also where offline notifications get configured.
---

Speak to the user warmly and keep the plumbing out of sight. Open with a short, friendly line that starts with 📚 and says, in plain words, that you are taking a quick look at where Playbook stands on this machine. Do not add a separate hello: on a first run the introduction below does the greeting, and a second one reads as double. Never narrate the mechanics; the words "setup gate", "marker" and "status report" are for you, not for them.

Quietly check whether this machine has been set up: read `~/.claude/playbook/setup` and compare its stored `plugins=` line against the currently enabled plugins (`jq -r '.enabledPlugins | to_entries[] | select(.value) | .key' ~/.claude/settings.json`, sorted and comma-separated). Do not describe this step; just do it. Then:

- **No record yet (first run):** tell them in a friendly line that Playbook has not been set up here yet and that you will hand over to get that sorted, then run the `playbook:setup` skill. It leads the introduction and asks their permission before it reads anything, so let it take over from there. Print the status below only once it returns.
- **A record exists but the enabled plugins have changed:** say in plain words which plugins have appeared or gone, and ask whether to run the check again. On yes, run `playbook:setup`. On no, quietly bring the record up to date so this stops asking. Either way, finish with the status below.
- **A record exists and nothing has changed:** go straight to the status below.

Then give a short status, one line each, no preamble:

1. Whether Playbook is active this session.
2. The current routing mode, if there is one (lone-wolf, interns, hackathon, workflows, gsd, fix, debug, offline, brainstorming).
3. The model split: which tier is executing, which is planning and reviewing.
4. Whether offline mode is on this run.
5. Whether Playbook owns the context-calm channel this session (whether a competing context-warning hook has been quieted in favour of Playbook's calm compaction voice).
