---
description: Playbook status heartbeat: print whether Playbook is active and what it is currently doing.
---

Print a Playbook status report covering:

1. Whether Playbook is active this session (yes/no).
2. The current routing mode, if known (lone-wolf, interns, hackathon, workflows, gsd, fix, debug, offline, brainstorming).
3. The current model split: which tier is executing, which is planning/reviewing.
4. Whether offline mode is on this run.
5. Whether Playbook owns the context-calm channel this session (i.e. whether the GSD context-warning hook has been quieted in favour of Playbook's calm compaction voice).

Format each item as a single line. Keep the output short.
