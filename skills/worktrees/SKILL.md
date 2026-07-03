---
name: worktrees
description: Triggers on /worktrees or /pb-worktrees. Sets up a git worktree under .worktrees/ on a dedicated branch and assigns it an instance number so parallel Claude Code sessions can run isolated resources (databases, dev-server ports, cache namespaces) without collision. This is for the human running multiple Claude sessions at once, not for subagent parallelism inside one session.
---

# Worktrees

## Overview

Worktrees let a developer run several Claude Code sessions against the same repository simultaneously, each on its own branch and each with its own isolated stack resources, so they do not step on each other's databases, ports, or caches. Each worktree lives under `.worktrees/` and carries an instance number; that number is the single offset applied to every resource the stack needs to isolate.

This is distinct from interns or hackathon mode. Those fan work across subagents inside one session. Worktrees are for the human opening several terminal windows, each running a separate Claude Code session, each working an independent branch.

Announce at entry:

```
🌿 Playbook · worktrees: <one-line description of what this worktree is for>
```

## When to use

Use worktrees when:
- Two or more Claude Code sessions need to run simultaneously against the same repo.
- Each session is on a different branch and the branches must not share mutable state (a running database, a dev server port, a cache namespace).
- The work is genuinely independent: different features, different experiments, or a spike alongside a main branch.

Do not use worktrees for separable sub-tasks within one session; use interns or workflows for that.

## The instance-isolation pattern

Every worktree is assigned an **instance number** at creation: 1, 2, 3, and so on, chosen as the next unused number in the `.worktrees/` directory. That number offsets every resource the stack exposes, so any number of worktrees can run in parallel without collision.

### Docker database example

For a stack using a Docker-managed Postgres database, the instance number offsets four things:

| Resource | Primary (instance 1) | Second instance | Pattern |
|---|---|---|---|
| Host port | 5432 | 5433 | `5431 + N` |
| Container name | `myapp-db-1` | `myapp-db-2` | `myapp-db-N` |
| Volume name | `myapp-data-1` | `myapp-data-2` | `myapp-data-N` |
| Database name | `myapp_1` | `myapp_2` | `myapp_N` |

The same offset applies wherever the stack uses a shared resource: a dev-server port (`3000 + N - 1`), a Redis database index (`N - 1`), an S3 bucket prefix (`myapp-N/`), or any other isolatable slot. The principle is identical regardless of platform or language.

## Process

### 1. Detect the stack

Before creating the worktree, scan the repository root for signals of isolatable resources:

- `docker-compose.yml` or `compose.yaml`: indicates a containerised stack; read it to find the services and their port mappings.
- `package.json` with a `dev` script mentioning a port: indicates a Node dev server.
- `Procfile`: lists all processes and their ports.
- `.env.example` or `.env`: lists environment variables for database URLs, ports, and credentials.
- `Makefile` or `justfile`: may expose start and test targets that reveal the resource model.

If none of these are present, the worktree is still useful for branch isolation; proceed without resource isolation and say so.

### 2. Choose the instance number

List `.worktrees/` and find the highest instance number already in use. Assign `N = highest + 1`. If `.worktrees/` is empty or does not exist, assign `N = 1`.

### 3. Create the worktree and branch

```bash
# from the repository root
git worktree add .worktrees/<slug>-N -b <slug>-N
```

Use a short descriptive slug for the work (e.g. `auth`, `billing`, `spike`), suffixed with the instance number. The branch name matches the worktree directory name.

### 4. Write the instance config

Create `.worktrees/<slug>-N/.worktree-instance` with the instance number and any resource overrides so the session in that worktree knows its identity without scanning the directory. The values are the resolved offsets for instance 2 of the Docker-Postgres stack (host port from the table above, dev-server port per the 3000 + N - 1 pattern):

```
PLAYBOOK_INSTANCE=2
DB_PORT=5433
DB_NAME=myapp_2
DEV_PORT=3001
```

Fill in only the variables relevant to the detected stack. This file is read by the Claude Code session that opens the worktree; it is not a shell script and is not sourced automatically.

### 5. Summarise for the user

Print a short block:

```
🌿 Playbook · worktrees: created .worktrees/<slug>-2 on branch <slug>-2 (instance 2)

Resources isolated for this session:
  DB port:       5433
  DB name:       myapp_2
  Dev port:      3001

Open a new Claude Code session in .worktrees/<slug>-2 to begin.
```

If no isolatable resources were detected, say so plainly: "no isolatable resources found; the worktree is branch-isolated but shares the stack."

## Red Flags

**Never:**
- Assign the same instance number to two worktrees. Always scan `.worktrees/` before choosing N.
- Use worktrees as a replacement for interns or workflows. Subagent parallelism inside one session is the engine's job.
- Leave resource collisions silent. If the stack has a known port or name conflict, surface it before creating the worktree.
- Write into the primary working tree from inside a worktree session. Each worktree is branch-isolated; cross-branch writes must go through git.

## Integration

The instance number and resource config in `.worktree-instance` are read by the session that opens in that directory. The routing engine in that session operates normally; it routes on separability and durability as usual, with the North Star of whatever task the session is working on.

When a worktree is finished and its branch has been merged, remove it cleanly:

```bash
git worktree remove .worktrees/<slug>-N
git branch -d <slug>-N
```
