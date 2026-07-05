---
description: Playbook status heartbeat: print whether Playbook is active and what it is doing, and run the one-time machine setup check when it has never run or the plugins changed.
---

First, the setup gate. Read `~/.claude/playbook/setup` and compare its `plugins=` line against the currently enabled plugins (`jq -r '.enabledPlugins | to_entries[] | select(.value) | .key' ~/.claude/settings.json`, sorted, comma-separated):

- If the marker file does not exist, this machine has never been checked: run the `playbook:setup` skill now, then print the status report below.
- If it exists but the plugin list differs, say which plugins appeared or vanished and ask whether to re-run the check; on yes run `playbook:setup`, on no rewrite the marker with the current list so this offer does not repeat.
- If it exists and matches, skip straight to the status report.

Then print a Playbook status report covering:

1. Whether Playbook is active this session (yes/no).
2. The current routing mode, if known (lone-wolf, interns, hackathon, workflows, gsd, fix, debug, offline, brainstorming).
3. The current model split: which tier is executing, which is planning/reviewing.
4. Whether offline mode is on this run.
5. Whether Playbook owns the context-calm channel this session (i.e. whether the GSD context-warning hook has been quieted in favour of Playbook's calm compaction voice).

Format each item as a single line. Keep the output short.
